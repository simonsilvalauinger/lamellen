# Firmware

| Crate | Ziel | Inhalt |
|---|---|---|
| `protocol/` | `no_std`, Host-testbar | ESP-NOW-Nachrichten, Räume, Servo-Mathematik, Entscheidungs- und Sicherheitslogik |
| `node/` | ESP32-C6 (XIAO), `esp-hal` + Embassy | Knoten am Gitter: aufwachen → Status senden → Sollwert empfangen → Servo fahren → Deep-Sleep |
| `gateway/` | *folgt* | ESP-NOW ↔ MQTT-Discovery für Home Assistant |

## Werkzeuge

```sh
rustup target add riscv32imac-unknown-none-elf
cargo install espflash
```

## Tests (Host)

```sh
cd protocol && cargo test
```

## Knoten bauen und flashen

Jeder Knoten bekommt seinen Raum und seine Servo-Kalibrierung beim Bauen mit. Ein
unbekannter Raum führt schon zu einem Compilerfehler.

```sh
cd node
LAMELLE_ROOM=schlafzimmer LAMELLE_CLOSED_US=1125 LAMELLE_OPEN_US=1875 cargo run --release
```

Gültige Räume: `wohnzimmer`, `kueche`, `schlafzimmer`, `spielzimmer`, `arbeitszimmer`,
`kinderzimmer`, `badezimmer`.

### Kalibrieren

1. Den Knoten zunächst ohne Ritzel flashen. Nach dem Flashen fährt er auf `LAMELLE_OPEN_US` (100 %).
2. Das Gitter von Hand ganz öffnen und das Ritzel so aufsetzen, dass es passt.
3. `LAMELLE_CLOSED_US` so lange anpassen, bis „0 %“ genau „zu“ ist. Ist die Drehrichtung
   falsch, die beiden Werte tauschen.
4. Ohne Gateway öffnet der Knoten nach 3 h von selbst ganz (Fail-Safe). Zum Testen
   `NodeConfig::DEFAULT` in `protocol/src/logic.rs` anpassen.

## Ablauf und Energie

Eine Wachphase dauert etwa 0,1–0,2 s ohne Bewegung. Danach folgt Deep-Sleep, Standard
300 s, vom Gateway einstellbar zwischen 30 und 3600 s.

Sicherheitsregeln (in `protocol/src/logic.rs`, getestet):

- nie unter 15 % Öffnung (`min_position_floor`), unabhängig vom Befehl,
- 36 Runden ohne Gateway → 100 % (Fail-Safe),
- Akku < 3,3 V → 100 % und nur noch alle 6 h aufwachen,
- ab 3 Runden ohne Antwort wird der nächste WLAN-Kanal probiert (das Gateway sendet auf
  dem Kanal seines WLANs),
- Gateway: `enforce_min_total` öffnet zuerst Wohnzimmer und Küche, falls die Summe aller
  Öffnungen zu klein würde.
