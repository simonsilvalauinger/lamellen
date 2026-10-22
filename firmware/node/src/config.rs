//! Einstellungen pro Gitter, beim Bauen über Umgebungsvariablen gesetzt:
//!
//! ```sh
//! LAMELLE_ROOM=kueche LAMELLE_CLOSED_US=1150 LAMELLE_OPEN_US=1850 cargo run --release
//! ```

use lamellen_protocol::Room;
use lamellen_protocol::logic::NodeConfig;
use lamellen_protocol::servo::ServoCalibration;

pub const ROOM: Room = match Room::from_slug(or(option_env!("LAMELLE_ROOM"), "schlafzimmer")) {
    Some(room) => room,
    None => panic!("LAMELLE_ROOM: unbekannter Raum (siehe Room::slug)"),
};

/// Pulsbreiten für „zu“ (0 %) und „offen“ (100 %), pro Gitter kalibrieren.
/// Standard passt zur Variante „direkt“ (45° am Servo, MG90S ≈ 11 µs/°).
/// Für die Variante „getriebe“ (135° am Servo) etwa 750 / 2250 µs.
pub const SERVO: ServoCalibration = ServoCalibration {
    closed_us: parse_u16(or(option_env!("LAMELLE_CLOSED_US"), "1250")),
    open_us: parse_u16(or(option_env!("LAMELLE_OPEN_US"), "1750")),
};

pub const NODE: NodeConfig = NodeConfig::DEFAULT;

/// Prozentpunkte pro Rampenschritt und Pause dazwischen. Ein voller Hub
/// dauert damit etwa 2 s, das ist leise und schont das Getriebe.
pub const RAMP_STEP: u8 = 2;
pub const RAMP_STEP_MS: u64 = 40;
/// Wartezeit in der Endlage, bevor der Servo stromlos wird.
pub const SETTLE_MS: u64 = 300;
/// Anlaufzeit des 5-V-Wandlers.
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
