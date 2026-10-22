# Hardware: Lamellen-Aktor

Für Edelstahl-Lüftungsgitter mit einem kleinen, rautenförmigen Drehknopf auf dem Rahmenrand
(35 × 9 mm, ragt 15 mm heraus). Der Knopf dreht 180° und verstellt die Lamellen dabei um ca. 75°.
Im geschlossenen Zustand überlappen sich die Lamellen.
Der Aktor baut **nur entlang des Rahmenrands** (Standard: Servo oberhalb des Knopfs). Er
verdeckt keine Lamellen und passt neben Möbel, die direkt am Gitter stehen.

| Variante „direkt“ (Standard) | Variante „getriebe“ |
|---|---|
| ![direkt](vorschau_direkt.png) | ![getriebe](vorschau_getriebe.png) |
| MG90S (180°) koaxial vor dem Knopf | 270°-Microservo, 24er-Ritzel auf 36er-Zahnrad (1:1,5) |
| 2 Teile, ca. 53 mm Bauhöhe | 3 Teile, 1,5-faches Drehmoment |
| für leichtgängige Knöpfe | für schwergängige Knöpfe / das große Wohnzimmergitter |

Variante wählen: `variante = "direkt";` oder `"getriebe"` oben in `lamellen_aktor.scad`.

## Ein Gehäuse für alles

Servo, Akku und Mikrocontroller sitzen in **einem** 25 mm breiten Gehäuse auf dem
Rahmenrand. Es ist gestuft: Nur der Servoturm über dem Knopf ist hoch, Akku und Elektronik
liegen flach daneben direkt auf dem Rahmen.

```
          Seitenansicht (Standard: 18650, „direkt“)

                 ┌────────┐ 55 mm
                 │ Servo  │
   ┌──────┐      ├────────┤      ┌──────────────────┐ 25 mm
   │XIAO│Platine │ Knopf  │      │   18650-Akku     │
═══╧════╧════════╧════════╧══════╧══════════════════╧═══ Rahmen
   ← unten  88,5 mm      Knopfmitte           112 mm  oben →
```

| Akku (`akku = …`) | Länge | über / unter der Knopfmitte | Höhe Akkufach | Laufzeit (Schätzung) |
|---|---|---|---|---|
| `"18650"` – Rundzelle mit Lötfahnen und Schutzschaltung, ca. 3000 mAh (Standard) | 200 mm | 112 / 88,5 mm | 25 mm | mehrere Jahre |
| `"lipo"` – LiPo 102050, ca. 1000 mAh, 50 × 20 × 10 mm | 180 mm | 92 / 88,5 mm | 17 mm | ca. eine Heizperiode |

Servoturm (55 mm, 65 mm lang) und Elektronikfach (15 mm) sind bei beiden gleich.
Gemessener Platz am Gitter: 107,5 mm unter und 120 mm über der Knopfmitte (`space_below`,
`space_above`). OpenSCAD bricht mit einer Meldung ab, wenn das Gehäuse über den Rahmen
hinausragen würde. Die Variante „getriebe“ passt nur mit LiPo.

- **Kabel:** Aus den Fächern laufen die Kabel in je einen Schacht an den Turmenden, durch den
  Zwischenboden und neben dem Servo entlang. Durch den Drehbereich des Knopfs läuft nie ein
  Kabel.
- **Wärme:** Akku und Elektronik liegen direkt auf dem Rahmen, der Akku auf 2 mm hohen
  Rippen. In der ersten Heizwoche die Temperatur im Akkufach prüfen: Li-Ion nicht über 45 °C
  laden und nicht über 60 °C betreiben. Wird es zu warm, `rib_h` erhöhen.
- **Funk:** Der XIAO sitzt am unteren Ende, die Antenne zeigt zur Stirnwand und damit weg von
  Akku und Servo.
- **Laden:** Deckel des Elektronikfachs abschrauben (1 × M2) und USB-C einstecken. Die
  Ladeschaltung sitzt auf dem XIAO.
- **Platine:** Lochraster ca. 21 × 24 mm, Bauteile höchstens 9 mm hoch. Den Elko liegend
  einbauen.

## Teile und Druck (Bambu A1)

| Teil | Material | Ausrichtung |
|---|---|---|
| `mitnehmer` – Rautenhülse über dem Knopf (+ Zahnrad) | PETG | wird automatisch richtig gedreht, keine Stützen |
| `gehaeuse` – Turm und beide Fächer in einem Stück | PETG | Rahmenseite aufs Bett, **Baumstützen nur unter dem Zwischenboden** (Drehbereich) |
| `deckel` – Turmdeckel (gesteckt) und zwei Fachdeckel (je 1 × M2) | PETG | flach, alle drei in einer Datei |
| `ritzel` (nur getriebe) | PETG, 100 % Infill | flach |

```sh
for p in mitnehmer gehaeuse deckel; do
  openscad -D 'variante="direkt"' -D "part=\"$p\"" -o "$p.stl" lamellen_aktor.scad
done
```

Erste Probe: nur den `mitnehmer` drucken und auf den Knopf stecken, um das Spiel (`fit`)
zu prüfen.

## Maße

| Parameter | Bedeutung |
|---|---|
| `knob_len`, `knob_w` | Länge und größte Breite der Raute (gemessen: 35 / 9 mm) |
| `knob_h` | wie weit der Knopf aus dem Rahmen ragt (gemessen: 15 mm) |
| `engage` | wie tief die Hülse über den Knopf greift (≤ `knob_h`) |
| `knob_angle` | Lage der Rautenlängsachse bei der Montage (90 = senkrecht) |
| `frame_w` | Breite des Rahmenrands = Gehäusebreite (gemessen: 25 mm) |
| `akku` | `"18650"` oder `"lipo"` |
| `space_below`, `space_above` | Platz von der Knopfmitte bis zum Rahmenende (gemessen: 107,5 / 120 mm) |

OpenSCAD gibt beim Export die Gehäusemaße aus. Es bricht ab, wenn Servo, Akku oder XIAO
nicht in die Breite passen.

## Befestigung

Das Gitter ist nur geklemmt, und der Rahmen ist aus Edelstahl. Das Gehäuse wird mit den
Böden der beiden Fächer per **3M VHB** aufgeklebt (vorher mit Isopropanol entfetten, 24 h aushärten
lassen). Gitter und Aktor bleiben eine Einheit und lassen sich zum Reinigen zusammen
herausziehen.

## Montage

**Direkt:**
1. Das einarmige Horn mit der Mittelschraube auf den Servo schrauben (Stellung siehe
   Kalibrierung in `firmware/README.md`).
2. Die Hülse mit der Tasche auf das Horn drücken. Die Hornachse muss dabei entlang der
   Rautenlängsachse liegen. Zwei kleine Hornschrauben von innen durch das Dach in die
   Hornlöcher drehen.
3. Den Servo von oben in den Zwischenboden stecken und an den Laschen festschrauben.
4. Akku, Platine und XIAO mit Schaumklebeband in die Fächer kleben. Die Kabel durch die
   Schächte führen und verdrahten. Dann die Deckel aufsetzen.
5. Das Gehäuse mit der Hülse über den Knopf setzen und aufkleben.

**Getriebe:**
1. Ein 270°-Microservo im MG90S-Format verwenden (gleiche Befestigungsmaße). Horn auf 9 mm
   ab Wellenmitte kürzen, in die Tasche des Ritzels legen und mit zwei kleinen Schrauben
   fixieren. Das Ritzel mit der Mittelschraube (von unten durch die Senkung) auf die Welle
   schrauben.
2. Den Servo einsetzen, den Mitnehmer auf den Knopf setzen und das Gehäuse aufsetzen (der
   Zapfen greift in die Bohrung). Weiter wie bei „direkt“.

## Elektronik je Knoten

```
 18650 (+) ──┬── XIAO BAT+            XIAO ESP32-C6
             │                         D0/GPIO0 ◄── Mitte Spannungsteiler 1 MΩ/1 MΩ (+100 nF nach GND)
             ├── 1 MΩ ── D0 ── 1 MΩ ── GND
             │                         D1/GPIO1 ──► Gate 2N7002 (Servo-Strom ein)
             └── AO3401 (P-MOSFET, Source) ── Drain ── 5-V-Boost ── Servo +
                   Gate: 100 kΩ nach Akku+,  über 2N7002 nach GND
                                       D2/GPIO2 ──► Servo-Signal
 18650 (−) ──── GND (XIAO BAT−, Boost, Servo)
```

- Der **P-MOSFET vor dem Boost** ist Pflicht. Ein abgeschalteter Aufwärtswandler lässt die
  Akkuspannung meist trotzdem zum Servo durch, und der Ruhestrom des Servos würde den Akku
  in Tagen leeren.
- 470 µF Elko direkt am Servo gegen Spannungseinbrüche beim Anlaufen.
- Laden über den USB-C-Anschluss des XIAO (Ladeschaltung auf dem Board).
- Die Bauteile sitzen auf einem Stück Lochraster (ca. 21 × 24 mm) im Elektronikfach.
