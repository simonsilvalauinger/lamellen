#!/usr/bin/env python3
"""Prüft das CadQuery-Modell (cad/lamellen.py) gegen das OpenSCAD-Modell.

1. Gleiche Teile → gleiches Volumen (OpenSCAD facettiert Rundungen, daher 0,5 %
   Toleranz). So fällt auf, wenn Parameter nur in einem Modell geändert wurden.
2. Kollisionen im exakten Modell: Zahneingriff (mit Gegenprobe), Hülse über den
   ganzen Drehweg gegen das Gehäuse, Servo, Ritzel und Deckel.

Aufruf:  python3 tools/check_cad.py      (Exit-Code 1 bei Fehlern)
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import trimesh

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE / "cad"))
import lamellen as L  # noqa: E402

TOLERANCE = 0.005
failures = 0


def report(ok: bool, text: str) -> None:
    global failures
    failures += not ok
    print(f"{'OK       ' if ok else 'FEHLER   '} {text}")


def scad_volume(part: str, tmp: Path) -> float:
    out = tmp / f"{part}.stl"
    subprocess.run(["openscad", "-D", f'part="{part}"', "-D", 'variante="stirn"', "-o", str(out),
                    str(HERE / "lamellen_aktor.scad")], check=True, capture_output=True)
    return trimesh.load_mesh(out).volume


def overlap(a, b) -> float:
    return a.intersect(b).val().Volume() if a.intersect(b).solids().size() else 0.0


def rot(shape, deg, y=0.0):
    return shape.translate((0, -y, 0)).rotate((0, 0, 0), (0, 0, 1), deg).translate((0, y, 0))


with tempfile.TemporaryDirectory() as tmp:
    for name, (einbau, _) in L.PARTS.items():
        v_cq = einbau().val().Volume()
        v_scad = scad_volume(f"einbau_{name}", Path(tmp))
        dev = abs(v_cq - v_scad) / v_scad
        report(dev < TOLERANCE, f"Volumen {name}: CadQuery {v_cq:.1f}, OpenSCAD {v_scad:.1f} mm³ ({dev:.2%})")

m, r, g = L.mitnehmer(), L.ritzel(), L.gehaeuse()
servo = L.ref_servo()
pitch = 360 / L.P.spur_z
eps = 1e-3
report(overlap(m, r) < eps, "Zahnkranz und Ritzel greifen ohne Durchdringung")
report(overlap(rot(m, pitch / 2), r) > 1, "Gegenprobe: um eine halbe Teilung verdreht kollidieren sie")
for a in (20, 45):
    # 1:1, gegensinnig
    report(overlap(rot(m, a), rot(r, -a, L.P.s_pin_y)) < eps, f"Eingriff bleibt sauber nach {a}° Drehung")
for a in (0, 45, 90, 135, 180):
    report(overlap(rot(m, a), g) < eps, f"Hülse {a}° frei gegenüber dem Gehäuse")
    report(overlap(rot(m, a), servo) < eps, f"Hülse {a}° frei gegenüber dem Servo")
report(overlap(r, g) < eps, "Ritzel frei gegenüber dem Gehäuse")
shaft = L.cyl(4.9, L.P.s_z0 - 1, L.P.s_top_face + 0.01, y=L.P.s_pin_y)
report(overlap(r, servo.cut(shaft)) < eps, "Ritzel frei gegenüber dem Servo (außer Welle)")
report(overlap(servo.translate((0, 0, 0.05)), g) < eps, "Servo liegt nur auf dem Boden auf")
report(overlap(L.deckel_turm().translate((0, 0, 0.05)), servo) < eps, "Turmdeckel frei gegenüber dem Servo")
report(overlap(L.deckel_turm().translate((0, 0, 0.05)), g) < eps, "Turmdeckel sitzt auf dem Gehäuse")
report(overlap(L.deckel_akku().translate((0, 0, 0.05)), g) < eps, "Akkudeckel sitzt auf dem Gehäuse")
report(overlap(L.ref_akku().translate((0, 0, 0.05)), g) < eps, "Akku passt ins Akkufach")
report(overlap(L.ref_elektronik().translate((0, 0, 0.05)), g) < eps, "Platine und XIAO passen auf die Ablage")

print(f"\n{failures} Fehler" if failures else "\nAlles in Ordnung")
sys.exit(1 if failures else 0)
