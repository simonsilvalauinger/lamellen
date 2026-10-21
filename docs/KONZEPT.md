# Lamellensteuerung für die Warmluft-Ölheizung – Lösungskonzept (v3)

## 1. Ausgangslage

```
                 ┌──────────────────────┐
  Wohnzimmer ◄───┤  Warmlufterzeuger    ├───► Küche
                 │  (Öl)  [Steckdose]   │
                 └───┬──────────────┬───┘
               Klappe│ Schacht 1    │Klappe Schacht 2   (rechteckig)
        ┌────────────┼──────┐       ├──────────────┐
        ▼            ▼      ▼       ▼              ▼
   Schlafzimmer  Spielzi. Arbeitszi. Kinderschlafzi. Badezimmer
```

- 7 Raumauslässe, **alle** sollen gesteuert werden (auch Wohnzimmer und Küche).
- Die Lamellen werden über einen Drehknopf verstellt, der wie eine Flügelmutter aus Kunststoff aussieht.
  Weg: 0–45°, der Knopf dreht nur und wandert nicht axial.
- Die Gitter sind nur geklemmt (keine Schrauben).
- **An den Gittern gibt es keine Steckdosen** → Batteriebetrieb.
- Klappen gibt es nur am Anfang der Schächte (an der Heizung, dort gibt es Strom).
- In jedem Raum hängt bereits ein Temperatur- und Feuchtesensor an HA.
- Drucker: Bambu Lab A1 (offener Bauraum).

## 2. Sicherheit: Mindest-Luftstrom

Weil jetzt alle 7 Auslässe zugehen können, muss das an drei Stellen abgesichert werden:

1. **Mechanik:** Der Aktor kann das Gitter nie ganz schließen (Software-Endlage z. B. 15 %).
2. **Gateway/HA:** Befehle, die die Summe aller Öffnungen unter einen Grenzwert drücken
   würden, werden abgelehnt bzw. korrigiert.
3. **Knoten-Firmware (Fail-Safe):**
   - Batterie fast leer → Gitter auf 100 % fahren, *dann* abschalten.
   - Mehrere Stunden kein Kontakt zum Gateway → auf 100 % fahren.

## 3. Mechanik

> **Umgesetzt:** `hardware/lamellen_aktor.scad`, siehe `hardware/README.md`. Gewählt wurde
> ein MG90S mit 1:3-Zahnradstufe (135° Servo = 45° Lamelle) und einem Halter auf zwei Füßen,
> die auf dem Gitterrahmen kleben oder verschraubt sind.

### Kopplung an die Flügelmutter

```
  Wand/Gitter          Flügelmutter      Mitnehmer-Glocke      Motor
  ───────────┐           ┌─┐            ┌───────────┐       ┌──────┐
             │◄──────────┤ ├────────────┤  Schlitz  ├───────┤ Welle│
  ───────────┘           └─┘            └───────────┘       └──┬───┘
             └────────── Halter (an Gitterrahmen geklemmt/geschraubt) ──┘
```

- Eine **Mitnehmer-Glocke** wird über die Flügelmutter gestülpt (Schlitz mit 0,3 mm Spiel).
- Wandert der Knopf beim Drehen axial (Gewinde), läuft die Glocke auf einem
  **Vielkeil-/Sechskantschaft**, damit sie mitgleiten kann.
- Der **Halter** wird am Gitterrahmen festgeschraubt (vorhandene Schrauben) oder hinter dem
  Gitter verklemmt. Der Motor sitzt raumseitig und außerhalb des warmen Luftstroms.
- CAD in **OpenSCAD**, parametrisch (Flügelspannweite, Dicke, Nabendurchmesser,
  Rahmenmaße).

### Antrieb – abhängig vom Drehbereich

| Drehbereich zu→auf | Antrieb | Positionserfassung |
|---|---|---|
| ≤ 180° | **MG90S-Servo** (direkt oder mit Zahnradübersetzung) | absolut über PWM |
| > 180° / mehrere Umdrehungen | **N20-Schneckengetriebemotor** + DRV8833 | **AS5600** Magnet-Winkelsensor + Umdrehungszähler, Referenz über Blockade an der Endlage |

Ein Schneckengetriebe ist selbsthemmend und hält die Position ohne Strom, was im
Batteriebetrieb ideal ist. Motor, Treiber und Sensor sind nur während einer Bewegung
bestromt.

### Material auf dem Bambu A1

Zuerst die Oberflächentemperatur am Knopf bei Volllast messen.

| Temperatur am Knopf | Material |
|---|---|
| < 60 °C | **PETG** für alles (auf dem A1 problemlos) |
| 60–85 °C | Glocke und knopfnahe Teile in **ASA**. Auf dem A1 machbar für kleine Teile: Brim, Bauteillüfter niedrig, Karton-Haube gegen Zugluft. Halter in PETG |
| > 85 °C | Motor weiter weg, Kopplung über eine Metallwelle (M3-Gewindestange/4-mm-Welle) |

**PLA nicht verwenden.**

## 4. Funk – Architektur für Batteriebetrieb

### Option A – ESP-NOW-Knoten + Gateway an der Heizung (**Empfehlung**)

```
 [Knoten Raum x7]  ── ESP-NOW (2,4 GHz) ──►  [Gateway an der Heizung]  ── WLAN/MQTT ──► Home Assistant
  XIAO ESP32-C6                               ESP32 (Netzteil)
  Akku, Deep-Sleep                            + optional 2 Schachtklappen-Motoren
```

- Der Knoten wacht alle **5 min** auf, sendet einen Status (Position, Akku, RSSI) und bekommt
  in derselben Funkrunde den Sollwert zurück. Danach Bewegung (falls nötig) und wieder
  Deep-Sleep. Wachzeit ca. 50–150 ms, weil kein WLAN-Login und kein DHCP nötig ist.
- Das **Gateway** hängt am Netz, verbindet sich per WLAN mit MQTT und meldet per
  MQTT-Discovery 7 `cover`-Entitäten plus Akku- und RSSI-Sensoren. Hier liegt auch die
  zentrale Sicherheitslogik. Optional steuert es die beiden Schachtklappen.
- **Alles in Rust:** ESP-NOW wird von `esp-radio` (no_std) und von `esp-idf-svc` gut unterstützt.
- Latenz bis 5 min, für eine Heizung irrelevant (einstellbar).
- Hinweis: ESP-NOW muss auf dem WLAN-Kanal des Gateways laufen. Der Knoten scannt beim
  ersten Start die Kanäle und merkt sich den gefundenen Kanal.

### Option B – WLAN direkt mit Deep-Sleep

- Der Knoten wacht alle 10–15 min auf, verbindet sich per WLAN (statische IP, gespeicherter
  BSSID/Kanal) und liest den retained MQTT-Sollwert.
- Kein Gateway nötig, aber jeder WLAN-Login dauert 0,5–3 s. Das ergibt etwa 3–5× mehr
  Energie als Option A und hängt von der WLAN-Abdeckung am Gitter ab.
- Guter Einstieg für den ersten Prototyp. Der Funk-Teil der Firmware ist austauschbar.

### Option C – Zigbee Sleepy End Device (ESP32-C6/H2)

- Technisch ideal: geringster Verbrauch, direkt in ZHA/Z2M, nutzt ein vorhandenes
  Zigbee-Netz.
- **Aber:** Es gibt keinen brauchbaren Zigbee-Stack in reinem Rust, man müsste `esp-zigbee-lib`
  (C) per FFI einbinden. Das ist sinnvoll nur, wenn Rust für diesen Teil kein Muss ist.

### Energiebilanz (Option A, Abschätzung)

| Posten | mAh/Tag |
|---|---|
| 288 Wakes × ~0,1 s × ~60 mA | ~0,5 |
| Deep-Sleep XIAO C6 (~15 µA) | ~0,4 |
| 4 Bewegungen × 2 s × ~250 mA | ~0,6 |
| **Summe** | **~1,5** |

Mit einem 18650-Akku (3000 mAh) ergibt das rechnerisch über 3 Jahre, realistisch reicht es
**sicher mindestens eine Heizperiode**. Geladen wird über den USB-C-Anschluss des XIAO
(Ladeschaltung ist auf dem Board).

## 5. Hardware je Knoten

| Teil | Zweck | ca. € |
|---|---|---|
| Seeed XIAO ESP32-C6 | MCU, ESP-NOW, LiPo-Lader | 6 |
| 18650-Li-Ion 3000 mAh + Halter | Versorgung (an BAT-Pads) | 6 |
| Servo MG90S **oder** N20-Schneckenmotor + DRV8833 + AS5600 | Antrieb | 3 / 8 |
| Boost 5 V mit EN-Pin (z. B. TPS61023-Modul), nur für den Servo | nur während Bewegung an | 2 |
| Spannungsteiler 2×1 MΩ + 100 nF | Akkuspannung messen | – |
| PETG/ASA, Schrauben, Magnet (für AS5600) | Mechanik | 2 |
| **Summe** | | **~20–25** |

Gateway: beliebiger ESP32-C6/S3 + USB-Netzteil an der Heizung, ca. 10 €.

## 6. Software

> **Umgesetzt:** `firmware/protocol` (getestet) und `firmware/node`. Das Gateway folgt.

### Repo-Struktur

```
protocol/        no_std-Crate: Nachrichten (serde + postcard), gemeinsam für Knoten und Gateway
node/            no_std: esp-hal + embassy + esp-radio (ESP-NOW), Deep-Sleep, Motor
gateway/         esp-idf-svc (std): WLAN + ESP-NOW + MQTT-Discovery + OTA + Sicherheitslogik
hardware/        OpenSCAD (parametrisch), STL, Fotos/Maße
homeassistant/   Regel-Automationen / Blueprint, Dashboard
```

### Protokoll (Entwurf)

```rust
// Knoten → Gateway
struct Status { node: u8, seq: u16, position: u8, battery_mv: u16, flags: u8 }
// Gateway → Knoten (Antwort in derselben Wachphase)
struct Command { target: u8, min_position: u8, sleep_s: u16 }
```

ESP-NOW-Verschlüsselung (PMK/LMK) einschalten, damit Nachbarn nichts verstellen können.

### Ablauf Knoten

```
Wake (Timer)
 ├─ Zustand aus RTC-RAM (Position, Kanal, Umdrehungszähler)
 ├─ Akku messen → zu niedrig? → auf 100 % fahren, lange schlafen
 ├─ Status senden, ≤ 30 ms auf Command warten
 │    └─ keine Antwort seit N Runden → Fail-Safe 100 %
 ├─ target ≠ position? → Motor/Boost an, langsam fahren, aus
 └─ Deep-Sleep(sleep_s)
```

## 7. Regelung in Home Assistant

- Die vorhandenen Raumsensoren liefern den Istwert. Pro Raum gibt es einen Sollwert
  (`input_number`) bzw. Zeitplan.
- Eine Blueprint-Automation alle 5 min:
  `Öffnung = clamp(15, 100, 50 + k · (Soll − Ist))`, mit Hysterese, damit nicht jeder
  Zehntelgrad eine Bewegung auslöst (das spart Akku).
- Die Luftfeuchte im Bad kann z. B. eine Mindestöffnung nach dem Duschen erzwingen.
- Der Brenner regelt weiterhin über das vorhandene Thermostat. Die Lamellen verteilen nur.

## 8. Vorgehen

1. Knopf vermessen: Drehwinkel zu→auf, Drehmoment (schwergängig?), wandert er axial?,
   Maße Flügel/Nabe, Befestigung des Gitters, Temperatur am Knopf.
2. Mechanik-Prototyp für **ein** Gitter drucken (PETG), Antrieb mit Testsketch prüfen.
3. Gateway + ein Knoten mit ESP-NOW und MQTT-Discovery.
4. Eine Woche Testbetrieb (Akku-Verbrauch messen, Geräusch, Hitze).
5. Rollout auf 7 Räume, HA-Regelung aktivieren, optional Schachtklappen.
