//! Lamellen-Knoten: wacht auf, meldet sich per ESP-NOW beim Gateway, stellt
//! das Gitter nach und schläft wieder.
//!
//! Pinbelegung (Seeed XIAO ESP32-C6):
//! - D0 / GPIO0: Akku über Spannungsteiler 2 × 1 MΩ
//! - D1 / GPIO1: EN des 5-V-Aufwärtswandlers für den Servo
//! - D2 / GPIO2: Servo-Signal
//!
//! Mit dem Feature `schnecke` treibt stattdessen ein Schneckengetriebemotor
//! über einen DRV8833 die Lamellen, ein AS5600 misst ihre Stellung absolut
//! (Pinbelegung in `schnecke.rs`).

#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types, especially those \
    holding buffers for the duration of a data transfer."
)]
#![deny(clippy::large_stack_frames)]

mod config;
#[cfg(feature = "schnecke")]
mod schnecke;

use embassy_executor::Spawner;
use embassy_time::{Duration, with_timeout};
#[cfg(not(feature = "schnecke"))]
use embassy_time::Timer;
use esp_backtrace as _;
use esp_hal::analog::adc::{Adc, AdcCalCurve, AdcConfig, Attenuation};
use esp_hal::gpio::{Level, Output, OutputConfig};
#[cfg(not(feature = "schnecke"))]
use esp_hal::gpio::{DriveMode, OutputPin};
#[cfg(not(feature = "schnecke"))]
use esp_hal::ledc::channel::{self, ChannelHW, ChannelIFace};
#[cfg(not(feature = "schnecke"))]
use esp_hal::ledc::timer::{self, TimerIFace};
#[cfg(not(feature = "schnecke"))]
use esp_hal::ledc::{LSGlobalClkSource, Ledc, LowSpeed};
#[cfg(not(feature = "schnecke"))]
use esp_hal::peripherals::LEDC;
use esp_hal::peripherals::{ADC1, GPIO0};
use esp_hal::rtc_cntl::sleep::{LowPower, RtcSleepConfig};
use esp_hal::rtc_cntl::{SocResetReason, reset_reason};
use esp_hal::system::Cpu;
use esp_hal::time::Instant;
#[cfg(not(feature = "schnecke"))]
use esp_hal::time::Rate;
use esp_hal::timer::timg::TimerGroup;
use esp_radio::esp_now::BROADCAST_ADDRESS;
use lamellen_protocol::logic::{NodeMemory, decide};
use lamellen_protocol::message::MAX_FRAME_LEN;
#[cfg(not(feature = "schnecke"))]
use lamellen_protocol::servo::duty_for_pulse;
use lamellen_protocol::{Message, Status, StatusFlags, decode, encode};
use log::{info, warn};

use crate::config::{NODE, ROOM};
#[cfg(not(feature = "schnecke"))]
use crate::config::SERVO;
#[cfg(feature = "schnecke")]
use crate::config::ANGLE;

extern crate alloc;

esp_bootloader_esp_idf::esp_app_desc!();

/// Deep-Sleep-fester Zustand. Nur primitive Felder, damit jedes Bitmuster
/// gültig ist; `magic` erkennt nicht initialisierten Speicher.
#[repr(C)]
struct Persisted {
    magic: u32,
    position: u8,
    target: u8,
    min_position: u8,
    misses: u8,
    channel: u8,
    seq: u16,
    sleep_s: u16,
    /// Variante „schnecke“: gelernte Motorpolung und Störung der letzten Fahrt.
    motor_invert: u8,
    drive_fault: u8,
}

// SAFETY: nur ganzzahlige Felder, jedes Bitmuster ist ein gültiger Wert.
unsafe impl esp_hal::Persistable for Persisted {}

const PERSIST_MAGIC: u32 = 0x4C41_4D32; // "LAM2"

#[esp_hal::ram(unstable(rtc_fast, persistent))]
static mut STATE: Persisted = Persisted {
    magic: 0,
    position: 0,
    target: 0,
    min_position: 0,
    misses: 0,
    channel: 0,
    seq: 0,
    sleep_s: 0,
    motor_invert: 0,
    drive_fault: 0,
};

/// Antriebszustand, der nicht zur gemeinsamen Logik gehört.
#[derive(Clone, Copy, Default)]
struct DriveMemory {
    motor_invert: bool,
    drive_fault: bool,
}

fn load_memory() -> (NodeMemory, DriveMemory, bool) {
    // SAFETY: einziger Zugriff, läuft vor allen Tasks.
    let p = unsafe { &*core::ptr::addr_of!(STATE) };
    if p.magic != PERSIST_MAGIC || !(1..=13).contains(&p.channel) {
        return (NodeMemory::initial(&NODE), DriveMemory::default(), true);
    }
    let mem = NodeMemory {
        position: p.position.min(100),
        target: p.target.min(100),
        min_position: p.min_position,
        misses: p.misses,
        channel: p.channel,
        seq: p.seq,
        sleep_s: p.sleep_s,
    };
    let drive = DriveMemory { motor_invert: p.motor_invert != 0, drive_fault: p.drive_fault != 0 };
    (mem, drive, false)
}

fn store_memory(mem: &NodeMemory, drive: &DriveMemory) {
    // SAFETY: einziger Zugriff, läuft nach allen Tasks direkt vor dem Schlafen.
    unsafe {
        *core::ptr::addr_of_mut!(STATE) = Persisted {
            magic: PERSIST_MAGIC,
            position: mem.position,
            target: mem.target,
            min_position: mem.min_position,
            misses: mem.misses,
            channel: mem.channel,
            seq: mem.seq,
            sleep_s: mem.sleep_s,
            motor_invert: u8::from(drive.motor_invert),
            drive_fault: u8::from(drive.drive_fault),
        };
    }
}

fn read_battery_mv(adc1: ADC1<'_>, pin: GPIO0<'_>) -> u16 {
    let mut config = AdcConfig::new();
    let mut pin = config.enable_pin_with_cal::<_, AdcCalCurve<ADC1>>(pin, Attenuation::_11dB);
    let mut adc = Adc::new(adc1, config);
    let mut sum: u32 = 0;
    const SAMPLES: u32 = 8;
    for _ in 0..SAMPLES {
        let mv = loop {
            match adc.read_oneshot(&mut pin) {
                Ok(mv) => break mv,
                Err(nb::Error::WouldBlock) => continue,
                Err(nb::Error::Other(())) => break 0,
            }
        };
        sum += u32::from(mv);
    }
    (sum / SAMPLES) as u16 * config::BATTERY_DIVIDER
}

#[cfg(not(feature = "schnecke"))]
/// Fährt langsam von `from` nach `to` und schaltet danach Servo und Wandler ab.
async fn move_servo(ledc: LEDC<'_>, signal: impl OutputPin, boost_en: &mut Output<'_>, from: u8, to: u8) {
    const DUTY_BITS: u8 = 14;

    let mut ledc = Ledc::new(ledc);
    ledc.set_global_slow_clock(LSGlobalClkSource::APBClk);
    let mut pwm_timer = ledc.timer::<LowSpeed>(timer::Number::Timer0);
    pwm_timer
        .configure(timer::config::Config {
            duty: timer::config::Duty::Duty14Bit,
            clock_source: timer::LSClockSource::APBClk,
            frequency: Rate::from_hz(50),
        })
        .expect("LEDC-Timer");
    let mut pwm = ledc.channel(channel::Number::Channel0, signal);
    pwm.configure(channel::config::Config {
        timer: &pwm_timer,
        duty_pct: 0,
        drive_mode: DriveMode::PushPull,
    })
    .expect("LEDC-Kanal");

    // Erst den Puls der bekannten Ist-Lage anlegen, dann Strom: so ruckt der
    // Servo beim Einschalten nicht.
    pwm.set_duty_hw(duty_for_pulse(SERVO.pulse_us(from), DUTY_BITS));
    boost_en.set_high();
    Timer::after(Duration::from_millis(config::BOOST_STARTUP_MS)).await;

    for position in lamellen_protocol::servo::ramp(from, to, config::RAMP_STEP) {
        pwm.set_duty_hw(duty_for_pulse(SERVO.pulse_us(position), DUTY_BITS));
        Timer::after(Duration::from_millis(config::RAMP_STEP_MS)).await;
    }
    Timer::after(Duration::from_millis(config::SETTLE_MS)).await;

    pwm.set_duty_hw(0);
    boost_en.set_low();
}

#[allow(
    clippy::large_stack_frames,
    reason = "it's not unusual to allocate larger buffers etc. in main"
)]
#[esp_rtos::main]
async fn main(_spawner: Spawner) -> ! {
    esp_println::logger::init_logger_from_env();

    let peripherals = esp_hal::init(esp_hal::Config::default());
    esp_alloc::heap_allocator!(#[esp_hal::ram(reclaimed)] size: 65536);

    let timg0 = TimerGroup::new(peripherals.TIMG0);
    esp_rtos::start(timg0.timer0, peripherals.FROM_CPU_INTR0);

    let mut low_power = LowPower::new(peripherals.LPWR);
    // Servo: Wandler sofort aus, damit der Servo nicht unkontrolliert Strom bekommt.
    // Schnecke: DRV8833 schlafen lassen, der Motor bleibt stromlos.
    let mut boost_en = Output::new(peripherals.GPIO1, Level::Low, OutputConfig::default());

    let (mut mem, drive_mem, fresh) = load_memory();
    #[cfg(feature = "schnecke")]
    let mut drive_mem = drive_mem;
    let cold_boot = fresh || reset_reason(Cpu::ProCpu) != Some(SocResetReason::CoreDeepSleep);
    let battery_mv = read_battery_mv(peripherals.ADC1, peripherals.GPIO0);

    // Schnecke: Stellung absolut messen, bevor der Status gesendet wird
    #[cfg(feature = "schnecke")]
    let mut sensor = {
        use esp_hal::i2c::master::{Config as I2cConfig, I2c};
        let i2c = I2c::new(peripherals.I2C0, I2cConfig::default().with_frequency(esp_hal::time::Rate::from_khz(400)))
            .expect("I2C")
            .with_sda(peripherals.GPIO22)
            .with_scl(peripherals.GPIO23);
        let power = Output::new(peripherals.GPIO19, Level::Low, OutputConfig::default());
        schnecke::Sensor::ein(i2c, power).await
    };
    #[cfg(feature = "schnecke")]
    if config::KALIBRIEREN {
        use esp_hal::gpio::{Input, InputConfig, Pull};
        let boot = Input::new(peripherals.GPIO9, InputConfig::default().with_pull(Pull::Up));
        schnecke::kalibrieren(peripherals.LEDC, peripherals.GPIO2, peripherals.GPIO21, &mut boost_en, &mut sensor, boot)
            .await;
    }
    #[cfg(feature = "schnecke")]
    let measured = match sensor.lesen() {
        Ok(raw) => {
            mem.position = ANGLE.position_of(raw);
            true
        }
        Err(e) => {
            warn!("AS5600: {:?}", e);
            drive_mem.drive_fault = true;
            false
        }
    };

    let mut flags = StatusFlags::default();
    if drive_mem.drive_fault {
        flags.set(StatusFlags::DRIVE_FAULT);
    }
    if cold_boot {
        flags.set(StatusFlags::COLD_BOOT);
    }
    if battery_mv < NODE.battery_low_mv {
        flags.set(StatusFlags::BATTERY_LOW);
    }
    mem.seq = mem.seq.wrapping_add(1);

    let reply = {
        let controller = esp_radio::wifi::WifiController::new(peripherals.WIFI, Default::default())
            .expect("WLAN-Controller");
        let mut esp_now = controller.esp_now();
        if let Err(e) = esp_now.set_channel(mem.channel) {
            warn!("Kanal {} nicht setzbar: {:?}", mem.channel, e);
        }

        let status = Message::Status(Status {
            room: ROOM,
            seq: mem.seq,
            position: mem.position,
            battery_mv,
            flags,
        });
        let mut buf = [0u8; MAX_FRAME_LEN];
        let frame = encode(&status, &mut buf).expect("Status passt in den Rahmen");
        if let Err(e) = esp_now.send_async(&BROADCAST_ADDRESS, frame).await {
            warn!("Senden fehlgeschlagen: {:?}", e);
        }

        let seq = mem.seq;
        with_timeout(Duration::from_millis(config::REPLY_TIMEOUT_MS), async {
            loop {
                let received = esp_now.receive_async().await;
                if let Ok(Message::Command(cmd)) = decode(received.data())
                    && cmd.room == ROOM
                    && cmd.seq == seq
                {
                    return cmd;
                }
            }
        })
        .await
        .ok()
        // Funk wird hier beim Verlassen des Blocks abgeschaltet.
    };

    let plan = decide(&mut mem, reply.as_ref(), battery_mv, &NODE);
    info!(
        "{}: Kanal {} Antwort {} Akku {} mV, {}% -> {}%, schlafe {} s",
        ROOM.slug(),
        mem.channel,
        reply.is_some(),
        battery_mv,
        mem.position,
        plan.target,
        plan.sleep_s
    );

    #[cfg(not(feature = "schnecke"))]
    if plan.target != mem.position || cold_boot {
        move_servo(peripherals.LEDC, peripherals.GPIO2, &mut boost_en, mem.position, plan.target).await;
        mem.position = plan.target;
    }

    #[cfg(feature = "schnecke")]
    {
        // 1 % Abweichung ist Rundung, kein Grund für eine Fahrt
        if measured && plan.target.abs_diff(mem.position) > 1 {
            let result = schnecke::fahren(
                peripherals.LEDC,
                peripherals.GPIO2,
                peripherals.GPIO21,
                &mut boost_en,
                &mut sensor,
                plan.target,
                &mut drive_mem.motor_invert,
            )
            .await;
            match result {
                Ok(raw) => {
                    mem.position = ANGLE.position_of(raw);
                    drive_mem.drive_fault = false;
                }
                Err(e) => {
                    warn!("Fahrt auf {}% abgebrochen: {:?}", plan.target, e);
                    drive_mem.drive_fault = true;
                    if let Ok(raw) = sensor.lesen() {
                        mem.position = ANGLE.position_of(raw);
                    }
                }
            }
        } else if measured {
            drive_mem.drive_fault = false;
        }
        sensor.aus();
    }

    store_memory(&mem, &drive_mem);
    low_power.set_wakeup_deadline(Instant::now() + esp_hal::time::Duration::from_secs(u64::from(plan.sleep_s)));
    low_power.sleep_deep(RtcSleepConfig::deep())
}
