# Hardware: Lamellen-Aktor

Für Edelstahl-Lüftungsgitter mit einem kleinen, rautenförmigen Drehknopf auf dem
Rahmenrand. Der Knopf ist 35 × 9 mm groß und ragt 15 mm heraus. Er dreht 180° und verstellt
die Lamellen dabei um ca. 75°. Im geschlossenen Zustand überlappen sich die Lamellen.

Servo, Akku und Mikrocontroller sitzen in **einem** Gehäuse auf dem 25 mm breiten
Rahmenrand. Nur der Servoturm am Knopf ist hoch, Akku und Elektronik liegen flach daneben.

![Variante kegel](vorschau_kegel.png)

## Varianten

| | **„kegel“ (Standard)** | „direkt“ | „getriebe“ |
|---|---|---|---|
| Antrieb | MG90S (180°) liegt flach unter dem Knopf, zwei gleiche Kegelräder 1:1 | MG90S (180°) steht koaxial vor dem Knopf | 270°-Microservo steht versetzt, Stirnräder 1:1,5 |
| Höhe Servoturm | **39 mm** | 55 mm | 58 mm |
| Drehmoment am Knopf | wie Servo | wie Servo | 1,5-fach |
| Teile | Hülse, Kegelrad, Gehäuse, Deckel | Hülse, Gehäuse, Deckel | Hülse, Ritzel, Gehäuse, Deckel |
| Akku | 18650 oder LiPo | 18650 oder LiPo | nur LiPo (Platz) |
| Bild | ![kegel](vorschau_kegel.png) | ![direkt](vorschau_direkt.png) | ![getriebe](vorschau_getriebe.png) |

Variante wählen: `variante = "kegel";` (oder `"direkt"`, `"getriebe"`) oben in
`lamellen_aktor.scad`.

### Warum Kegelräder und kein Kronenrad

Ein Kronenrad mit Stirnritzel funktioniert nur, wenn das Kronenrad deutlich mehr Zähne hat
als das Ritzel (etwa ab 2:1). Bei 1:1 werden seine Zähne innen vollständig unterschnitten.
Hier ist 1:1 nötig, weil Servo und Knopf beide 180° drehen. Für 1:1 im rechten Winkel ist ein
Paar gleicher Kegelräder die passende Bauform. Deren Achsen schneiden sich über der
Knopfmitte.

### Hinweise zur Variante „kegel“

- Die Servowelle sitzt nicht mittig im Gehäuse. Damit das Kegelrad genau über der Knopfachse
  steht, ragt der Servo **4,3 mm über den Rahmenrand zur Lamellenseite** (`servo_side = 1`).
  Zur Möbelseite ragt nichts über. Das Gehäuse hat dort eine Ausbuchtung, die erst über der
  Hülse beginnt.
- Die Befestigungslaschen des Servos werden nicht gebraucht und können abgeschnitten werden.
  Der Servo liegt in einem Bett mit Anschlägen, die Rippen im Turmdeckel drücken ihn nach
  unten. Ein Streifen dünner Schaumstoff dazwischen nimmt Toleranzen auf.
- `servo_shaft_h` (Oberseite des Servos bis zur Hornauflage, Standard 7 mm) am eigenen
  Servo nachmessen. Davon hängt ab, wo der Servo im Bett liegt.

## Platz am Gitter (gemessen)

107,5 mm unter und 120 mm über der Knopfmitte (`space_below`, `space_above`). OpenSCAD
bricht mit einer Meldung ab, wenn das Gehäuse über den Rahmen hinausragen würde.

| Variante, Akku | Gehäuselänge | über / unter der Knopfmitte | Höhe Turm / Akkufach / Elektronikfach |
|---|---|---|---|
| **kegel, 18650** | 215 mm | 112 / 103 mm | 39 / 25 / 15 mm |
| direkt, 18650 | 201 mm | 112 / 89 mm | 55 / 25 / 15 mm |
| getriebe, LiPo | 208 mm | 119 / 89 mm | 58 / 17 / 15 mm |

```
          Seitenansicht (kegel, 18650)

                ┌───────────┐ 39 mm
                │Servo ⟂Kegel│      ┌──────────────────┐ 25 mm
   ┌──────┐     │   Knopf    │      │   18650-Akku     │
   │XIAO│Plat.  │            │      │                  │
═══╧════╧═══════╧════════════╧══════╧══════════════════╧═══ Rahmen
   ← unten  103 mm        Knopfmitte              112 mm  oben →
```

- **Kabel:** Aus den Fächern laufen die Kabel in je einen Schacht an den Turmenden. Von dort
  geht es über der Hülse bzw. durch das Servobett weiter, nie durch den Drehbereich des
  Knopfs.
- **Wärme:** Akku und Elektronik liegen direkt auf dem Rahmen, der Akku auf 2 mm hohen
  Rippen. In der ersten Heizwoche die Temperatur im Akkufach prüfen: Li-Ion nicht über 45 °C
  laden und nicht über 60 °C betreiben. Wird es zu warm, `rib_h` erhöhen.
- **Funk:** Der XIAO sitzt am unteren Ende, die Antenne zeigt zur Stirnwand und damit weg von
  Akku, Servo und Edelstahl.
- **Laden:** Deckel des Elektronikfachs abschrauben (1 × M2) und USB-C einstecken.

## Teile und Druck (Bambu A1)

| Teil | Material | Ausrichtung |
|---|---|---|
| `mitnehmer` – Rautenhülse mit Kegelrad | PETG | Öffnung nach unten, keine Stützen |
| `ritzel` – Kegelrad für die Servowelle | PETG, 100 % Infill, 0,12 mm Schichten | Horntasche auf dem Bett |
| `gehaeuse` – Turm und beide Fächer in einem Stück | PETG | Rahmenseite aufs Bett, **Baumstützen** unter dem Servobett und dem Dach über dem Knopf |
| `deckel` – Turmdeckel (gesteckt) und zwei Fachdeckel (je 1 × M2) | PETG | flach, alle drei in einer Datei |

```sh
for p in mitnehmer ritzel gehaeuse deckel; do
  openscad -D "part=\"$p\"" -o "$p.stl" lamellen_aktor.scad
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
| `space_below`, `space_above` | Platz von der Knopfmitte bis zum Rahmenende (gemessen: 107,5 / 120 mm) |
| `akku` | `"18650"` oder `"lipo"` |
| `servo_shaft_h` | Servo-Oberseite bis Hornauflage (nachmessen) |
| `servo_side` | Seite, zu der der liegende Servo übersteht (1 = Lamellen) |

## Befestigung

Das Gitter ist nur geklemmt, und der Rahmen ist aus Edelstahl. Das Gehäuse wird mit den
Böden der beiden Fächer per **3M VHB** aufgeklebt (vorher mit Isopropanol entfetten, 24 h
aushärten lassen). Gitter und Aktor bleiben eine Einheit und lassen sich zum Reinigen zusammen
herausziehen.

## Montage

**Kegel (Standard):**
1. Ein einarmiges Horn auf **5 mm** ab Wellenmitte kürzen und in die Tasche des Kegelrads
   legen. Mit der Hornschraube von der Zahnseite aus auf die Servowelle schrauben (Stellung
   siehe Kalibrierung in `firmware/README.md`).
2. Die Befestigungslaschen des Servos abschneiden. Den Servo ins Bett legen, mit der Welle
   zum Knopf und dem langen Gehäuseteil zur Lamellenseite.
3. Akku, Platine und XIAO mit Schaumklebeband in die Fächer kleben. Die Kabel durch die
   Schächte führen und verdrahten.
4. Die Hülse auf den Knopf stecken, das Gehäuse darübersetzen (die Kegelräder müssen
   ineinandergreifen) und aufkleben. Dann die Deckel aufsetzen. Der Turmdeckel drückt den
   Servo ins Bett.

**Direkt:**
1. Das einarmige Horn mit der Mittelschraube auf den Servo schrauben.
2. Die Hülse mit der Tasche auf das Horn drücken. Die Hornachse muss dabei entlang der
   Rautenlängsachse liegen. Zwei kleine Hornschrauben von innen durch das Dach in die
   Hornlöcher drehen.
3. Den Servo von oben in den Zwischenboden stecken und an den Laschen festschrauben.
4. Weiter wie bei „kegel“ ab Schritt 3.

**Getriebe:**
1. Ein 270°-Microservo im MG90S-Format verwenden. Horn auf 6 mm kürzen, in die Tasche des
   Ritzels legen und das Ritzel mit der Mittelschraube auf die Welle schrauben.
2. Den Servo einsetzen, den Mitnehmer auf den Knopf setzen und das Gehäuse aufsetzen (der
   Zapfen greift in die Bohrung). Weiter wie bei „kegel“ ab Schritt 3.

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
