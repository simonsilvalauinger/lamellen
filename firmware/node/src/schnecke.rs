//! Antrieb der Variante „schnecke“: N20-Schneckengetriebemotor an einem
//! DRV8833, Stellung über einen AS5600 an einer Lamellenachse.
//!
//! Pinbelegung (Seeed XIAO ESP32-C6):
//! - D1 / GPIO1:  nSLEEP des DRV8833 (nur während der Fahrt hoch)
//! - D2 / GPIO2:  AIN1
//! - D3 / GPIO21: AIN2
//! - D4 / GPIO22: SDA AS5600
//! - D5 / GPIO23: SCL AS5600
//! - D8 / GPIO19: Versorgung AS5600 (6,5 mA, direkt aus dem Pin)
//! - BOOT / GPIO9: im Kalibriermodus Motor von Hand fahren

use embassy_time::{Duration, Instant, Timer};
use esp_hal::Blocking;
use esp_hal::gpio::{DriveMode, Input, Output, OutputPin};
use esp_hal::i2c::master::I2c;
use esp_hal::ledc::channel::{self, Channel, ChannelIFace};
use esp_hal::ledc::timer::{self, TimerIFace};
use esp_hal::ledc::{LSGlobalClkSource, Ledc, LowSpeed};
use esp_hal::peripherals::LEDC;
use esp_hal::time::Rate;
use lamellen_protocol::motor::{Drive, StallWatch, drive_for, runs_backwards};
use log::{info, warn};

use crate::config::{ANGLE, MOTOR};

const AS5600_ADDR: u8 = 0x36;
const REG_STATUS: u8 = 0x0B;
const REG_RAW_ANGLE: u8 = 0x0C;
const STATUS_MAGNET_DETECTED: u8 = 1 << 5;
/// Einschaltzeit des AS5600 laut Datenblatt.
const SENSOR_STARTUP_MS: u64 = 10;
/// Nach dieser Zeit prüft die erste Fahrt, ob der Motor richtig herum dreht.
const DIRECTION_PROBE_MS: u32 = 150;
const DIRECTION_PROBE_COUNTS: u16 = 30;
const LOOP_MS: u64 = 2;
const BRAKE_MS: u64 = 50;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Fehler {
    /// Keine Antwort über I2C.
    Sensor,
    /// AS5600 sieht keinen Magneten.
    KeinMagnet,
    /// Winkel ändert sich trotz Motorstrom nicht.
    Blockiert,
    Zeitueberschreitung,
}

pub struct Sensor<'d> {
    i2c: I2c<'d, Blocking>,
    power: Output<'d>,
}

impl<'d> Sensor<'d> {
    pub async fn ein(i2c: I2c<'d, Blocking>, mut power: Output<'d>) -> Self {
        power.set_high();
        Timer::after(Duration::from_millis(SENSOR_STARTUP_MS)).await;
        Sensor { i2c, power }
    }

    /// Rohwinkel 0 … 4095.
    pub fn lesen(&mut self) -> Result<u16, Fehler> {
        let mut status = [0u8];
        self.i2c.write_read(AS5600_ADDR, &[REG_STATUS], &mut status).map_err(|_| Fehler::Sensor)?;
        if status[0] & STATUS_MAGNET_DETECTED == 0 {
            return Err(Fehler::KeinMagnet);
        }
        let mut raw = [0u8; 2];
        self.i2c.write_read(AS5600_ADDR, &[REG_RAW_ANGLE], &mut raw).map_err(|_| Fehler::Sensor)?;
        Ok((u16::from(raw[0] & 0x0F) << 8) | u16::from(raw[1]))
    }

    pub fn aus(self) {
        let Sensor { i2c, mut power } = self;
        drop(i2c);
        power.set_low();
    }
}

/// H-Brücke mit zwei PWM-Kanälen (20 kHz, unhörbar).
struct Bruecke<'a> {
    in1: Channel<'a, LowSpeed>,
    in2: Channel<'a, LowSpeed>,
}

impl Bruecke<'_> {
    fn stellen(&self, drive: Drive, invert: bool) {
        let (a, b) = match drive {
            Drive::Brake => (100, 100),
            Drive::Open(d) if !invert => (d, 0),
            Drive::Close(d) if invert => (d, 0),
            Drive::Open(d) | Drive::Close(d) => (0, d),
        };
        // Langsamer Zerfall wäre leiser, schneller Zerfall reicht für den kurzen Hub
        self.in1.set_duty(a).expect("Tastgrad");
        self.in2.set_duty(b).expect("Tastgrad");
    }
}

fn pwm_timer<'a>(ledc: &Ledc<'a>) -> timer::Timer<'a, LowSpeed> {
    let mut t = ledc.timer::<LowSpeed>(timer::Number::Timer0);
    t.configure(timer::config::Config {
        duty: timer::config::Duty::Duty10Bit,
        clock_source: timer::LSClockSource::APBClk,
        frequency: Rate::from_khz(20),
    })
    .expect("LEDC-Timer");
    t
}

fn kanal<'a>(
    ledc: &Ledc<'a>,
    t: &'a timer::Timer<'a, LowSpeed>,
    nr: channel::Number,
    pin: impl OutputPin + 'a,
) -> Channel<'a, LowSpeed> {
    let mut ch = ledc.channel(nr, pin);
    ch.configure(channel::config::Config { timer: t, duty_pct: 0, drive_mode: DriveMode::PushPull })
        .expect("LEDC-Kanal");
    ch
}

/// Fährt auf `target` (%) und gibt den danach gemessenen Rohwinkel zurück.
/// Stimmt die Polung des Motors nicht, wird `invert` umgeschaltet.
pub async fn fahren(
    ledc: LEDC<'_>,
    in1: impl OutputPin,
    in2: impl OutputPin,
    nsleep: &mut Output<'_>,
    sensor: &mut Sensor<'_>,
    target: u8,
    invert: &mut bool,
) -> Result<u16, Fehler> {
    let mut ledc = Ledc::new(ledc);
    ledc.set_global_slow_clock(LSGlobalClkSource::APBClk);
    let t = pwm_timer(&ledc);
    let bruecke = Bruecke {
        in1: kanal(&ledc, &t, channel::Number::Channel0, in1),
        in2: kanal(&ledc, &t, channel::Number::Channel1, in2),
    };
    nsleep.set_high();
    Timer::after(Duration::from_millis(1)).await;

    let start = Instant::now();
    let mut raw = sensor.lesen();
    let start_error = raw.map(|r| ANGLE.error(r, target)).unwrap_or(0);
    let mut watch = StallWatch::new(*raw.as_ref().unwrap_or(&0), 0);
    let mut probed = false;
    let result = loop {
        let r = match raw {
            Ok(r) => r,
            Err(e) => break Err(e),
        };
        let ms = start.elapsed().as_millis() as u32;
        let error = ANGLE.error(r, target);
        if !probed && ms >= DIRECTION_PROBE_MS {
            probed = true;
            if runs_backwards(start_error, error, DIRECTION_PROBE_COUNTS) {
                *invert = !*invert;
                warn!("Motor dreht falsch herum, Polung wird umgeschaltet");
                watch = StallWatch::new(r, ms);
            }
        }
        let drive = drive_for(error, &MOTOR);
        bruecke.stellen(drive, *invert);
        if drive == Drive::Brake {
            break Ok(r);
        }
        if ms > MOTOR.timeout_ms {
            break Err(Fehler::Zeitueberschreitung);
        }
        if watch.update(r, ms, &MOTOR) {
            break Err(Fehler::Blockiert);
        }
        Timer::after(Duration::from_millis(LOOP_MS)).await;
        raw = sensor.lesen();
    };

    bruecke.stellen(Drive::Brake, false);
    Timer::after(Duration::from_millis(BRAKE_MS)).await;
    bruecke.in1.set_duty(0).expect("Tastgrad");
    bruecke.in2.set_duty(0).expect("Tastgrad");
    nsleep.set_low();
    // Endlage nachmessen; die Schnecke hält sie ohne Strom
    result.and_then(|_| sensor.lesen())
}

/// Kalibriermodus: zeigt laufend den Rohwinkel. Solange BOOT gedrückt ist,
/// fährt der Motor langsam; jedes neue Drücken kehrt die Richtung um.
pub async fn kalibrieren(
    ledc: LEDC<'_>,
    in1: impl OutputPin,
    in2: impl OutputPin,
    nsleep: &mut Output<'_>,
    sensor: &mut Sensor<'_>,
    boot: Input<'_>,
) -> ! {
    let mut ledc = Ledc::new(ledc);
    ledc.set_global_slow_clock(LSGlobalClkSource::APBClk);
    let t = pwm_timer(&ledc);
    let bruecke = Bruecke {
        in1: kanal(&ledc, &t, channel::Number::Channel0, in1),
        in2: kanal(&ledc, &t, channel::Number::Channel1, in2),
    };
    info!("Kalibriermodus: BOOT gedrückt halten fährt den Motor, jedes Drücken wechselt die Richtung");
    let mut forward = false;
    let mut was_pressed = false;
    let mut tick: u32 = 0;
    loop {
        let pressed = boot.is_low();
        if pressed && !was_pressed {
            forward = !forward;
            nsleep.set_high();
        }
        if pressed {
            let duty = MOTOR.slow_duty;
            bruecke.stellen(if forward { Drive::Open(duty) } else { Drive::Close(duty) }, false);
        } else if was_pressed {
            bruecke.stellen(Drive::Brake, false);
            Timer::after(Duration::from_millis(BRAKE_MS)).await;
            bruecke.stellen(Drive::Open(0), false);
            nsleep.set_low();
        }
        was_pressed = pressed;

        if tick.is_multiple_of(125) {
            match sensor.lesen() {
                Ok(raw) => info!("Rohwinkel {:4}  ({}° , {}% nach aktueller Kalibrierung)",
                                 raw, u32::from(raw) * 360 / 4096, ANGLE.position_of(raw)),
                Err(e) => warn!("AS5600: {:?}", e),
            }
        }
        tick = tick.wrapping_add(1);
        Timer::after(Duration::from_millis(LOOP_MS)).await;
    }
}
