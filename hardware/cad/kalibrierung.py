"""Kalibrierserie für die Passform der Rautenhülse auf dem Knopf.

Kurze, oben und unten offene Hülsenringe ohne Zahnkranz, je mit einer Lasche,
in die die Breite `knob_w` eingraviert ist. Alle anderen Maße (Länge, Spiel,
Wandstärke) kommen aus `lamellen.P`, damit die passende Probe 1:1 auf die
echte Hülse übertragen werden kann: den Wert der besten Probe als `knob_w` in
beide Modelle eintragen.

Aufruf:  python3 cad/kalibrierung.py
Ergebnis: export/kalibrierung/huelse_passprobe.3mf und stl/huelse_<breite>.stl
"""

import dataclasses
import sys
from pathlib import Path

import cadquery as cq
import trimesh

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lamellen as L  # noqa: E402

# knob_w der Proben: aktueller Wert der Modelle ± 1 mm in 0,5-mm-Schritten
STEPS = [-1.0, -0.5, 0.0, 0.5, 1.0]
WIDTHS = [L.P.knob_w + d for d in STEPS]
HEIGHT = 8.0                                 # Ringhöhe (reicht zum Aufstecken)
TAB = (12.0, 7.0, 1.6)                       # Lasche: Länge, Breite, Dicke
OUT = Path(__file__).resolve().parent.parent / "export" / "kalibrierung"


def probe(knob_w: float) -> cq.Workplane:
    p = dataclasses.replace(L.P, knob_w=knob_w)
    ring = L.knob_profile(p.fit, p).offset2D(p.wall, "arc").extrude(HEIGHT)
    ring = ring.intersect(L.cyl(2 * p.bell_r, -1, HEIGHT + 1))
    ring = ring.cut(L.knob_profile(p.fit, p).extrude(HEIGHT + 2).translate((0, 0, -1)))
    # Lasche quer zur Raute, mittig an der breitesten Stelle
    tab_len, tab_w, tab_t = TAB
    x0 = (p.knob_w / 2 + p.fit + p.wall) - 0.8
    tab = L.box(x0, -tab_w / 2, 0, x0 + tab_len, tab_w / 2, tab_t)
    label = (cq.Workplane().text(f"{knob_w:.2f}".replace(".", ","), 3.6, -0.6,
                                 kind="bold", halign="center", valign="center")
             .translate((x0 + 0.8 + tab_len / 2, 0, tab_t)))
    return ring.union(tab).cut(label)


def main() -> None:
    (OUT / "stl").mkdir(parents=True, exist_ok=True)
    scene = trimesh.Scene()
    for i, w in enumerate(WIDTHS):
        name = f"huelse_{w:.2f}".replace(".", "_")
        path = OUT / "stl" / f"{name}.stl"
        cq.exporters.export(probe(w), str(path), tolerance=0.01, angularTolerance=0.05)
        mesh = trimesh.load_mesh(path)
        mesh.export(path)   # binäres STL
        mesh = mesh.copy()
        mesh.apply_translation([i * 34.0, 0, -mesh.bounds[0][2]])
        scene.add_geometry(mesh, node_name=name, geom_name=name)
        print(f"  {path.name}  (Volumen {mesh.volume:.0f} mm³)")
    scene.export(OUT / "huelse_passprobe.3mf")
    lo, hi = scene.bounds
    print(f"  huelse_passprobe.3mf  ({hi[0] - lo[0]:.0f} × {hi[1] - lo[1]:.0f} mm)")


if __name__ == "__main__":
    main()
