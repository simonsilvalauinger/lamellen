//! ESP-NOW-Nachrichten zwischen Knoten und Gateway.
//!
//! Rahmen: `MAGIC (2 Byte) | VERSION (1 Byte) | postcard(Message)`.
//! Das Präfix filtert fremden ESP-NOW-Verkehr in der Nachbarschaft heraus.

use serde::{Deserialize, Serialize};

use crate::Room;

pub const MAGIC: [u8; 2] = *b"LM";
pub const VERSION: u8 = 1;
const HEADER_LEN: usize = MAGIC.len() + 1;

/// Größter kodierter Rahmen; ESP-NOW erlaubt 250 Byte.
pub const MAX_FRAME_LEN: usize = 32;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Message {
    Status(Status),
    Command(Command),
}

/// Knoten → Gateway, einmal pro Wachphase.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Status {
    pub room: Room,
    /// Fortlaufende Nummer; das Gateway antwortet mit derselben Nummer.
    pub seq: u16,
    /// Aktuelle Öffnung in Prozent.
    pub position: u8,
    pub battery_mv: u16,
    pub flags: StatusFlags,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct StatusFlags(pub u8);

impl StatusFlags {
    /// Knoten hat wegen fehlender Verbindung auf 100 % geöffnet.
    pub const FAIL_SAFE: u8 = 1 << 0;
    /// Akku fast leer, Gitter wurde geöffnet.
    pub const BATTERY_CRITICAL: u8 = 1 << 1;
    /// Akku sollte bald geladen werden.
    pub const BATTERY_LOW: u8 = 1 << 2;
    /// Erster Start nach Reset/Flashen (kein Deep-Sleep-Wake).
    pub const COLD_BOOT: u8 = 1 << 3;
    /// Antrieb gestört: Winkelsensor ohne Magnet oder Motor blockiert (Variante „schnecke“).
    pub const DRIVE_FAULT: u8 = 1 << 4;
    /// Versorgung über Kabel: `battery_mv` ist dann die Versorgungsspannung (12 V).
    pub const MAINS_POWERED: u8 = 1 << 5;

    pub const fn contains(self, flag: u8) -> bool {
        self.0 & flag != 0
    }

    pub fn set(&mut self, flag: u8) {
        self.0 |= flag;
    }
}

/// Gateway → Knoten, als Antwort auf einen [`Status`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Command {
    pub room: Room,
    /// Echo von [`Status::seq`].
    pub seq: u16,
    /// Soll-Öffnung in Prozent.
    pub target: u8,
    /// Untergrenze, die der Knoten nie unterschreitet.
    pub min_position: u8,
    /// Schlafdauer bis zur nächsten Meldung.
    pub sleep_s: u16,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DecodeError {
    NotOurs,
    WrongVersion(u8),
    Malformed,
}

/// Kodiert `msg` in `buf` und gibt den belegten Teil zurück.
pub fn encode<'a>(msg: &Message, buf: &'a mut [u8]) -> Result<&'a [u8], postcard::Error> {
    if buf.len() < HEADER_LEN {
        return Err(postcard::Error::SerializeBufferFull);
    }
    buf[..2].copy_from_slice(&MAGIC);
    buf[2] = VERSION;
    let len = postcard::to_slice(msg, &mut buf[HEADER_LEN..])?.len();
    Ok(&buf[..HEADER_LEN + len])
}

pub fn decode(frame: &[u8]) -> Result<Message, DecodeError> {
    if frame.len() < HEADER_LEN || frame[..2] != MAGIC {
        return Err(DecodeError::NotOurs);
    }
    if frame[2] != VERSION {
        return Err(DecodeError::WrongVersion(frame[2]));
    }
    postcard::from_bytes(&frame[HEADER_LEN..]).map_err(|_| DecodeError::Malformed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_fits_frame() {
        let messages = [
            Message::Status(Status {
                room: Room::Badezimmer,
                seq: u16::MAX,
                position: 100,
                battery_mv: 4200,
                flags: StatusFlags(0xff),
            }),
            Message::Command(Command {
                room: Room::Kueche,
                seq: u16::MAX,
                target: 55,
                min_position: 15,
                sleep_s: u16::MAX,
            }),
        ];
        for msg in messages {
            let mut buf = [0u8; MAX_FRAME_LEN];
            let frame = encode(&msg, &mut buf).unwrap();
            assert_eq!(decode(frame), Ok(msg));
        }
    }

    #[test]
    fn rejects_foreign_frames() {
        assert_eq!(decode(b""), Err(DecodeError::NotOurs));
        assert_eq!(decode(b"XY\x01\x00"), Err(DecodeError::NotOurs));
        assert_eq!(decode(b"LM\x09\x00"), Err(DecodeError::WrongVersion(9)));
        assert_eq!(decode(b"LM\x01"), Err(DecodeError::Malformed));
    }
}
