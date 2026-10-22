"""Kalibrierserien für die Passform der Rautenhülse auf dem Knopf.

Kurze, oben und unten offene Hülsenringe ohne Zahnkranz, je mit einer Lasche,
in die der geprüfte Wert eingraviert ist. Zwei Serien:

  breite  – `knob_w` variiert, Länge wie im Modell   (Gravur z. B. „13,25“)
  laenge  – `knob_len` variiert, Breite wie im Modell (Gravur z. B. „L36,5“)

Alle übrigen Maße (Spiel, Wandstärke) kommen aus `lamellen.P`, damit die
passende Probe 1:1 auf die echte Hülse übertragbar ist: den Wert der besten
Probe in beide Modelle eintragen. Die Serien legen sich um den aktuellen Wert.

Aufruf:  python3 cad/kalibrierung.py [breite] [laenge]   (Standard: beide)
Ergebnis: export/kalibrierung/huelse_<serie>.3mf und stl/huelse_<serie>_<wert>.stl
"""

import dataclasses
import sys
from pathlib import Path

import cadquery as cq
import trimesh

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lamellen as L  # noqa: E402

# Serien: Parameter, Abweichungen vom aktuellen Wert, Gravur
# Länge: bekannt ist „mindestens 1,5 mm zu kurz“, das Modell steht schon auf
# 35 + 1,5 mm, daher nur längere Proben
SERIES = {
    "breite": ("knob_w", [-1.0, -0.5, 0.0, 0.5, 1.0], lambda v: f"{v:.2f}".replace(".", ",")),
    "laenge": ("knob_len", [0.0, 0.5, 1.0, 1.5, 2.0], lambda v: "L" + f"{v:.1f}".replace(".", ",")),
}
HEIGHT = 8.0                                 # Ringhöhe (reicht zum Aufstecken)
TAB = (12.0, 7.0, 1.6)                       # Lasche: Länge, Breite, Dicke
OUT = Path(__file__).resolve().parent.parent / "export" / "kalibrierung"


def probe(param: str, value: float, label: str) -> cq.Workplane:
    p = dataclasses.replace(L.P, **{param: value})
    ring = L.knob_profile(p.fit, p).offset2D(p.wall, "arc").extrude(HEIGHT)
    ring = ring.intersect(L.cyl(2 * p.bell_r, -1, HEIGHT + 1))
    ring = ring.cut(L.knob_profile(p.fit, p).extrude(HEIGHT + 2).translate((0, 0, -1)))
    # Lasche quer zur Raute, mittig an der breitesten Stelle
    tab_len, tab_w, tab_t = TAB
    x0 = (p.knob_w / 2 + p.fit + p.wall) - 0.8
    tab = L.box(x0, -tab_w / 2, 0, x0 + tab_len, tab_w / 2, tab_t)
    label = (cq.Workplane().text(label, 3.2, -0.6,
                                 kind="bold", halign="center", valign="center")
             .translate((x0 + 0.8 + tab_len / 2, 0, tab_t)))
    return ring.union(tab).cut(label)


def export_series(serie: str) -> None:
    param, steps, fmt = SERIES[serie]
    base = getattr(L.P, param)
    scene = trimesh.Scene()
    x = 0.0
    for d in steps:
        value = base + d
        name = f"huelse_{serie}_{value:.2f}".replace(".", "_")
        path = OUT / "stl" / f"{name}.stl"
        cq.exporters.export(probe(param, value, fmt(value)), str(path), tolerance=0.01, angularTolerance=0.05)
        mesh = trimesh.load_mesh(path)
        mesh.export(path)   # binäres STL
        mesh = mesh.copy()
        lo, hi = mesh.bounds
        mesh.apply_translation([x - lo[0], -(lo[1] + hi[1]) / 2, -lo[2]])
        x += hi[0] - lo[0] + 6
        scene.add_geometry(mesh, node_name=name, geom_name=name)
        print(f"  {path.name}  ({param} = {value:.2f} mm)")
    scene.export(OUT / f"huelse_{serie}.3mf")
    lo, hi = scene.bounds
    print(f"  huelse_{serie}.3mf  ({hi[0] - lo[0]:.0f} × {hi[1] - lo[1]:.0f} mm)")


def main() -> None:
    (OUT / "stl").mkdir(parents=True, exist_ok=True)
    for serie in sys.argv[1:] or list(SERIES):
        export_series(serie)


if __name__ == "__main__":
    main()
