# Hardware: Lamellen-Aktor

Für Edelstahl-Lüftungsgitter mit einem kleinen Drehknopf auf dem Rahmenrand. Der Knopf
verstellt die Lamellen um 45° und dreht sich dabei nur, ohne vor oder zurück zu wandern.
Der Aktor baut **nur entlang des Rahmenrands** (Standard: Servo oberhalb des Knopfs). Er
verdeckt keine Lamellen und passt neben Möbel, die direkt am Gitter stehen.

| Variante „direkt“ (Standard) | Variante „getriebe“ |
|---|---|
| ![direkt](vorschau_direkt.png) | ![getriebe](vorschau_getriebe.png) |
| Servo koaxial vor dem Knopf, 45° Servoweg | 18er-Ritzel + Zahnsegment, 1:3, 135° Servoweg |
| 2 Teile, ca. 53 mm Bauhöhe | 3 Teile, dreifaches Drehmoment |
| für leichtgängige Knöpfe | für schwergängige Knöpfe / das große Wohnzimmergitter |

Variante wählen: `variante = "direkt";` oder `"getriebe"` oben in `lamellen_aktor.scad`.

## Teile und Druck (Bambu A1)

| Teil | Material | Ausrichtung |
|---|---|---|
| `mitnehmer` – Glocke über dem Knopf (+ Zahnsegment) | PETG, bei > 60 °C am Knopf ASA | wird automatisch richtig gedreht, keine Stützen |
| `halter` – Platte mit Servoausschnitt, zwei Füße | PETG | Platte aufs Bett, **Baumstützen nur unter den Füßen** |
| `ritzel` (nur getriebe) | PETG, 100 % Infill | flach |

```sh
for p in mitnehmer halter ritzel; do
  openscad -D 'variante="direkt"' -D "part=\"$p\"" -o "$p.stl" lamellen_aktor.scad
done
```

Erste Probe: nur den `mitnehmer` drucken und auf den Knopf stecken, um das Spiel (`fit`)
zu prüfen.

## Maße, die angepasst werden müssen

| Parameter | Bedeutung |
|---|---|
| `knob_span`, `knob_wing_t` | größte Breite des Knopfs und Breite quer dazu |
| `knob_hub_d`, `knob_h` | Durchmesser des runden Fußes, Höhe über dem Rahmen |
| `engage` | wie tief die Glocke über den Knopf greift (≤ `knob_h`) |
| `feet` | Fußpositionen relativ zur Knopfachse, beide auf dem Rahmenrand |
| `foot_size` | Klebefläche; Breite (x) ≤ Breite des Rahmenrands |
| `servo_dir` | 90 = Servo über dem Knopf, 270 = darunter |

OpenSCAD warnt, wenn ein Fuß mit dem Mitnehmer kollidiert.

## Befestigung

Das Gitter ist nur geklemmt, und der Rahmen ist aus Edelstahl. Am einfachsten werden die
Füße mit **3M VHB** aufgeklebt (vorher mit Isopropanol entfetten, 24 h aushärten lassen).
Das hält auf Edelstahl sehr gut und lässt sich wieder ablösen. Gitter und Aktor bleiben eine
Einheit und lassen sich zum Reinigen zusammen herausziehen.

## Montage

**Direkt:**
1. Das einarmige Horn mit der Mittelschraube auf den Servo schrauben (Stellung siehe
   Kalibrierung in `firmware/README.md`).
2. Die Glocke mit der Tasche auf das Horn drücken. Zwei kleine Hornschrauben von innen durch
   die Glocke in die Hornlöcher drehen.
3. Den Servo von vorn durch die Platte stecken und an den Laschen festschrauben.
4. Den Aktor mit der Glocke über den Knopf setzen und die Füße aufkleben.

**Getriebe:**
1. Horn auf 9 mm ab Wellenmitte kürzen, in die Tasche des Ritzels legen und mit zwei kleinen
   Schrauben fixieren. Das Ritzel mit der Mittelschraube (von unten durch die Senkung) auf die
   Welle schrauben.
2. Servo in die Platte schrauben. Den Mitnehmer auf den Knopf setzen, die Platte aufsetzen
   (der Zapfen greift in die Bohrung) und die Füße aufkleben.

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
- Ein Gehäuse für Akku und Elektronik folgt. Es soll ebenfalls auf dem Rahmenrand sitzen,
  unterhalb des Aktors.
