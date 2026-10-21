//! Entscheidungslogik: was ein Knoten nach einer Funkrunde tut, und wie das
//! Gateway die Mindest-Luftmenge der Heizung sicherstellt.

use crate::{Command, Room};

/// Feste Grenzen, die kein Befehl aus der Ferne aushebeln kann.
#[derive(Clone, Copy, Debug)]
pub struct NodeConfig {
    /// Absolute Untergrenze der Öffnung (mechanischer Schutz der Heizung).
    pub min_position_floor: u8,
    /// Nach so vielen Runden ohne Antwort öffnet der Knoten ganz.
    pub fail_safe_after_misses: u8,
    /// Ab so vielen Runden ohne Antwort wird der nächste Kanal probiert.
    pub hop_channel_after_misses: u8,
    pub battery_low_mv: u16,
    /// Darunter: Gitter öffnen und nur noch selten aufwachen.
    pub battery_critical_mv: u16,
    pub default_sleep_s: u16,
    pub min_sleep_s: u16,
    pub max_sleep_s: u16,
    /// Schlafdauer bei kritischem Akku.
    pub critical_sleep_s: u16,
}

impl NodeConfig {
    pub const DEFAULT: NodeConfig = NodeConfig {
        min_position_floor: 15,
        // 36 × 5 min = 3 h ohne Gateway.
        fail_safe_after_misses: 36,
        hop_channel_after_misses: 3,
        battery_low_mv: 3500,
        battery_critical_mv: 3300,
        default_sleep_s: 300,
        min_sleep_s: 30,
        max_sleep_s: 3600,
        critical_sleep_s: 6 * 3600,
    };
}

/// Zustand, der den Deep-Sleep überlebt.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct NodeMemory {
    pub position: u8,
    pub target: u8,
    pub min_position: u8,
    pub misses: u8,
    pub channel: u8,
    pub seq: u16,
    pub sleep_s: u16,
}

impl NodeMemory {
    /// Nach dem Flashen ist das Gitter in unbekannter Lage, daher sicher offen.
    pub const fn initial(cfg: &NodeConfig) -> Self {
        NodeMemory {
            position: 100,
            target: 100,
            min_position: cfg.min_position_floor,
            misses: 0,
            channel: 1,
            seq: 0,
            sleep_s: cfg.default_sleep_s,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Plan {
    /// Anzufahrende Öffnung; gleich `position` heißt: nicht bewegen.
    pub target: u8,
    pub sleep_s: u16,
    pub fail_safe: bool,
    pub battery_critical: bool,
}

pub const fn next_channel(channel: u8) -> u8 {
    if channel >= 13 { 1 } else { channel + 1 }
}

/// Wertet eine Funkrunde aus und aktualisiert `mem` (außer `position`, die
/// erst nach der Bewegung gesetzt wird).
pub fn decide(
    mem: &mut NodeMemory,
    reply: Option<&Command>,
    battery_mv: u16,
    cfg: &NodeConfig,
) -> Plan {
    match reply {
        Some(cmd) => {
            mem.misses = 0;
            mem.min_position = cmd.min_position.clamp(cfg.min_position_floor, 100);
            mem.target = cmd.target.clamp(mem.min_position, 100);
            mem.sleep_s = cmd.sleep_s.clamp(cfg.min_sleep_s, cfg.max_sleep_s);
        }
        None => {
            mem.misses = mem.misses.saturating_add(1);
            if mem.misses >= cfg.hop_channel_after_misses {
                mem.channel = next_channel(mem.channel);
            }
            mem.sleep_s = cfg.default_sleep_s;
        }
    }

    let battery_critical = battery_mv < cfg.battery_critical_mv;
    let fail_safe = mem.misses >= cfg.fail_safe_after_misses;

    if battery_critical {
        Plan { target: 100, sleep_s: cfg.critical_sleep_s, fail_safe, battery_critical }
    } else if fail_safe {
        Plan { target: 100, sleep_s: mem.sleep_s, fail_safe, battery_critical }
    } else {
        Plan { target: mem.target, sleep_s: mem.sleep_s, fail_safe, battery_critical }
    }
}

/// Hebt Öffnungen an, bis ihre Summe mindestens `min_sum` Prozentpunkte
/// beträgt. Räume an der Heizung werden zuerst geöffnet.
///
/// Gibt `true` zurück, wenn etwas geändert wurde.
pub fn enforce_min_total(targets: &mut [u8; Room::COUNT], min_sum: u16) -> bool {
    let sum = |t: &[u8; Room::COUNT]| t.iter().map(|&v| u16::from(v)).sum::<u16>();
    let mut changed = false;
    let order = Room::ALL
        .iter()
        .filter(|r| r.is_next_to_heater())
        .chain(Room::ALL.iter().filter(|r| !r.is_next_to_heater()));
    for room in order {
        let total = sum(targets);
        if total >= min_sum {
            break;
        }
        let slot = &mut targets[room.index()];
        let raise = (min_sum - total).min(u16::from(100 - *slot)) as u8;
        if raise > 0 {
            *slot += raise;
            changed = true;
        }
    }
    changed
}

#[cfg(test)]
mod tests {
    use super::*;

    const CFG: NodeConfig = NodeConfig::DEFAULT;

    fn cmd(target: u8, min_position: u8, sleep_s: u16) -> Command {
        Command { room: Room::Schlafzimmer, seq: 1, target, min_position, sleep_s }
    }

    #[test]
    fn command_is_clamped() {
        let mut mem = NodeMemory::initial(&CFG);
        let plan = decide(&mut mem, Some(&cmd(0, 5, 1)), 4000, &CFG);
        assert_eq!(plan.target, CFG.min_position_floor);
        assert_eq!(plan.sleep_s, CFG.min_sleep_s);

        let plan = decide(&mut mem, Some(&cmd(10, 30, 60_000)), 4000, &CFG);
        assert_eq!(plan.target, 30);
        assert_eq!(plan.sleep_s, CFG.max_sleep_s);
    }

    #[test]
    fn missed_rounds_keep_target_then_hop_then_fail_safe() {
        let mut mem = NodeMemory::initial(&CFG);
        decide(&mut mem, Some(&cmd(40, 15, 300)), 4000, &CFG);

        let plan = decide(&mut mem, None, 4000, &CFG);
        assert_eq!(plan.target, 40);
        assert_eq!(mem.channel, 1);

        for _ in 1..CFG.hop_channel_after_misses {
            decide(&mut mem, None, 4000, &CFG);
        }
        assert_eq!(mem.channel, 2);

        let mut plan = plan;
        while mem.misses < CFG.fail_safe_after_misses {
            plan = decide(&mut mem, None, 4000, &CFG);
        }
        assert!(plan.fail_safe);
        assert_eq!(plan.target, 100);

        // Gateway wieder da → normaler Betrieb.
        let plan = decide(&mut mem, Some(&cmd(40, 15, 300)), 4000, &CFG);
        assert!(!plan.fail_safe);
        assert_eq!(plan.target, 40);
    }

    #[test]
    fn critical_battery_opens() {
        let mut mem = NodeMemory::initial(&CFG);
        let plan = decide(&mut mem, Some(&cmd(20, 15, 300)), 3200, &CFG);
        assert!(plan.battery_critical);
        assert_eq!(plan.target, 100);
        assert_eq!(plan.sleep_s, CFG.critical_sleep_s);
    }

    #[test]
    fn channel_wraps() {
        assert_eq!(next_channel(13), 1);
        assert_eq!(next_channel(6), 7);
    }

    #[test]
    fn min_total_opens_heater_rooms_first() {
        let mut t = [15u8; Room::COUNT];
        assert!(enforce_min_total(&mut t, 250));
        assert_eq!(t[Room::Wohnzimmer.index()], 100);
        assert_eq!(t[Room::Kueche.index()], 75);
        assert_eq!(t[Room::Badezimmer.index()], 15);
        assert_eq!(t.iter().map(|&v| v as u16).sum::<u16>(), 250);

        let mut ok = [50u8; Room::COUNT];
        assert!(!enforce_min_total(&mut ok, 250));
    }
}
