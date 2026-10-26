#!/usr/bin/env python3
"""Kollisionsprüfung für die gedruckten Lamellengitter.

Rendert die Teile in Einbaulage über den ganzen Hub (zu → offen) und prüft, dass
sich keine zwei Teile durchdringen. Eine Gegenprobe muss anschlagen, sonst ist
die Prüfung blind.

  servo           lamellengitter.scad           (Haube, Servo, Kulisse)
  schnecke        lamellengitter_schnecke.scad  (Kammer im Schacht, Schneckenmotor, AS5600, Akku)
  schnecke_kabel  dasselbe mit versorgung="kabel" (WAGO-Klemmen, Zugentlastung)

Aufruf:  python3 tools/check_gitter.py [servo|schnecke|schnecke_kabel ...]   (Standard: alle;
         Exit-Code 1 bei Fehlern)
"""

import itertools
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import trimesh

HERE = Path(__file__).resolve().parent.parent
SCAD = {"servo": HERE / "lamellengitter.scad", "schnecke": HERE / "lamellengitter_schnecke.scad",
        "schnecke_kabel": HERE / "lamellengitter_schnecke.scad"}
DEFINES = {"schnecke_kabel": {"versorgung": '"kabel"'}}
STEPS = [0, 0.25, 0.5, 0.75, 1]
LIMIT = 0.5   # mm³, Rundungsreste der Facettierung
failures = 0


def report(ok: bool, text: str) -> None:
    global failures
    failures += not ok
    print(f"{'OK       ' if ok else 'FEHLER   '} {text}")


class Model:
    def __init__(self, name: str, tmp: Path):
        self.name, self.scad, self.tmp = name, SCAD[name], tmp
        self.fixed = DEFINES.get(name, {})

    def __call__(self, part: str, **defs) -> trimesh.Trimesh:
        defs = {**self.fixed, **defs}
        name = self.name + "_" + part + "".join(f"_{k}{v}" for k, v in defs.items())
        out = self.tmp / f"{name.replace('"', '')}.stl"
        if not out.exists():
            args = ["openscad", "-D", f'part="{part}"']
            for k, v in defs.items():
                args += ["-D", f"{k}={v}"]
            subprocess.run(args + ["-o", str(out), str(self.scad)], check=True, capture_output=True)
        return trimesh.load_mesh(out)

    def n_lamellen(self) -> int:
        args = ["openscad", "-D", 'part="ref_schacht"']
        for k, v in self.fixed.items():
            args += ["-D", f"{k}={v}"]
        result = subprocess.run(args + ["-o", str(self.tmp / "n.stl"), str(self.scad)], capture_output=True, text=True)
        return int(re.search(r"(\d+) Lamellen", result.stderr).group(1))


def overlap(a: trimesh.Trimesh, b: trimesh.Trimesh) -> float:
    if not (a.bounds[0] < b.bounds[1]).all() or not (b.bounds[0] < a.bounds[1]).all():
        return 0.0
    inter = trimesh.boolean.intersection([a, b], engine="manifold")
    return inter.volume if len(inter.faces) else 0.0


def check(name: str, pairs: dict[str, float]) -> None:
    for text, vol in pairs.items():
        report(vol < LIMIT, f"{name}: {text} ({vol:.2f} mm³)")


def check_servo(m: Model) -> None:
    n = m.n_lamellen()
    rahmen, haube = m("einbau_rahmen"), m("einbau_haube")
    servo, elektronik = m("ref_servo"), m("ref_elektronik")
    check("servo", {"Servo hängt frei in der Haube": overlap(haube, servo),
                    "Akku, Platine und XIAO in der Haube": overlap(haube, elektronik),
                    "Servo / Blende": overlap(rahmen, servo)})
    for o in STEPS:
        lam = [m("einbau_lamelle", oeffnung=o, nr=i) for i in range(n)]
        stange, kurbel = m("einbau_koppelstange", oeffnung=o), m("einbau_kurbel", oeffnung=o)
        check(f"servo {o:4.0%}", {
            "Lamellen untereinander": max(overlap(a, b) for a, b in itertools.pairwise(lam)),
            "Lamellen / Rahmen": max(overlap(l, rahmen) for l in lam),
            "Lamellen / Koppelstange": max(overlap(l, stange) for l in lam),
            "Lamellen / Servokurbel": max(overlap(l, kurbel) for l in lam),
            "Koppelstange / Rahmen": overlap(stange, rahmen),
            "Koppelstange / Servokurbel": overlap(stange, kurbel),
            "Servokurbel / Rahmen": overlap(kurbel, rahmen),
            "Servokurbel / Haube": overlap(kurbel, haube),
            "Servokurbel / Servo": overlap(kurbel, servo)})
    # Gegenprobe: Lamellen weiter zu als winkel_zu müssen kollidieren
    a, b = (m("einbau_lamelle", oeffnung=-0.14, nr=i) for i in range(2))
    report(overlap(a, b) > 1, "servo: Gegenprobe – zu weit geschlossene Lamellen stoßen aneinander")


def check_schnecke(m: Model) -> None:
    n = m.n_lamellen()
    v = m.name
    rahmen, deckel = m("einbau_rahmen"), m("einbau_deckel")
    motor, elektronik = m("ref_motor"), m("ref_elektronik")
    pairs = {"Motor / Rahmen": overlap(motor, rahmen),
             "Akku bzw. WAGO, AS5600, Platinen / Rahmen": overlap(elektronik, rahmen),
             "Motor / Elektronik": overlap(motor, elektronik),
             "Deckel / Rahmen": overlap(deckel, rahmen),
             "Deckel / Elektronik": overlap(deckel, elektronik)}
    if v == "schnecke_kabel":
        buegel = m("einbau_klemmbuegel")
        pairs |= {"Klemmbügel / Rahmen": overlap(buegel, rahmen),
                  "Klemmbügel / Elektronik": overlap(buegel, elektronik),
                  "Klemmbügel / Deckel": overlap(buegel, deckel)}
    check(v, pairs)
    for o in STEPS:
        lam = [m("einbau_lamelle", oeffnung=o, nr=i) for i in range(n)]
        stange = m("einbau_koppelstange", oeffnung=o)
        kupplung, halter = m("einbau_kupplung", oeffnung=o), m("einbau_magnethalter", oeffnung=o)
        check(f"{v} {o:4.0%}", {
            "Lamellen untereinander": max(overlap(a, b) for a, b in itertools.pairwise(lam)),
            "Lamellen / Rahmen": max(overlap(l, rahmen) for l in lam),
            "Lamellen / Koppelstange": max(overlap(l, stange) for l in lam),
            "Lamellen / Kupplung": max(overlap(l, kupplung) for l in lam),
            "Lamellen / Magnethalter": max(overlap(l, halter) for l in lam),
            "Koppelstange / Rahmen": overlap(stange, rahmen),
            "Kupplung / Rahmen": overlap(kupplung, rahmen),
            "Kupplung / Motorwelle": overlap(kupplung, m("ref_motor", oeffnung=o)),
            "Magnethalter / Rahmen": overlap(halter, rahmen),
            "Magnethalter / Magnet": overlap(halter, elektronik)})
    # Gegenprobe: Koppelstange in Stellung „zu“, Lamellen halb offen
    stange = m("einbau_koppelstange", oeffnung=0)
    lam = m("einbau_lamelle", oeffnung=0.5, nr=0)
    report(overlap(stange, lam) > 1, f"{v}: Gegenprobe – falsch stehende Koppelstange stößt an die Kurbel")


def main() -> None:
    varianten = sys.argv[1:] or ["servo", "schnecke", "schnecke_kabel"]
    with tempfile.TemporaryDirectory() as tmp:
        for v in varianten:
            {"servo": check_servo, "schnecke": check_schnecke,
             "schnecke_kabel": check_schnecke}[v](Model(v, Path(tmp)))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
