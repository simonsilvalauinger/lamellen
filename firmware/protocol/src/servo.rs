//! Umrechnung Öffnung (%) → Servo-Pulsbreite → LEDC-Tastgrad.

/// Pulsbreiten für die beiden Endlagen, pro Gitter kalibriert.
///
/// `closed_us > open_us` ist erlaubt, falls das Gitter in die andere
/// Richtung schließt.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ServoCalibration {
    pub closed_us: u16,
    pub open_us: u16,
}

impl ServoCalibration {
    pub fn pulse_us(&self, position: u8) -> u16 {
        let position = i32::from(position.min(100));
        let (closed, open) = (i32::from(self.closed_us), i32::from(self.open_us));
        (closed + (open - closed) * position / 100) as u16
    }
}

pub const PERIOD_US: u32 = 20_000;

/// Tastgrad für einen Timer mit `bits` Auflösung bei 50 Hz.
pub fn duty_for_pulse(pulse_us: u16, bits: u8) -> u32 {
    let max = (1u32 << bits) - 1;
    u32::from(pulse_us) * max / PERIOD_US
}

/// Zwischenpositionen für eine langsame, leise Bewegung von `from` nach `to`.
pub fn ramp(from: u8, to: u8, step: u8) -> impl Iterator<Item = u8> {
    let step = step.max(1);
    let mut current = from;
    let mut done = false;
    core::iter::from_fn(move || {
        if done {
            return None;
        }
        current = if current < to {
            current.saturating_add(step).min(to)
        } else if current > to {
            current.saturating_sub(step).max(to)
        } else {
            current
        };
        done = current == to;
        Some(current)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pulse_interpolates_both_directions() {
        let cal = ServoCalibration { closed_us: 1000, open_us: 2000 };
        assert_eq!(cal.pulse_us(0), 1000);
        assert_eq!(cal.pulse_us(50), 1500);
        assert_eq!(cal.pulse_us(100), 2000);
        assert_eq!(cal.pulse_us(200), 2000);

        let reversed = ServoCalibration { closed_us: 2000, open_us: 1000 };
        assert_eq!(reversed.pulse_us(25), 1750);
    }

    #[test]
    fn duty_matches_period() {
        assert_eq!(duty_for_pulse(20_000, 14), (1 << 14) - 1);
        assert_eq!(duty_for_pulse(1500, 14), 1228);
    }

    #[test]
    fn ramp_ends_on_target() {
        let up: heapless_vec::Vec = ramp(10, 25, 4).collect();
        assert_eq!(up.as_slice(), &[14, 18, 22, 25]);
        let down: heapless_vec::Vec = ramp(25, 20, 4).collect();
        assert_eq!(down.as_slice(), &[21, 20]);
        let same: heapless_vec::Vec = ramp(7, 7, 4).collect();
        assert_eq!(same.as_slice(), &[7]);
    }

    /// Minimaler Sammel-Puffer für die Tests (kein `std`/`alloc` nötig).
    mod heapless_vec {
        pub struct Vec {
            buf: [u8; 32],
            len: usize,
        }
        impl Vec {
            pub fn as_slice(&self) -> &[u8] {
                &self.buf[..self.len]
            }
        }
        impl FromIterator<u8> for Vec {
            fn from_iter<I: IntoIterator<Item = u8>>(iter: I) -> Self {
                let mut v = Vec { buf: [0; 32], len: 0 };
                for x in iter {
                    v.buf[v.len] = x;
                    v.len += 1;
                }
                v
            }
        }
    }
}
