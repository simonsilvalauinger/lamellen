#!/usr/bin/env python3
"""Exportiert den Lamellen-Aktor für Bambu Studio und Onshape.

Die Standardvariante „stirn“ kommt aus dem exakten CadQuery-Modell
(cad/lamellen.py): echte Zylinder und Evolventenflanken in den STEP-Dateien.
Alle anderen Varianten werden mit OpenSCAD gerendert und als Netz in
Volumenkörper umgewandelt (ebene Facetten zusammengefasst).

Erzeugt je Variante in hardware/export/<variante>/:
  lamellen_<variante>.3mf          alle Druckteile, druckfertig ausgerichtet (Bambu Studio)
  stl/<teil>.stl                   dieselben Teile einzeln
  step/<teil>.step                 Teile in Einbaulage als Volumenkörper (Onshape)
  lamellen_<variante>_baugruppe.step  alle Teile + Platzhalter für Servo, Knopf, Akku

Die gedruckten Lamellengitter ersetzen das Edelstahlgitter als Ganzes:
„gitter“ (lamellengitter.scad, Servo in einer Haube) und „gitter_schnecke“
(lamellengitter_schnecke.scad, alles im Schacht), dieses auch als
„gitter_schnecke_kabel“ mit 12-V-Versorgung durch den Schacht. Sie landen in
hardware/export/<variante>/ und haben je Druckplatte eine eigene 3MF-Datei.

Aufruf:  python3 tools/export.py [variante ...]      (Standard: stirn; „gitter“, „gitter_schnecke“)
Benötigt: openscad und die Pakete aus tools/requirements.txt.
"""

import contextlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import trimesh
from OCP.BRep import BRep_Builder
from OCP.BRepBuilderAPI import (BRepBuilderAPI_MakePolygon, BRepBuilderAPI_MakeFace,
                                BRepBuilderAPI_MakeSolid, BRepBuilderAPI_Sewing)
from OCP.gp import gp_Pnt
from OCP.IFSelect import IFSelect_RetDone
from OCP.Interface import Interface_Static
from OCP.Quantity import Quantity_Color, Quantity_TOC_RGB
from OCP.ShapeUpgrade import ShapeUpgrade_UnifySameDomain
from OCP.STEPCAFControl import STEPCAFControl_Writer
from OCP.STEPControl import STEPControl_AsIs
from OCP.TCollection import TCollection_ExtendedString
from OCP.TDataStd import TDataStd_Name
from OCP.TDocStd import TDocStd_Document
from OCP.XCAFDoc import XCAFDoc_ColorSurf, XCAFDoc_DocumentTool
from OCP.TopAbs import TopAbs_SHELL
from OCP.TopExp import TopExp_Explorer
from OCP.TopoDS import TopoDS, TopoDS_Compound

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE / "cad"))
SCAD = HERE / "lamellen_aktor.scad"
OUT = HERE / "export"

# Druckteile je Variante (Teilname in der .scad-Datei → Dateiname)
PRINT_PARTS = {
    "mitnehmer": "mitnehmer",
    "ritzel": "ritzel",
    "gehaeuse": "gehaeuse",
    "deckel_turm": "deckel_turm",
    "deckel_akku": "deckel_akku",
    "deckel_elektronik": "deckel_elektronik",
}
REFERENCES = ["ref_servo", "ref_elektronik", "ref_rahmen"]

# Gedruckte Lamellengitter: Druckplatten (3MF) mit ihren Teilen. Eine Anzahl
# "n" bzw. "n-1" richtet sich nach der Zahl der Lamellen im Modell.
GITTER = {
    "gitter": {
        "scad": HERE / "lamellengitter.scad",
        "plates": {
            "gitter_rahmen": [("rahmen", 1)],
            "gitter_lamellen": [("lamelle", "n")],
            "gitter_antrieb": [("haube", 1), ("koppelstange", 1), ("kurbel", 1)],
            "gitter_proben": [("probe_einschub", 1), ("probe_lager", 1)],
        },
        "einbau": ["rahmen", "lamellen", "koppelstange", "kurbel", "haube"],
        "references": ["ref_servo", "ref_elektronik", "ref_schacht"],
    },
    "gitter_schnecke": {
        "scad": HERE / "lamellengitter_schnecke.scad",
        "plates": {
            "schnecke_rahmen": [("rahmen", 1)],
            "schnecke_lamellen": [("lamelle", "n-1"), ("lamelle_antrieb", 1)],
            "schnecke_kleinteile": [("deckel", 1), ("koppelstange", 1), ("kupplung", 1), ("magnethalter", 1)],
            "schnecke_proben": [("probe_einschub", 1), ("probe_lager", 1)],
        },
        "einbau": ["rahmen", "lamellen", "koppelstange", "kupplung", "magnethalter", "deckel"],
        "references": ["ref_motor", "ref_elektronik", "ref_schacht"],
    },
    # Dasselbe Gitter mit 12 V durch den Schacht statt Akku
    "gitter_schnecke_kabel": {
        "scad": HERE / "lamellengitter_schnecke.scad",
        "defines": {"versorgung": '"kabel"'},
        "plates": {
            "kabel_rahmen": [("rahmen", 1)],
            "kabel_lamellen": [("lamelle", "n-1"), ("lamelle_antrieb", 1)],
            "kabel_kleinteile": [("deckel", 1), ("koppelstange", 1), ("kupplung", 1), ("magnethalter", 1),
                                 ("klemmbuegel", 1)],
            "kabel_proben": [("probe_einschub", 1), ("probe_lager", 1)],
        },
        "einbau": ["rahmen", "lamellen", "koppelstange", "kupplung", "magnethalter", "deckel", "klemmbuegel"],
        "references": ["ref_motor", "ref_elektronik", "ref_schacht"],
        "baugruppe": "lamellengitter_schnecke_kabel_baugruppe.step",
    },
}

# Farben in Onshape (RGB 0–1)
COLORS = {
    "mitnehmer": (1.0, 0.55, 0.0),
    "ritzel": (0.95, 0.8, 0.1),
    "gehaeuse": (0.3, 0.6, 0.45),
    "deckel_turm": (0.45, 0.7, 0.55),
    "deckel_akku": (0.45, 0.7, 0.55),
    "deckel_elektronik": (0.45, 0.7, 0.55),
    "ref_servo": (0.25, 0.4, 0.85),
    "ref_knopf": (0.1, 0.1, 0.1),
    "rahmen": (0.92, 0.92, 0.9),
    "lamellen": (0.7, 0.78, 0.88),
    "koppelstange": (1.0, 0.55, 0.0),
    "kurbel": (0.95, 0.8, 0.1),
    "haube": (0.3, 0.6, 0.45),
    "kupplung": (0.95, 0.8, 0.1),
    "magnethalter": (0.95, 0.8, 0.1),
    "deckel": (0.3, 0.6, 0.45),
    "ref_motor": (0.75, 0.75, 0.78),
    "klemmbuegel": (0.95, 0.8, 0.1),
}
DEFAULT_COLOR = (0.6, 0.6, 0.6)


def openscad(part: str, variante: str | None, out: Path, scad: Path = SCAD,
             defines: dict[str, str] | None = None) -> trimesh.Trimesh | None:
    """Rendert einen Teil; None, wenn er in dieser Variante leer ist."""
    args = ["openscad", "-D", f'part="{part}"']
    if variante:
        args += ["-D", f'variante="{variante}"']
    for k, v in (defines or {}).items():
        args += ["-D", f"{k}={v}"]
    result = subprocess.run(args + ["-o", str(out), str(scad)], capture_output=True, text=True)
    if "Current top level object is empty" in result.stderr:
        return None
    if result.returncode != 0:
        sys.exit(f"OpenSCAD-Fehler bei {variante}/{part}:\n{result.stderr}")
    mesh = trimesh.load_mesh(out)
    return mesh if len(mesh.faces) else None


def mesh_to_solid(mesh: trimesh.Trimesh):
    """Dreiecksnetz → Volumenkörper; ebene Dreiecke werden zu Flächen zusammengefasst."""
    sewing = BRepBuilderAPI_Sewing(1e-4)
    for tri in mesh.triangles:
        poly = BRepBuilderAPI_MakePolygon(*(gp_Pnt(*map(float, p)) for p in tri), True)
        face = BRepBuilderAPI_MakeFace(poly.Wire(), True)
        if face.IsDone():
            sewing.Add(face.Face())
    sewing.Perform()
    sewn = sewing.SewedShape()
    builder = BRep_Builder()
    compound = TopoDS_Compound()
    builder.MakeCompound(compound)
    explorer = TopExp_Explorer(sewn, TopAbs_SHELL)
    while explorer.More():
        solid = BRepBuilderAPI_MakeSolid(TopoDS.Shell(explorer.Current())).Solid()
        builder.Add(compound, solid)
        explorer.Next()
    unify = ShapeUpgrade_UnifySameDomain(compound, True, True, True)
    unify.Build()
    return unify.Shape()


@contextlib.contextmanager
def quiet_stdout():
    """OpenCascade schreibt seine Statistik direkt auf den Dateideskriptor 1."""
    sys.stdout.flush()
    saved = os.dup(1)
    with open(os.devnull, "w") as devnull:
        os.dup2(devnull.fileno(), 1)
        try:
            yield
        finally:
            os.dup2(saved, 1)
            os.close(saved)


def write_step(shapes: list[tuple[str, object]], path: Path) -> None:
    """Schreibt benannte, eingefärbte Teile als STEP AP214 (Einheit mm)."""
    doc = TDocStd_Document(TCollection_ExtendedString("XmlOcaf"))
    shape_tool = XCAFDoc_DocumentTool.ShapeTool_s(doc.Main())
    color_tool = XCAFDoc_DocumentTool.ColorTool_s(doc.Main())
    for name, shape in shapes:
        label = shape_tool.AddShape(shape, False)
        TDataStd_Name.Set_s(label, TCollection_ExtendedString(name))
        r, g, b = COLORS.get(name, DEFAULT_COLOR)
        color_tool.SetColor(label, Quantity_Color(r, g, b, Quantity_TOC_RGB), XCAFDoc_ColorSurf)
    Interface_Static.SetCVal_s("write.step.schema", "AP214")
    Interface_Static.SetCVal_s("write.step.unit", "MM")
    writer = STEPCAFControl_Writer()
    writer.SetNameMode(True)
    writer.SetColorMode(True)
    with quiet_stdout():
        writer.Transfer(doc, STEPControl_AsIs)
        status = writer.Write(str(path))
    if status != IFSelect_RetDone:
        sys.exit(f"STEP-Export fehlgeschlagen: {path}")


def arrange(meshes: dict[str, trimesh.Trimesh], gap: float = 8.0) -> trimesh.Scene:
    """Legt die Druckteile nebeneinander auf die Platte (256 × 256 mm beim A1)."""
    scene = trimesh.Scene()
    x = y = row_h = 0.0
    for name, mesh in meshes.items():
        mesh = mesh.copy()
        lo, hi = mesh.bounds
        w, d = hi[0] - lo[0], hi[1] - lo[1]
        if x and x + w > 240:
            x, y, row_h = 0.0, y + row_h + gap, 0.0
        mesh.apply_translation([x - lo[0], y - lo[1], -lo[2]])
        scene.add_geometry(mesh, node_name=name, geom_name=name)
        x += w + gap
        row_h = max(row_h, d)
    return scene


def export_cadquery(variante: str) -> None:
    """Exakte Geometrie aus cad/lamellen.py (nur Variante „stirn“)."""
    import cadquery as cq
    import lamellen as L

    target = OUT / variante
    (target / "stl").mkdir(parents=True, exist_ok=True)
    (target / "step").mkdir(parents=True, exist_ok=True)
    printed, assembly = {}, []
    for name, (einbau, druck) in L.PARTS.items():
        stl = target / "stl" / f"{name}.stl"
        cq.exporters.export(druck(), str(stl), tolerance=0.01, angularTolerance=0.05)
        printed[name] = trimesh.load_mesh(stl)
        printed[name].export(stl)   # binäres STL
        print(f"  {variante}: {name}.stl")
        solid = einbau().val().wrapped
        write_step([(name, solid)], target / "step" / f"{name}.step")
        print(f"  {variante}: {name}.step")
        assembly.append((name, solid))
    arrange(printed).export(target / f"lamellen_{variante}.3mf")
    print(f"  {variante}: lamellen_{variante}.3mf")
    for name, ref in L.REFERENCES.items():
        assembly.append((name, ref().val().wrapped))
    write_step(assembly, target / f"lamellen_{variante}_baugruppe.step")
    print(f"  {variante}: lamellen_{variante}_baugruppe.step")


def gitter_lamellen(scad: Path, tmp: Path, defines: dict[str, str]) -> int:
    """Anzahl der Lamellen aus der Meldung des Modells."""
    args = ["openscad", "-D", 'part="ref_schacht"']
    for k, v in defines.items():
        args += ["-D", f"{k}={v}"]
    result = subprocess.run(args + ["-o", str(tmp / "n.stl"), str(scad)], capture_output=True, text=True)
    return int(result.stderr.split(" Lamellen")[0].rsplit(" ", 1)[1])


def export_gitter(variante: str) -> None:
    """Gedrucktes Lamellengitter: je Druckplatte eine 3MF, Teile als STL und STEP."""
    cfg = GITTER[variante]
    scad = cfg["scad"]
    defines = cfg.get("defines", {})
    target = OUT / variante
    (target / "stl").mkdir(parents=True, exist_ok=True)
    (target / "step").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        n = gitter_lamellen(scad, tmp, defines)
        counts = {"n": n, "n-1": n - 1}
        for plate, parts in cfg["plates"].items():
            printed = {}
            for part, count in parts:
                mesh = openscad(part, None, tmp / f"{part}.stl", scad, defines)
                mesh.export(target / "stl" / f"{part}.stl")
                print(f"  {variante}: {part}.stl")
                count = counts.get(count, count)
                if count == 1:
                    printed[part] = mesh
                else:
                    printed.update({f"{part}_{i + 1}": mesh for i in range(count)})
            arrange(printed).export(target / f"{plate}.3mf")
            print(f"  {variante}: {plate}.3mf")

        assembly = []
        for part in [f"einbau_{p}" for p in cfg["einbau"]] + cfg["references"]:
            mesh = openscad(part, None, tmp / f"{part}.stl", scad, defines)
            name = part.removeprefix("einbau_")
            solid = mesh_to_solid(mesh)
            if not part.startswith("ref_"):
                write_step([(name, solid)], target / "step" / f"{name}.step")
                print(f"  {variante}: {name}.step")
            assembly.append((name, solid))
        baugruppe = cfg.get("baugruppe", f"{scad.stem}_baugruppe.step")
        write_step(assembly, target / baugruppe)
        print(f"  {variante}: {baugruppe}")


def export(variante: str) -> None:
    if variante in GITTER:
        export_gitter(variante)
        return
    if variante == "stirn":
        export_cadquery(variante)
        return
    target = OUT / variante
    (target / "stl").mkdir(parents=True, exist_ok=True)
    (target / "step").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        printed = {}
        for part, name in PRINT_PARTS.items():
            mesh = openscad(part, variante, tmp / f"{part}.stl")
            if mesh is None:
                continue
            mesh.export(target / "stl" / f"{name}.stl")   # binäres STL
            printed[name] = mesh
            print(f"  {variante}: {name}.stl")
        arrange(printed).export(target / f"lamellen_{variante}.3mf")
        print(f"  {variante}: lamellen_{variante}.3mf")

        assembly = []
        for part in [f"einbau_{p}" for p in PRINT_PARTS] + REFERENCES:
            mesh = openscad(part, variante, tmp / f"{part}.stl")
            if mesh is None:
                continue
            name = part.removeprefix("einbau_")
            solid = mesh_to_solid(mesh)
            if not part.startswith("ref_"):
                write_step([(name, solid)], target / "step" / f"{name}.step")
                print(f"  {variante}: {name}.step")
            assembly.append((name, solid))
        write_step(assembly, target / f"lamellen_{variante}_baugruppe.step")
        print(f"  {variante}: lamellen_{variante}_baugruppe.step")


if __name__ == "__main__":
    for v in sys.argv[1:] or ["stirn"]:
        export(v)
