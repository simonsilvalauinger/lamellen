# Lamellensteuerung für die Warmluft-Ölheizung – Lösungskonzept

## 1. Ausgangslage

```
                 ┌──────────────────────┐
  Wohnzimmer ◄───┤                      ├───► Küche          (direkt an der Heizung)
                 │  Warmlufterzeuger    │
                 │  (Öl)                │
                 └───┬──────────────┬───┘
                     │ Schacht 1    │ Schacht 2
        ┌────────────┼──────┐       ├──────────────┐
        ▼            ▼      ▼       ▼              ▼
   Schlafzimmer  Spielzi. Arbeitszi. Kinderschlafzi. Badezimmer
```

7 Auslässe, jeder mit einem manuellen Lamellengitter. Ziel: Jedes Gitter einzeln aus
Home Assistant (HA) heraus auf 0–100 % stellen, ESP32-basiert, Firmware in Rust,
Mechanik aus dem 3D-Drucker.

## 2. Wichtige Randbedingungen (zuerst klären!)

1. **Mindest-Luftmenge der Heizung.** Ein Warmlufterzeuger braucht Luftdurchsatz.
   Sind alle Gitter zu, staut sich die Wärme, der Sicherheitstemperaturbegrenzer (STB)
   löst aus. Deshalb:
   - mechanischer Anschlag: kein Gitter schließt ganz (z. B. min. 15 %), **und/oder**
   - Wohnzimmer + Küche (direkt an der Heizung) bleiben immer offen, **und**
   - Software-Regel in HA: Summe aller Öffnungen ≥ Schwellwert.
2. **Temperatur am Auslass.** Vorher mit einem IR-Thermometer messen (Heizung auf Volllast).
   - PLA erweicht ab ~55 °C → **nicht verwenden**.
   - PETG bis ~75 °C, **ASA/ABS bis ~95 °C** → Empfehlung ASA.
   - Hobby-Servos sind meist nur bis 60 °C spezifiziert → Motor nicht in den Luftstrom,
     sondern seitlich auf der Raumseite montieren.
3. **Stromversorgung.** Gibt es an den Gittern Steckdosen? Das entscheidet zwischen
   Netz- (WLAN geht problemlos) und Batteriebetrieb (dann eher Zigbee/Thread).
4. **Mechanik des Gitters.** Hebel, Drehrad oder Schieber? Wie schwergängig?
   Fotos + Maße bestimmen das Druckteil.
5. Nichts an der Heizung selbst bzw. im heißen Hauptkanal aus Kunststoff verbauen.

## 3. Mechanik – drei Varianten

| Variante | Beschreibung | Vorteile | Nachteile |
|---|---|---|---|
| **A – Nachrüst-Aktor** (Empfehlung) | Gedruckter Halter wird an den Gitterrahmen geklemmt/geschraubt, ein Servo bewegt über Schubstange/Zahnrad den vorhandenen Stellhebel | Gitter bleibt original, rückbaubar, billig | je Gittertyp eigene Adaption |
| **B – Eigenes Motorgitter** | Komplettes Lamellengitter in ASA drucken, Lamellen über Koppelstange vom Servo bewegt, ersetzt das alte Gitter | volle Kontrolle über Anschläge, Optik einheitlich | mehr Druck- und Konstruktionsaufwand, Hitze direkt am Kunststoff |
| **C – Rohrklappe** | Drosselklappe im runden Stichkanal hinter dem Gitter | unsichtbar | Kanalzugang nötig, heiß, Wartung schwierig |

Für die beiden **Schächte** zusätzlich je eine Klappe einzubauen ist möglich, dort ist es
aber heiß → dann eine fertige Metall-Motorklappe (z. B. DN125 mit 24-V-Stellantrieb) per
Relais schalten, nicht drucken.

### Antrieb

| Antrieb | Kosten | Pro | Contra |
|---|---|---|---|
| **MG90S Servo** (Metallgetriebe) | ~3 € | absolute Position ohne Referenzfahrt, einfache PWM-Ansteuerung | brummt/zittert, wenn dauerhaft angesteuert → PWM nach Bewegung abschalten bzw. Versorgung per MOSFET trennen |
| **28BYJ-48 Schrittmotor + ULN2003** | ~3 € | leise, selbsthemmend (hält ohne Strom), hitzetoleranter | braucht Referenzfahrt (Endschalter/Hall-Sensor) |
| MG996R (größer) | ~6 € | viel Kraft für schwergängige Gitter | groß |

CAD-Vorschlag: **OpenSCAD** (parametrisch – Gittermaße als Variablen, gut versionierbar
im Repo) oder FreeCAD/CadQuery.

## 4. Funk + Software – drei Architekturen

### Option 1 – WLAN + MQTT, Rust auf ESP-IDF (**Empfehlung**)

- Hardware: **Seeed XIAO ESP32-C6** (WLAN 6 + 802.15.4 → später auch Thread/Zigbee möglich)
  oder XIAO ESP32-C3. Ein Knoten pro Gitter, 5 V über USB-C-Netzteil.
- Rust-Stack: `esp-idf-svc` / `esp-idf-hal` (std).
  - `EspWifi` für WLAN, `EspMqttClient` für MQTT, LEDC-PWM für den Servo,
    NVS für Konfiguration/letzte Position, `EspOta` für Firmware-Updates über WLAN.
  - Projektstart: `cargo generate esp-rs/esp-idf-template`.
- HA-Anbindung: Mosquitto-Add-on + **MQTT-Discovery**. Jedes Gitter erscheint automatisch
  als `cover`-Entität mit Positionsregler 0–100 %.
- Vorteile: reifstes Rust-Ökosystem, einfach zu debuggen, OTA, kein Zigbee-Coordinator nötig.
- Nachteil: braucht Netzstrom (WLAN ist für Batterie ungeeignet).

Alternative im gleichen Option: `no_std` mit `esp-hal` 1.x + Embassy + `esp-radio`
(ehem. `esp-wifi`) + `rust-mqtt`. Schlanker und schneller beim Booten, aber OTA und MQTT
sind mehr Eigenarbeit.

### Option 2 – Zigbee (ESP32-C6 / ESP32-H2)

- Gerät implementiert den Standard-Cluster **Window Covering (0x0102)** → ZHA erkennt es
  als `cover`; bei Zigbee2MQTT ist ein External Converter nötig.
- Sehr stromsparend als *Sleepy End Device* → **Batteriebetrieb** realistisch
  (Servo bewegt sich nur wenige Male am Tag).
- **Haken für Rust:** Es gibt keinen ausgereiften Zigbee-Stack in reinem Rust. Man muss
  Espressifs C-Bibliothek `esp-zigbee-lib` über `esp-idf-sys` (extra/managed components)
  einbinden und die FFI-Bindings selbst pflegen. Machbar, aber deutlich mehr Aufwand.

### Option 3 – Matter over Thread (ESP32-C6)

- `rs-matter` (reine Rust-Implementierung von Matter) + OpenThread-Bindings.
  Gerätetyp *Window Covering* → native HA-Matter-Integration, batteriefähig.
- Zukunftssicher und „richtig Rust“, aber aktuell noch experimentell; braucht einen
  Thread-Border-Router (z. B. HA Connect ZBT-1/-2 oder ein Thread-fähiger Router).

### Bewertung

| | WLAN/MQTT | Zigbee | Matter/Thread |
|---|---|---|---|
| Reife Rust-Ökosystem | ★★★ | ★ (C-FFI) | ★★ |
| Batteriebetrieb | ✗ | ★★★ | ★★★ |
| Aufwand bis lauffähig | gering | hoch | mittel–hoch |
| HA-Integration | MQTT-Discovery | ZHA / Z2M | Matter |

## 5. Firmware-Design (Option 1)

```
boot
 ├─ NVS lesen: Raumname, Min/Max-Winkel, letzte Position
 ├─ WLAN verbinden, MQTT verbinden (LWT: lamellen/<raum>/availability = offline)
 ├─ Discovery-Config publizieren (retained), "online" publizieren
 ├─ subscribe lamellen/<raum>/set_position  und  lamellen/<raum>/cmd
 └─ Loop
     ├─ Sollwert empfangen → begrenzen auf [min, 100]
     ├─ Servo langsam rampen (leise, schont Getriebe)
     ├─ PWM abschalten, Position in NVS speichern
     └─ lamellen/<raum>/position publizieren (retained)
optional: DS18B20 im Auslass → Zulufttemperatur (zeigt auch, ob die Heizung läuft)
```

Discovery-Payload (Topic `homeassistant/cover/lamelle_schlafzimmer/config`):

```json
{
  "name": "Lamelle Schlafzimmer",
  "unique_id": "lamelle_schlafzimmer",
  "device_class": "damper",
  "command_topic": "lamellen/schlafzimmer/cmd",
  "set_position_topic": "lamellen/schlafzimmer/set_position",
  "position_topic": "lamellen/schlafzimmer/position",
  "availability_topic": "lamellen/schlafzimmer/availability",
  "payload_open": "OPEN", "payload_close": "CLOSE", "payload_stop": "STOP",
  "position_open": 100, "position_closed": 0,
  "device": { "identifiers": ["lamelle_schlafzimmer"], "name": "Lamelle Schlafzimmer",
              "manufacturer": "DIY", "model": "XIAO ESP32-C6 + MG90S" }
}
```

## 6. Regelung in Home Assistant

- Pro Raum ein Temperatursensor **im Raum**, nicht am Gitter (z. B. Zigbee-Sensor
  SNZB-02 / Aqara, oder ein SHT40 an einem eigenen Knoten).
- Pro Raum ein Sollwert (`input_number`) bzw. Zeitplan (`schedule`).
- Einfache P-Regelung als Automation/Template:
  `Öffnung = clamp(min, 100, 50 + k · (Soll − Ist))`, z. B. alle 5 min,
  mit Hysterese, damit die Servos nicht ständig nachstellen.
- Sicherheitsregel: Summe der Öffnungen ≥ Grenzwert, sonst Wohnzimmer/Küche auf 100 %.
- Der Brenner wird weiterhin vom vorhandenen Raumthermostat geregelt – die Lamellen
  verteilen nur die Wärme. Später möglich: Brennerfreigabe per Relais aus HA
  (nur mit potentialfreiem Thermostateingang und fachgerecht!).

## 7. Stückliste je Gitter (Option 1, Variante A)

| Teil | ca. Preis |
|---|---|
| Seeed XIAO ESP32-C6 | 6 € |
| MG90S Servo | 3 € |
| USB-C-Netzteil 5 V/1 A + Kabel | 6 € |
| Kleinteile (Elko 470 µF am Servo, MOSFET, Schrauben) | 1 € |
| ASA-Filament | 1 € |
| **Summe** | **~17 €** → 7 Gitter ≈ 120 € |

## 8. Vorgeschlagene Repo-Struktur

```
firmware/        Rust-Crate (esp-idf-svc), ein Binary, Raum per NVS/Build-Config
hardware/        OpenSCAD-Dateien, STL-Exporte, Fotos/Maße der Gitter
homeassistant/   Automationen, Blueprints, Dashboard-YAML
docs/            dieses Konzept, Verdrahtung
```

## 9. Vorgehen

1. Gitter fotografieren/vermessen, Auslasstemperatur messen, Steckdosen prüfen.
2. Prototyp an **einem** Gitter (Schlafzimmer): Halter drucken, Servo + XIAO,
   Firmware mit MQTT-Discovery.
3. Eine Heizperiode-Woche testen (Lautstärke, Hitze, Mechanik).
4. Auf alle Räume ausrollen, Regelung in HA aktivieren.
