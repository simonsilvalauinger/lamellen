#!/usr/bin/env python3
"""Kollisionsprüfung für das gedruckte Lamellengitter (lamellengitter.scad).

Rendert die Teile in Einbaulage über den ganzen Hub (zu → offen) und prüft, dass
sich keine zwei Teile durchdringen: Lamellen untereinander und gegen Rahmen,
Koppelstange und Servokurbel, die Kurbel gegen Haube und Servo, Akku und Servo
gegen die Haube. Eine Gegenprobe (Lamellen weiter geschlossen als erlaubt) muss
anschlagen, sonst ist die Prüfung blind.

Aufruf:  python3 tools/check_gitter.py      (Exit-Code 1 bei Fehlern)
"""

import itertools
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import trimesh

HERE = Path(__file__).resolve().parent.parent
SCAD = HERE / "lamellengitter.scad"
LIMIT = 0.5   # mm³, Rundungsreste der Facettierung
failures = 0


def report(ok: bool, text: str) -> None:
    global failures
    failures += not ok
    print(f"{'OK       ' if ok else 'FEHLER   '} {text}")


def render(tmp: Path, part: str, **defs) -> trimesh.Trimesh:
    name = part + "".join(f"_{k}{v}" for k, v in defs.items())
    out = tmp / f"{name}.stl"
    if not out.exists():
        args = ["openscad", "-D", f'part="{part}"']
        for k, v in defs.items():
            args += ["-D", f"{k}={v}"]
        subprocess.run(args + ["-o", str(out), str(SCAD)], check=True, capture_output=True)
    return trimesh.load_mesh(out)


def overlap(a: trimesh.Trimesh, b: trimesh.Trimesh) -> float:
    if not (a.bounds[0] < b.bounds[1]).all() or not (b.bounds[0] < a.bounds[1]).all():
        return 0.0
    inter = trimesh.boolean.intersection([a, b], engine="manifold")
    return inter.volume if len(inter.faces) else 0.0


def n_lamellen() -> int:
    result = subprocess.run(["openscad", "-D", 'part="ref_servo"', "-o", "/dev/null", "--export-format", "stl",
                             str(SCAD)], capture_output=True, text=True)
    return int(re.search(r"(\d+) Lamellen", result.stderr).group(1))


def main() -> None:
    n = n_lamellen()
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        rahmen = render(tmp, "einbau_rahmen")
        haube = render(tmp, "einbau_haube")
        servo = render(tmp, "ref_servo")
        elektronik = render(tmp, "ref_elektronik")
        report(overlap(haube, servo) < LIMIT, "Servo hängt frei in der Haube")
        report(overlap(haube, elektronik) < LIMIT, "Akku, Platine und XIAO passen in die Haube")
        report(overlap(rahmen, servo) < LIMIT, "Servo berührt die Blende nicht")

        for o in [0, 0.25, 0.5, 0.75, 1]:
            lam = [render(tmp, "einbau_lamelle", oeffnung=o, nr=i) for i in range(n)]
            stange = render(tmp, "einbau_koppelstange", oeffnung=o)
            kurbel = render(tmp, "einbau_kurbel", oeffnung=o)
            pairs = {"Lamellen untereinander": max(overlap(a, b) for a, b in itertools.pairwise(lam)),
                     "Lamellen / Rahmen": max(overlap(l, rahmen) for l in lam),
                     "Lamellen / Koppelstange": max(overlap(l, stange) for l in lam),
                     "Lamellen / Servokurbel": max(overlap(l, kurbel) for l in lam),
                     "Koppelstange / Rahmen": overlap(stange, rahmen),
                     "Koppelstange / Servokurbel": overlap(stange, kurbel),
                     "Servokurbel / Rahmen": overlap(kurbel, rahmen),
                     "Servokurbel / Haube": overlap(kurbel, haube),
                     "Servokurbel / Servo": overlap(kurbel, servo)}
            for name, vol in pairs.items():
                report(vol < LIMIT, f"Öffnung {o:4.0%}: {name} ({vol:.2f} mm³)")

        # Gegenprobe: Lamellen 10° weiter zu als winkel_zu müssen kollidieren
        a, b = (render(tmp, "einbau_lamelle", oeffnung=-0.14, nr=i) for i in range(2))
        report(overlap(a, b) > 1, "Gegenprobe: zu weit geschlossene Lamellen stoßen aneinander")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
