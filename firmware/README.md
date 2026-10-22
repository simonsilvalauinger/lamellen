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
LAMELLE_ROOM=schlafzimmer LAMELLE_CLOSED_US=600 LAMELLE_OPEN_US=2400 cargo run --release
```

Gültige Räume: `wohnzimmer`, `kueche`, `schlafzimmer`, `spielzimmer`, `arbeitszimmer`,
`kinderzimmer`, `badezimmer`.

### Kalibrieren

Der Knopf dreht 180° (die Lamellen dabei ca. 75°). Standardwerte: Varianten „stirn“,
„kegel“ und „direkt“ (1:1) 600/2400 µs, Variante „getriebe“ (270°-Servo) etwa 830/2170 µs.
Bei den Zahnradvarianten dreht der Knopf entgegengesetzt zum Servo. Schließt das Gitter bei
100 %, die beiden Werte tauschen.

Den Wert für „offen“ so wählen, dass der Servo **knapp vor** dem Anschlag des Knopfs stehen
bleibt. Drückt er gegen den Anschlag, zieht er Blockierstrom, bis er stromlos geschaltet wird.
Den Anschlag „zu“ erreicht er nie, weil die Firmware mindestens 15 % offen hält.

1. Den Knoten flashen, bevor der Servo mit dem Gitter verbunden ist. Nach dem Flashen fährt
   er auf `LAMELLE_OPEN_US` (100 %).
2. Das Gitter von Hand ganz öffnen und das Horn (direkt) bzw. das Kegelrad oder Ritzel in
   dieser Stellung aufsetzen. Die Kerbverzahnung der Welle rastet in 18°-Schritten, den Rest gleicht
   die Kalibrierung aus.
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
