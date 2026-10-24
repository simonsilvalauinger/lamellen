//! Einstellungen pro Gitter, beim Bauen über Umgebungsvariablen gesetzt:
//!
//! ```sh
//! LAMELLE_ROOM=kueche LAMELLE_CLOSED_US=1150 LAMELLE_OPEN_US=1850 cargo run --release
//! # Variante „schnecke“ (Schneckenmotor + AS5600):
//! LAMELLE_ROOM=kueche LAMELLE_CLOSED_RAW=3510 cargo run --release --features schnecke
//! ```

use lamellen_protocol::Room;
use lamellen_protocol::logic::NodeConfig;
#[cfg(feature = "schnecke")]
use lamellen_protocol::motor::{AngleCalibration, MotorConfig};
#[cfg(not(feature = "schnecke"))]
use lamellen_protocol::servo::ServoCalibration;

pub const ROOM: Room = match Room::from_slug(or(option_env!("LAMELLE_ROOM"), "schlafzimmer")) {
    Some(room) => room,
    None => panic!("LAMELLE_ROOM: unbekannter Raum (siehe Room::slug)"),
};

/// Pulsbreiten für „zu“ (0 %) und „offen“ (100 %), pro Gitter kalibrieren.
/// Der Knopf dreht 180°. Standard passt zur Variante „direkt“ (MG90S, 180°
/// bei etwa 500–2500 µs), mit etwas Abstand zu den Servo-Endlagen.
/// Variante „getriebe“ (270°-Servo, 1:1,5) braucht etwa 830 / 2170 µs.
#[cfg(not(feature = "schnecke"))]
pub const SERVO: ServoCalibration = ServoCalibration {
    closed_us: parse_u16(or(option_env!("LAMELLE_CLOSED_US"), "600")),
    open_us: parse_u16(or(option_env!("LAMELLE_OPEN_US"), "2400")),
};

/// Rohwinkel des AS5600 bei „zu“ (Lamellen flach) und „offen“ (90°), mit dem
/// Kalibriermodus ablesen. Ohne `LAMELLE_OPEN_RAW` liegt „offen“ eine
/// Vierteldrehung weiter; so zählt der AS5600, wenn DIR an GND liegt und der
/// Chip zum Magneten zeigt.
#[cfg(feature = "schnecke")]
pub const ANGLE: AngleCalibration = {
    let closed_raw = parse_u16(or(option_env!("LAMELLE_CLOSED_RAW"), "0"));
    assert!(closed_raw < 4096, "LAMELLE_CLOSED_RAW muss kleiner als 4096 sein");
    let open_raw = match option_env!("LAMELLE_OPEN_RAW") {
        Some(v) => parse_u16(v),
        None => (closed_raw + 1024) % 4096,
    };
    assert!(open_raw < 4096, "LAMELLE_OPEN_RAW muss kleiner als 4096 sein");
    AngleCalibration { closed_raw, open_raw }
};

#[cfg(feature = "schnecke")]
pub const MOTOR: MotorConfig = MotorConfig::DEFAULT;

/// `LAMELLE_KALIBRIEREN=1`: kein Funk, kein Schlaf, Rohwinkel laufend ausgeben
/// und den Motor über die BOOT-Taste fahren.
#[cfg(feature = "schnecke")]
pub const KALIBRIEREN: bool = option_env!("LAMELLE_KALIBRIEREN").is_some();

pub const NODE: NodeConfig = NodeConfig::DEFAULT;

/// Prozentpunkte pro Rampenschritt und Pause dazwischen. Ein voller Hub
/// dauert damit etwa 2 s, das ist leise und schont das Getriebe.
#[cfg(not(feature = "schnecke"))]
pub const RAMP_STEP: u8 = 2;
#[cfg(not(feature = "schnecke"))]
pub const RAMP_STEP_MS: u64 = 40;
/// Wartezeit in der Endlage, bevor der Servo stromlos wird.
#[cfg(not(feature = "schnecke"))]
pub const SETTLE_MS: u64 = 300;
/// Anlaufzeit des 5-V-Wandlers.
#[cfg(not(feature = "schnecke"))]
pub const BOOST_STARTUP_MS: u64 = 20;
/// So lange wartet der Knoten auf die Antwort des Gateways.
pub const REPLY_TIMEOUT_MS: u64 = 60;
/// Akku-Spannungsteiler (2 × 1 MΩ): U_Akku = U_ADC × 2.
pub const BATTERY_DIVIDER: u16 = 2;

const fn or(value: Option<&'static str>, default: &'static str) -> &'static str {
    match value {
        Some(v) => v,
        None => default,
    }
}

const fn parse_u16(s: &str) -> u16 {
    let bytes = s.as_bytes();
    assert!(!bytes.is_empty(), "leere Zahl in LAMELLE_*_US");
    let mut value: u32 = 0;
    let mut i = 0;
    while i < bytes.len() {
        let digit = bytes[i];
        assert!(digit.is_ascii_digit(), "LAMELLE_*_US muss eine Zahl sein");
        value = value * 10 + (digit - b'0') as u32;
        assert!(value <= u16::MAX as u32, "LAMELLE_*_US zu groß");
        i += 1;
    }
    value as u16
}
