"""Lamellen-Aktor, Variante „stirn“, als exaktes CAD-Modell (CadQuery).

Dieselbe Geometrie wie `lamellen_aktor.scad` mit `variante = "stirn"`, aber als
B-Rep: Bohrungen und Dome sind echte Zylinder, die Zahnflanken echte
Evolventen-Splines. Daraus entstehen die STEP-Dateien für Onshape.

Koordinaten wie im OpenSCAD-Modell: Knopfachse im Ursprung, z aus der Wand
heraus, y entlang des Rahmenrands nach oben, x Richtung Lamellen.

Die Parameter in `P` müssen zu `lamellen_aktor.scad` passen;
`tools/check_cad.py` vergleicht beide Modelle über die Volumina.
"""

from dataclasses import dataclass
from math import acos, ceil, cos, degrees, radians, sin, tan

import cadquery as cq


@dataclass(frozen=True)
class Params:
    # Knopf (rautenförmig, von vorn gesehen)
    knob_len: float = 36.5   # gemessen 35, Passprobe: mind. +1,5 – Längenserie drucken
    knob_w: float = 13.25   # gemessen 10, Breitenserie: 13,25 passt
    knob_angle: float = 90
    knob_h: float = 17
    wall: float = 2.4
    fit: float = 0.3
    # Rahmen
    frame_w: float = 25
    # Zahnkranz an der Hülse und Ritzel
    spur_m: float = 1
    spur_t: float = 4.5
    spur_gap: float = 2.5
    backlash: float = 0.15
    pressure_angle: float = 20
    shelf_t: float = 1.6
    # Servo MG90S
    servo_l: float = 22.8
    servo_w: float = 12.4
    servo_hole_dist: float = 27.8
    servo_hole_d: float = 2.0
    servo_shaft_off: float = 6.0
    servo_body_h: float = 22.7
    servo_shaft_h: float = 7.0
    servo_tab_from_top: float = 4.6
    servo_boss_d: float = 11.8
    horn_hub_d: float = 7.4
    horn_arm_w: float = 5.6
    horn_t: float = 1.8
    horn_arm_len: float = 14
    # Gehäuse
    plate_t: float = 3
    case_wall: float = 2
    base_t: float = 1.6
    lid_t: float = 2
    rib_h: float = 2
    boss_d: float = 5
    foot_len: float = 10
    # Akku 18650 (Länge, Breite, Höhe), Elektronik
    akku_dim: tuple = (70, 18.6, 18.6)
    board_len: float = 24
    elec_h: float = 11
    xiao_len: float = 21.5
    xiao_w: float = 17.8

    # ---------------------------------------------------------------- Ableitungen
    @property
    def bell_r(self): return self.knob_len / 2 + self.fit + 1.2
    @property
    def bell_z0(self): return self.spur_gap
    @property
    def spur_z(self):
        # kleinste Zähnezahl, deren Fußkreis die Hülse mit 0,3 mm Abstand umschließt
        return ceil(2 * ((self.bell_r + 0.3) / self.spur_m + 1.25))
    @property
    def spur_pz(self): return self.spur_z   # 1:1 für 180°-Servo
    @property
    def inner_w(self): return self.frame_w - 2 * self.case_wall
    @property
    def tab_half(self): return self.servo_hole_dist / 2 + 3.2
    @property
    def s_z0(self): return self.spur_gap
    @property
    def s_z1(self): return self.s_z0 + self.spur_t
    @property
    def s_rk(self): return self.spur_m * self.spur_z / 2
    @property
    def s_rp(self): return self.spur_m * self.spur_pz / 2
    @property
    def s_pin_y(self): return -(self.s_rk + self.s_rp)
    @property
    def s_top_face(self): return self.s_z0 + self.servo_shaft_h
    @property
    def s_tab_z(self): return self.s_top_face + self.servo_tab_from_top
    @property
    def s_floor_z0(self): return self.s_tab_z - self.plate_t
    @property
    def s_servo_top(self): return self.s_top_face + self.servo_body_h
    @property
    def s_body_y0(self): return self.s_pin_y - self.servo_shaft_off
    @property
    def s_center_y(self): return self.s_body_y0 + self.servo_l / 2
    @property
    def s_cap_top(self): return self.knob_h + self.fit + 2
    @property
    def s_shelf_z0(self): return self.s_cap_top + 0.5
    @property
    def s_shelf_y0(self): return -self.bell_r - 0.5
    @property
    def z_lid(self):
        return max(self.s_servo_top, self.s_shelf_z0 + self.shelf_t + self.elec_h) + 0.6
    @property
    def tower_top(self):
        return max(self.s_rk + self.spur_m + 1.5,
                   self.s_shelf_y0 + self.board_len + 1 + self.xiao_len + 1) + self.case_wall
    @property
    def tower_bot(self): return self.s_pin_y - self.s_rp - self.spur_m - 1.5 - self.case_wall
    @property
    def akku_y0(self): return self.tower_top + 1
    @property
    def akku_y1(self): return self.akku_y0 + self.akku_dim[0]
    @property
    def boss_top_y(self): return self.akku_y1 + 1 + self.boss_d / 2
    @property
    def y_top(self): return self.boss_top_y + self.boss_d / 2 + 0.5 + self.case_wall
    @property
    def y_bot(self): return self.tower_bot - self.foot_len
    @property
    def z_akku_lid(self): return self.base_t + self.rib_h + self.akku_dim[2] + 1
    @property
    def board_y1(self): return self.s_shelf_y0 + self.board_len
    @property
    def xiao_y0(self): return self.board_y1 + 1


P = Params()


# ---------------------------------------------------------------- Hilfsfunktionen
def box(x0, y0, z0, x1, y1, z1) -> cq.Workplane:
    return cq.Workplane().box(x1 - x0, y1 - y0, z1 - z0, centered=False).translate((x0, y0, z0))


def span(y0, y1, z0, z1, inset=0.0, p=P) -> cq.Workplane:
    """Quader über die Rahmenbreite (wie span2d im OpenSCAD-Modell)."""
    return box(-p.frame_w / 2 + inset, y0 + inset, z0, p.frame_w / 2 - inset, y1 - inset, z1)


def shell(y0, y1, h, p=P) -> cq.Workplane:
    return span(y0, y1, 0, h).cut(span(y0, y1, -1, h + 1, p.case_wall))


def cyl(d, z0, z1, x=0.0, y=0.0) -> cq.Workplane:
    return cq.Workplane().circle(d / 2).extrude(z1 - z0).translate((x, y, z0))


def _pt(r, a_deg):
    return (r * cos(radians(a_deg)), r * sin(radians(a_deg)))


def gear_profile(m, z, pa=20.0, bl=0.0) -> cq.Workplane:
    """Geschlossene 2D-Kontur eines Stirnrads mit Evolventenflanken (als Splines)."""
    rp = m * z / 2
    rb = rp * cos(radians(pa))
    ra = rp + m
    rf = rp - 1.25 * m
    inv = lambda a: degrees(tan(radians(a)) - radians(a))
    psi = 90 / z - degrees((bl / 2) / rp)          # halber Zahnwinkel am Teilkreis
    r0 = max(rb, rf)
    phi = lambda r: psi + inv(pa) - inv(degrees(acos(rb / r)))
    rs = [r0 + (ra - r0) * i / 8 for i in range(9)]
    pitch = 360 / z

    wp = cq.Workplane()
    start = _pt(rf, -phi(r0))
    wp = wp.moveTo(*start)
    for i in range(z):
        a = i * pitch
        if r0 > rf:
            wp = wp.lineTo(*_pt(r0, a - phi(r0)))
        wp = wp.spline([_pt(r, a - phi(r)) for r in rs[1:]], includeCurrent=True)
        wp = wp.threePointArc(_pt(ra, a), _pt(ra, a + phi(ra)))
        wp = wp.spline([_pt(r, a + phi(r)) for r in reversed(rs[:-1])], includeCurrent=True)
        if r0 > rf:
            wp = wp.lineTo(*_pt(rf, a + phi(r0)))
        nxt = (i + 1) * pitch
        end = _pt(rf, nxt - phi(r0))
        if i == z - 1:
            wp = wp.threePointArc(_pt(rf, a + pitch / 2), start)
        else:
            wp = wp.threePointArc(_pt(rf, a + pitch / 2), end)
    return wp.close()


def gear(m, z, t, p=P) -> cq.Workplane:
    return gear_profile(m, z, p.pressure_angle, p.backlash).extrude(t)


def knob_profile(offset=0.0, p=P) -> cq.Workplane:
    a = radians(p.knob_angle)
    rot = lambda x, y: (x * cos(a) - y * sin(a), x * sin(a) + y * cos(a))
    pts = [rot(p.knob_len / 2, 0), rot(0, p.knob_w / 2), rot(-p.knob_len / 2, 0), rot(0, -p.knob_w / 2)]
    wp = cq.Workplane().polyline(pts).close()
    return wp.offset2D(offset, "arc") if offset else wp


def horn_pocket(depth, p=P) -> cq.Workplane:
    """Umriss des einarmigen Servohorns (Hülle zweier Kreise) mit Spiel."""
    r1 = (p.horn_hub_d + 2 * p.fit) / 2
    r2 = (p.horn_arm_w + 2 * p.fit) / 2
    d = p.horn_arm_len - p.horn_arm_w / 2
    al = acos((r1 - r2) / d)
    up1, up2 = (r1 * cos(al), r1 * sin(al)), (d + r2 * cos(al), r2 * sin(al))
    lo1, lo2 = (up1[0], -up1[1]), (up2[0], -up2[1])
    return (cq.Workplane().moveTo(*up1).lineTo(*up2).threePointArc((d + r2, 0), lo2)
            .lineTo(*lo1).threePointArc((-r1, 0), up1).close().extrude(depth))


# ---------------------------------------------------------------- Teile (Einbaulage)
def mitnehmer(p=P) -> cq.Workplane:
    """Rautenhülse über dem Knopf mit Zahnkranz direkt über dem Rahmen."""
    sleeve = (knob_profile(p.fit).offset2D(p.wall, "arc").extrude(p.s_cap_top - p.bell_z0)
              .translate((0, 0, p.bell_z0)))
    sleeve = sleeve.intersect(cyl(2 * p.bell_r, p.bell_z0 - 1, p.s_cap_top + 1))
    # Lücke bei −90° (zum Ritzel hin)
    ring = gear(p.spur_m, p.spur_z, p.spur_t).rotate((0, 0, 0), (0, 0, 1), -90 + 180 / p.spur_z)
    ring = ring.translate((0, 0, p.s_z0))
    cavity = knob_profile(p.fit).extrude(p.knob_h - p.bell_z0 + 1 + p.fit).translate((0, 0, p.bell_z0 - 1))
    return sleeve.union(ring).cut(cavity)


def ritzel_lokal(p=P) -> cq.Workplane:
    """Ritzel im eigenen Koordinatensystem: Horntasche bei z = 0 (Rahmenseite)."""
    body = gear(p.spur_m, p.spur_pz, p.spur_t)
    body = body.cut(horn_pocket(p.horn_t + 1).translate((0, 0, -1)))
    body = body.cut(cyl(p.servo_boss_d + 0.8, -1, p.spur_t + 1))
    for x in (p.horn_arm_len - 5, p.horn_arm_len - 2):
        body = body.cut(cyl(1.4, -1, p.spur_t - 1, x=x))
    return body


def ritzel(p=P) -> cq.Workplane:
    # ein Zahn zeigt zum Knopf (+y); der Zahnkranz hat dort eine Lücke
    return ritzel_lokal(p).rotate((0, 0, 0), (0, 0, 1), 90).translate((0, p.s_pin_y, p.s_z0))


def gehaeuse(p=P) -> cq.Workplane:
    """Turm mit Servoboden und Ablage, flaches Akkufach, Klebefuß unten."""
    w, cw = p.frame_w, p.case_wall
    body = shell(p.tower_bot, p.tower_top, p.z_lid)
    body = body.union(shell(p.tower_top - cw, p.y_top, p.z_akku_lid))
    body = body.union(span(p.tower_top - cw, p.y_top, 0, p.base_t, cw / 2))
    body = body.union(span(p.y_bot, p.tower_bot + cw, 0, p.base_t))
    # Stützrippen zwischen Fuß und Turmwand
    gusset = (cq.Workplane("YZ")
              .polyline([(p.y_bot, 0), (p.tower_bot + cw, 0), (p.tower_bot + cw, p.s_floor_z0),
                         (p.tower_bot, p.s_floor_z0), (p.y_bot, p.base_t)]).close().extrude(cw))
    for x in (-w / 2, w / 2 - cw):
        body = body.union(gusset.translate((x, 0, 0)))
    # Servoboden und Ablage über der Hülse
    body = body.union(span(p.tower_bot, p.s_shelf_y0, p.s_floor_z0, p.s_floor_z0 + p.plate_t, cw / 2))
    body = body.union(span(p.s_shelf_y0 - 1, p.tower_top, p.s_shelf_z0, p.s_shelf_z0 + p.shelf_t, cw / 2))
    # Rippen unter dem Akku, Schraubdom des Akkudeckels
    y = p.akku_y0 + 5
    while y <= p.akku_y1 - 3 + 1e-9:
        body = body.union(box(-p.inner_w / 2, y, p.base_t - 0.01, p.inner_w / 2, y + 2, p.base_t + p.rib_h))
        y += 15
    body = body.union(cyl(p.boss_d, p.base_t - 0.01, p.z_akku_lid, y=p.boss_top_y))

    # Seitenwände unten offen: Zahnkranz/Hülse und Ritzel
    win_k = p.s_rk + p.spur_m + 1
    win_p = p.s_rp + p.spur_m + 1
    for sgn in (-1, 1):
        x0, x1 = (p.inner_w / 2 - 0.01, 2 * w) if sgn > 0 else (-2 * w, -p.inner_w / 2 + 0.01)
        body = body.cut(box(x0, -win_k, -1, x1, win_k, p.s_shelf_z0))
        body = body.cut(box(x0, p.s_pin_y - win_p, -1, x1, p.s_pin_y + win_p, p.s_z1 + 0.7))
    # Servo steckt kopfüber durch den Boden, Laschen liegen oben auf
    body = body.cut(box(-p.servo_w / 2 - 0.3, p.s_body_y0 - 0.3, p.s_floor_z0 - 1,
                        p.servo_w / 2 + 0.3, p.s_body_y0 + p.servo_l + 0.3, p.s_floor_z0 + p.plate_t + 1))
    for sgn in (-1, 1):
        body = body.cut(cyl(p.servo_hole_d, p.s_floor_z0 - 1, p.s_floor_z0 + p.plate_t + 1,
                            y=p.s_center_y + sgn * p.servo_hole_dist / 2))
    # Kabel vom Akkufach auf die Ablage, Schraubloch des Akkudeckels
    body = body.cut(box(-5, p.tower_top - cw - 1, p.s_shelf_z0 + p.shelf_t,
                        5, p.tower_top + 1, p.z_akku_lid - 0.5))
    body = body.cut(cyl(1.8, p.z_akku_lid - 6, p.z_akku_lid + 1, y=p.boss_top_y))
    return body


def _lid(y0, y1, z, screw_y=None, p=P) -> cq.Workplane:
    lid = span(y0, y1, z, z + p.lid_t)
    lip = span(y0, y1, z - 1.5, z + 0.01, p.case_wall + 0.25).cut(
        span(y0, y1, z - 2.5, z + 1, p.case_wall + 1.45))
    lid = lid.union(lip)
    if screw_y is not None:
        lid = lid.cut(cyl(2.4, z - 2, z + p.lid_t + 1, y=screw_y))
        lid = lid.cut(cyl(p.boss_d + 0.6, z - 2, z, y=screw_y))   # Steg am Schraubdom aussparen
        cone = (cq.Workplane().circle(1.2).workplane(offset=1.21).circle(2.3).loft()
                .translate((0, screw_y, z + p.lid_t - 1.2)))
        lid = lid.cut(cone)
    return lid


def deckel_turm(p=P) -> cq.Workplane:
    return _lid(p.tower_bot, p.tower_top, p.z_lid, p=p)


def deckel_akku(p=P) -> cq.Workplane:
    return _lid(p.tower_top, p.y_top, p.z_akku_lid, p.boss_top_y, p=p)


# ---------------------------------------------------------------- Platzhalter
def ref_servo(p=P) -> cq.Workplane:
    s = box(-p.servo_w / 2, p.s_body_y0, p.s_top_face,
            p.servo_w / 2, p.s_body_y0 + p.servo_l, p.s_top_face + p.servo_body_h)
    s = s.union(box(-p.servo_w / 2, p.s_center_y - p.servo_hole_dist / 2 - 2.2, p.s_tab_z,
                    p.servo_w / 2, p.s_center_y + p.servo_hole_dist / 2 + 2.2, p.s_tab_z + 2.5))
    s = s.union(cyl(p.servo_boss_d, p.s_top_face - 4, p.s_top_face + 0.01, y=p.s_pin_y))
    return s.union(cyl(4.8, p.s_z0, p.s_top_face, y=p.s_pin_y))


def ref_akku(p=P) -> cq.Workplane:
    z = p.base_t + p.rib_h + p.akku_dim[2] / 2
    return (cq.Workplane("XZ").circle(p.akku_dim[1] / 2).extrude(-p.akku_dim[0])
            .translate((0, p.akku_y0, z)))


def ref_elektronik(p=P) -> cq.Workplane:
    z = p.s_shelf_z0 + p.shelf_t
    board = box(-p.inner_w / 2 + 0.5, p.board_y1 - p.board_len, z + 0.5,
                p.inner_w / 2 - 0.5, p.board_y1, z + 2.1)
    xiao = box(-p.xiao_w / 2, p.xiao_y0, z + 1, p.xiao_w / 2, p.xiao_y0 + p.xiao_len, z + 2.6)
    return board.union(xiao)


def ref_knopf(p=P) -> cq.Workplane:
    return knob_profile(p=p).extrude(p.knob_h)


def ref_rahmen(p=P) -> cq.Workplane:
    rand = box(-p.frame_w / 2, -120, -1.5, p.frame_w / 2, 120, 0)
    lamellen = box(p.frame_w / 2, -120, -6, p.frame_w / 2 + 200, 120, -4.5)
    return rand.union(lamellen)


# ---------------------------------------------------------------- Druckorientierung
def flip_lid(lid: cq.Workplane, z_top: float) -> cq.Workplane:
    return lid.rotate((0, 0, 0), (1, 0, 0), 180).translate((0, 0, z_top))


PARTS = {
    # Name: (Einbaulage, Druckorientierung)
    "mitnehmer": (mitnehmer, lambda p=P: mitnehmer(p).translate((0, 0, -p.bell_z0))),
    "ritzel": (ritzel, lambda p=P: ritzel_lokal(p).mirror("XY").translate((0, 0, p.spur_t))),
    "gehaeuse": (gehaeuse, gehaeuse),
    "deckel_turm": (deckel_turm, lambda p=P: flip_lid(deckel_turm(p), p.z_lid + p.lid_t)),
    "deckel_akku": (deckel_akku, lambda p=P: flip_lid(deckel_akku(p), p.z_akku_lid + p.lid_t)),
}
REFERENCES = {
    "ref_servo": ref_servo,
    "ref_akku": ref_akku,
    "ref_elektronik": ref_elektronik,
    "ref_knopf": ref_knopf,
    "ref_rahmen": ref_rahmen,
}
COLORS = {
    "mitnehmer": (1.0, 0.55, 0.0),
    "ritzel": (0.95, 0.8, 0.1),
    "gehaeuse": (0.3, 0.6, 0.45),
    "deckel_turm": (0.45, 0.7, 0.55),
    "deckel_akku": (0.45, 0.7, 0.55),
    "ref_servo": (0.25, 0.4, 0.85),
    "ref_knopf": (0.1, 0.1, 0.1),
}
