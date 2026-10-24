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

Das gedruckte Lamellengitter (lamellengitter.scad) als Ganzes ersetzt das
Edelstahlgitter; es landet in hardware/export/gitter/ und hat je Druckplatte
eine eigene 3MF-Datei.

Aufruf:  python3 tools/export.py [variante ...]      (Standard: stirn; „gitter“ für das Gitter)
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

# Gedrucktes Lamellengitter: Druckplatten (3MF) mit ihren Teilen
GITTER_SCAD = HERE / "lamellengitter.scad"
GITTER_PLATES = {
    "gitter_rahmen": ["rahmen"],
    "gitter_lamellen": ["lamelle"],          # n-mal, siehe gitter_lamellen()
    "gitter_antrieb": ["haube", "koppelstange", "kurbel"],
    "gitter_proben": ["probe_einschub", "probe_lager"],
}
GITTER_EINBAU = ["rahmen", "lamellen", "koppelstange", "kurbel", "haube"]
GITTER_REFERENCES = ["ref_servo", "ref_elektronik", "ref_schacht"]

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
}
DEFAULT_COLOR = (0.6, 0.6, 0.6)


def openscad(part: str, variante: str | None, out: Path, scad: Path = SCAD) -> trimesh.Trimesh | None:
    """Rendert einen Teil; None, wenn er in dieser Variante leer ist."""
    args = ["openscad", "-D", f'part="{part}"']
    if variante:
        args += ["-D", f'variante="{variante}"']
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


def gitter_lamellen(tmp: Path) -> int:
    """Anzahl der Lamellen aus der Meldung von lamellengitter.scad."""
    result = subprocess.run(["openscad", "-D", 'part="ref_servo"', "-o", str(tmp / "n.stl"), str(GITTER_SCAD)],
                            capture_output=True, text=True)
    return int(result.stderr.split(" Lamellen")[0].rsplit(" ", 1)[1])


def export_gitter() -> None:
    """Gedrucktes Lamellengitter: je Druckplatte eine 3MF, Teile als STL und STEP."""
    target = OUT / "gitter"
    (target / "stl").mkdir(parents=True, exist_ok=True)
    (target / "step").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        n = gitter_lamellen(tmp)
        for plate, parts in GITTER_PLATES.items():
            printed = {}
            for part in parts:
                mesh = openscad(part, None, tmp / f"{part}.stl", GITTER_SCAD)
                mesh.export(target / "stl" / f"{part}.stl")
                print(f"  gitter: {part}.stl")
                if part == "lamelle":
                    printed.update({f"lamelle_{i + 1}": mesh for i in range(n)})
                else:
                    printed[part] = mesh
            arrange(printed).export(target / f"{plate}.3mf")
            print(f"  gitter: {plate}.3mf")

        assembly = []
        for part in [f"einbau_{p}" for p in GITTER_EINBAU] + GITTER_REFERENCES:
            mesh = openscad(part, None, tmp / f"{part}.stl", GITTER_SCAD)
            name = part.removeprefix("einbau_")
            solid = mesh_to_solid(mesh)
            if not part.startswith("ref_"):
                write_step([(name, solid)], target / "step" / f"{name}.step")
                print(f"  gitter: {name}.step")
            assembly.append((name, solid))
        write_step(assembly, target / "lamellengitter_baugruppe.step")
        print("  gitter: lamellengitter_baugruppe.step")


def export(variante: str) -> None:
    if variante == "gitter":
        export_gitter()
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
