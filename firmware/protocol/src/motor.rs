//! Stellungsregelung für den Schneckengetriebemotor (Variante „schnecke“).
//!
//! Ein AS5600 misst den Winkel einer Lamelle absolut (12 Bit, 4096 Schritte je
//! Umdrehung). Der Motor fährt mit voller Leistung an, wird kurz vor dem Ziel
//! langsamer und bremst im Totband. Die Schnecke ist selbsthemmend, danach ist
//! der Motor stromlos.

/// Schritte des AS5600 je Umdrehung.
pub const COUNTS: i32 = 4096;

/// Kürzeste vorzeichenbehaftete Strecke von `from` nach `to` in Schritten
/// (−2048 … 2047).
pub fn wrap_diff(from: u16, to: u16) -> i32 {
    let d = (i32::from(to) - i32::from(from)).rem_euclid(COUNTS);
    if d >= COUNTS / 2 { d - COUNTS } else { d }
}

/// Rohwinkel in den beiden Endlagen, pro Gitter kalibriert. Der Hub muss
/// kleiner als eine halbe Umdrehung sein (hier 90°, also etwa 1024 Schritte).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AngleCalibration {
    pub closed_raw: u16,
    pub open_raw: u16,
}

impl AngleCalibration {
    fn span(&self) -> i32 {
        wrap_diff(self.closed_raw, self.open_raw)
    }

    /// Rohwinkel für eine Öffnung in Prozent.
    pub fn raw_for(&self, position: u8) -> u16 {
        let p = i32::from(position.min(100));
        (i32::from(self.closed_raw) + self.span() * p / 100).rem_euclid(COUNTS) as u16
    }

    /// Öffnung in Prozent für einen gemessenen Rohwinkel, auf 0 … 100 begrenzt.
    pub fn position_of(&self, raw: u16) -> u8 {
        let span = self.span();
        if span == 0 {
            return 0;
        }
        let d = wrap_diff(self.closed_raw, raw);
        // Runden statt Abschneiden, damit 0 % und 100 % stabil getroffen werden
        let p = (d * 200 / span + 1).div_euclid(2);
        p.clamp(0, 100) as u8
    }

    /// Abstand zum Ziel in Schritten, positiv heißt: Richtung „auf“ fahren.
    pub fn error(&self, raw: u16, target: u8) -> i32 {
        let d = wrap_diff(raw, self.raw_for(target));
        if self.span() < 0 { -d } else { d }
    }
}

/// Grenzen der Regelung.
#[derive(Clone, Copy, Debug)]
pub struct MotorConfig {
    /// Innerhalb dieses Abstands (Schritte) gilt das Ziel als erreicht.
    pub deadband: u16,
    /// Ab diesem Abstand wird langsamer gefahren.
    pub slow_zone: u16,
    pub full_duty: u8,
    pub slow_duty: u8,
    /// Bewegt sich der Winkel so lange um weniger als `stall_counts`, gilt der
    /// Antrieb als blockiert.
    pub stall_ms: u32,
    pub stall_counts: u16,
    /// Obergrenze für eine ganze Fahrt.
    pub timeout_ms: u32,
}

impl MotorConfig {
    pub const DEFAULT: MotorConfig = MotorConfig {
        deadband: 8,  // ca. 0,7°
        slow_zone: 80, // ca. 7°
        full_duty: 100,
        slow_duty: 45,
        stall_ms: 400,
        stall_counts: 6,
        timeout_ms: 6000,
    };
}

/// Ansteuerung der H-Brücke.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Drive {
    /// Richtung „auf“ mit Tastgrad in Prozent.
    Open(u8),
    /// Richtung „zu“ mit Tastgrad in Prozent.
    Close(u8),
    /// Beide Ausgänge hoch: Kurzschlussbremse.
    Brake,
}

pub fn drive_for(error: i32, cfg: &MotorConfig) -> Drive {
    let dist = error.unsigned_abs();
    if dist <= u32::from(cfg.deadband) {
        return Drive::Brake;
    }
    let duty = if dist <= u32::from(cfg.slow_zone) { cfg.slow_duty } else { cfg.full_duty };
    if error > 0 { Drive::Open(duty) } else { Drive::Close(duty) }
}

/// Erkennt einen blockierten Antrieb oder einen gelösten Magneten.
#[derive(Clone, Copy, Debug)]
pub struct StallWatch {
    anchor_raw: u16,
    anchor_ms: u32,
}

impl StallWatch {
    pub fn new(raw: u16, now_ms: u32) -> Self {
        StallWatch { anchor_raw: raw, anchor_ms: now_ms }
    }

    /// `true`, wenn sich der Winkel seit `stall_ms` kaum bewegt hat.
    pub fn update(&mut self, raw: u16, now_ms: u32, cfg: &MotorConfig) -> bool {
        if wrap_diff(self.anchor_raw, raw).unsigned_abs() >= u32::from(cfg.stall_counts) {
            *self = StallWatch::new(raw, now_ms);
            return false;
        }
        now_ms.wrapping_sub(self.anchor_ms) >= cfg.stall_ms
    }
}

/// Polung des Motors: Die Firmware lernt sie bei der ersten Fahrt. Läuft der
/// Winkel deutlich vom Ziel weg, ist der Motor andersherum angeschlossen.
pub fn runs_backwards(start_error: i32, error: i32, threshold: u16) -> bool {
    start_error.signum() != 0
        && start_error.signum() == error.signum()
        && error.unsigned_abs() >= start_error.unsigned_abs() + u32::from(threshold)
}

#[cfg(test)]
mod tests {
    use super::*;

    const CFG: MotorConfig = MotorConfig::DEFAULT;

    #[test]
    fn wrap_diff_takes_short_way() {
        assert_eq!(wrap_diff(100, 200), 100);
        assert_eq!(wrap_diff(200, 100), -100);
        assert_eq!(wrap_diff(4000, 50), 146);
        assert_eq!(wrap_diff(50, 4000), -146);
        assert_eq!(wrap_diff(0, 2048), -2048);
    }

    #[test]
    fn calibration_maps_both_ways_across_zero() {
        // zu bei 3500, auf eine Vierteldrehung weiter (über die 0 hinweg)
        let cal = AngleCalibration { closed_raw: 3500, open_raw: (3500 + 1024) % 4096 };
        assert_eq!(cal.raw_for(0), 3500);
        assert_eq!(cal.raw_for(100), 428);
        assert_eq!(cal.raw_for(50), 3500 + 512);
        for p in [0u8, 15, 50, 99, 100] {
            assert_eq!(cal.position_of(cal.raw_for(p)), p);
        }
        // über die Endlagen hinaus wird begrenzt
        assert_eq!(cal.position_of(3400), 0);
        assert_eq!(cal.position_of(600), 100);
    }

    #[test]
    fn error_points_towards_open() {
        let up = AngleCalibration { closed_raw: 1000, open_raw: 2024 };
        assert!(up.error(1000, 100) > 0);
        assert!(up.error(2024, 0) < 0);
        // umgekehrte Zählrichtung des Sensors
        let down = AngleCalibration { closed_raw: 2024, open_raw: 1000 };
        assert!(down.error(2024, 100) > 0);
        assert_eq!(down.error(1512, 50), 0);
    }

    #[test]
    fn drive_slows_down_and_brakes() {
        assert_eq!(drive_for(500, &CFG), Drive::Open(CFG.full_duty));
        assert_eq!(drive_for(-500, &CFG), Drive::Close(CFG.full_duty));
        assert_eq!(drive_for(40, &CFG), Drive::Open(CFG.slow_duty));
        assert_eq!(drive_for(-8, &CFG), Drive::Brake);
        assert_eq!(drive_for(0, &CFG), Drive::Brake);
    }

    #[test]
    fn stall_is_detected_only_without_progress() {
        let mut w = StallWatch::new(1000, 0);
        assert!(!w.update(1002, 300, &CFG));
        assert!(w.update(1003, 400, &CFG));
        let mut w = StallWatch::new(1000, 0);
        assert!(!w.update(1010, 300, &CFG)); // Fortschritt setzt den Anker neu
        assert!(!w.update(1012, 600, &CFG));
        assert!(w.update(1012, 700, &CFG));
    }

    #[test]
    fn backwards_motor_is_recognised() {
        assert!(runs_backwards(300, 340, 30));
        assert!(!runs_backwards(300, 320, 30));
        assert!(!runs_backwards(300, 200, 30));
        assert!(runs_backwards(-300, -340, 30));
        assert!(!runs_backwards(0, 100, 30));
    }
}
