use serde::{Deserialize, Serialize};

/// Ein Raum mit steuerbarem Auslass.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u8)]
pub enum Room {
    Wohnzimmer = 0,
    Kueche = 1,
    Schlafzimmer = 2,
    Spielzimmer = 3,
    Arbeitszimmer = 4,
    Kinderzimmer = 5,
    Badezimmer = 6,
}

impl Room {
    pub const COUNT: usize = 7;

    pub const ALL: [Room; Self::COUNT] = [
        Room::Wohnzimmer,
        Room::Kueche,
        Room::Schlafzimmer,
        Room::Spielzimmer,
        Room::Arbeitszimmer,
        Room::Kinderzimmer,
        Room::Badezimmer,
    ];

    /// Bezeichner für MQTT-Topics und `LAMELLE_ROOM`.
    pub const fn slug(self) -> &'static str {
        match self {
            Room::Wohnzimmer => "wohnzimmer",
            Room::Kueche => "kueche",
            Room::Schlafzimmer => "schlafzimmer",
            Room::Spielzimmer => "spielzimmer",
            Room::Arbeitszimmer => "arbeitszimmer",
            Room::Kinderzimmer => "kinderzimmer",
            Room::Badezimmer => "badezimmer",
        }
    }

    /// Anzeigename in Home Assistant.
    pub const fn name(self) -> &'static str {
        match self {
            Room::Wohnzimmer => "Wohnzimmer",
            Room::Kueche => "Küche",
            Room::Schlafzimmer => "Schlafzimmer",
            Room::Spielzimmer => "Spielzimmer",
            Room::Arbeitszimmer => "Arbeitszimmer",
            Room::Kinderzimmer => "Kinderschlafzimmer",
            Room::Badezimmer => "Badezimmer",
        }
    }

    pub const fn index(self) -> usize {
        self as usize
    }

    /// Wohnzimmer und Küche liegen direkt an der Heizung und werden als erste
    /// geöffnet, wenn die Mindest-Luftmenge unterschritten würde.
    pub const fn is_next_to_heater(self) -> bool {
        matches!(self, Room::Wohnzimmer | Room::Kueche)
    }

    /// `const`, damit ein falscher `LAMELLE_ROOM` schon beim Bauen auffällt.
    pub const fn from_slug(slug: &str) -> Option<Room> {
        let mut i = 0;
        while i < Self::COUNT {
            if str_eq(Self::ALL[i].slug(), slug) {
                return Some(Self::ALL[i]);
            }
            i += 1;
        }
        None
    }
}

const fn str_eq(a: &str, b: &str) -> bool {
    let (a, b) = (a.as_bytes(), b.as_bytes());
    if a.len() != b.len() {
        return false;
    }
    let mut i = 0;
    while i < a.len() {
        if a[i] != b[i] {
            return false;
        }
        i += 1;
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slug_roundtrip() {
        for room in Room::ALL {
            assert_eq!(Room::from_slug(room.slug()), Some(room));
            assert_eq!(Room::ALL[room.index()], room);
        }
        assert_eq!(Room::from_slug("keller"), None);
    }
}
