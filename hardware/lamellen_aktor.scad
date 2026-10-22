// Lamellen-Aktor für Edelstahl-Lüftungsgitter mit Drehknopf am Rahmenrand
//
// Koordinaten: Knopfachse im Ursprung, z zeigt aus der Wand heraus,
// y entlang des Rahmenrands (nach oben), x Richtung Lamellen.
// Der Aktor baut nur entlang des Rahmenrands (servo_dir), damit er neben
// Möbeln Platz hat und keine Lamellen verdeckt.
//
// Varianten:
//   "direkt"   – Servo sitzt koaxial vor dem Knopf, Horn treibt die Glocke
//                direkt an (45° Servoweg). Kompakt, wenig Teile. Standard.
//   "getriebe" – Servo versetzt, 18er-Ritzel treibt ein Zahnsegment an der
//                Glocke (1:3). Dreifaches Drehmoment für schwergängige Knöpfe
//                oder große Gitter (Wohnzimmer).
//
// Export:  openscad -D 'part="mitnehmer"' -o mitnehmer.stl lamellen_aktor.scad
// Teile:   "assembly", "mitnehmer", "halter", "ritzel" (nur Getriebe), "print"
//
// Alle Maße in mm. Erst den Knopf vermessen, dann die Werte unten anpassen.

part     = "assembly";
variante = "direkt";   // "direkt" oder "getriebe"

/* [Knopf (rautenförmig, von vorn gesehen)] */
knob_len    = 35;   // Länge der Raute (Spitze bis Spitze)
knob_w      = 9;    // Breite an der breitesten Stelle
knob_angle  = 90;   // Richtung der Längsachse bei der Montage (90 = senkrecht)
knob_h      = 12;   // wie weit der Knopf aus dem Rahmen ragt – NOCH MESSEN
engage      = 7;    // so tief übergreift die Hülse den Knopf (≤ knob_h)
wall        = 2.4;  // Wandstärke der Hülse
knob_travel = 45;   // Drehweg zu → auf
fit         = 0.3;  // Spiel je Seite (PETG auf dem A1: 0,2–0,3)

/* [Aufbau] */
servo_dir   = 90;   // Richtung, in die der Servo vom Knopf aus baut (90 = nach oben)

/* [Getriebe] */
gear_m      = 1;
z_pinion    = 18;
z_knob      = 54;   // Teilung des Zahnsegments (nur ein Ausschnitt wird gedruckt)
gear_t      = 6;
backlash    = 0.15;

/* [Servo MG90S] */
servo_l          = 22.8;  // Gehäuselänge
servo_w          = 12.4;  // Gehäusebreite
servo_hole_dist  = 27.8;  // Abstand der Befestigungslöcher
servo_hole_d     = 2.0;   // Kernloch für die mitgelieferten Schrauben
servo_shaft_off  = 6.0;   // Wellenmitte ab Gehäuseende
servo_below_tab  = 10.0;  // Lasche bis Hornauflage (Wellenseite)
horn_hub_d       = 7.4;   // Nabe des einarmigen Horns
horn_arm_w       = 5.6;
horn_t           = 1.8;
horn_arm_len     = variante == "direkt" ? 14 : 9;  // Getriebe: Horn kürzen

/* [Halter] */
plate_t     = 3;
axle_d      = 6;        // Führungszapfen am Halter (nur Getriebe)
feet        = variante == "direkt" ? [[0, -32], [0, 34]] : [[0, -32], [0, 64]];
foot_size   = [16, 22]; // Klebefläche je Fuß (VHB) – Breite ≤ Rahmenrand
leg_w       = 9;

$fn = 64;

// ---------------------------------------------------------------- Ableitungen
function dir(a) = [cos(a), sin(a)];

bell_r      = knob_len / 2 + fit + wall;  // Reichweite der Hülse ab Achse
bell_z0     = knob_h - engage;
roof_t      = 4.5;
direct      = variante == "direkt";

r_knob_gear = gear_m * z_knob / 2;
r_pinion    = gear_m * z_pinion / 2;
center_dist = r_knob_gear + r_pinion;
pinion_pos  = direct ? [0, 0] : center_dist * dir(servo_dir);
sector      = 2 * knob_travel + 30;   // deckt beide Drehrichtungen ab

gear_z0     = knob_h + 1.5;
horn_seat   = direct ? knob_h + fit + roof_t : gear_z0 + gear_t;
plate_front = horn_seat + servo_below_tab;  // Servolaschen liegen hier auf
plate_z0    = plate_front - plate_t;
// Mitte zwischen den Servolöchern, vom Wellenmittelpunkt aus
servo_center = pinion_pos + (servo_l / 2 - servo_shaft_off) * dir(servo_dir);

echo(str("Variante ", variante, ", Bauhöhe ab Rahmen ca. ", plate_front + 23, " mm",
         direct ? "" : str(", Achsabstand ", center_dist, " mm, 1:", z_knob / z_pinion)));
assert(plate_z0 > horn_seat + 0.8, "servo_below_tab zu klein für die Platte");
// Das Zahnsegment reicht nur in Richtung Servo über die Glocke hinaus.
function angdiff(a, b) = abs((a - b + 540) % 360 - 180);
function reach(f) = !direct && angdiff(atan2(f[1], f[0]), servo_dir) <= sector / 2 + 10
    ? r_knob_gear + gear_m : bell_r;
for (f = feet)
    if (norm(f) < reach(f) + leg_w * 0.71 + 1)
        echo("WARNUNG: Fuß", f, "kollidiert mit dem Mitnehmer");

// ---------------------------------------------------------------- Zahnrad 2D
function invd(a) = (tan(a) - a * PI / 180) * 180 / PI;

module gear2d(m, z, pa = 20, bl = backlash) {
    rp = m * z / 2;
    rb = rp * cos(pa);
    ra = rp + m;
    rf = rp - 1.25 * m;
    psi = 90 / z - (bl / 2) / rp * 180 / PI;  // halber Zahnwinkel am Teilkreis
    r0 = max(rb, rf);
    n = 8;
    function phi(r) = psi + invd(pa) - invd(acos(rb / r));
    function pt(r, a) = r * [cos(a), sin(a)];
    rs = [for (i = [0:n]) r0 + (ra - r0) * i / n];
    tooth = concat(
        [[0, 0], pt(rf, -phi(r0))],
        [for (r = rs) pt(r, -phi(r))],
        [for (i = [n:-1:0]) pt(rs[i], phi(rs[i]))],
        [pt(rf, phi(r0))]);
    union() {
        circle(r = rf);
        for (i = [0:z - 1]) rotate(i * 360 / z) polygon(tooth);
    }
}

module wedge2d(r, a0, a1) {
    polygon(concat([[0, 0]], [for (i = [0:24]) r * dir(a0 + (a1 - a0) * i / 24)]));
}

module horn_pocket2d() {
    hull() {
        circle(d = horn_hub_d + 2 * fit);
        translate([horn_arm_len - horn_arm_w / 2, 0]) circle(d = horn_arm_w + 2 * fit);
    }
}

module knob2d() {
    rotate(knob_angle) polygon([[knob_len / 2, 0], [0, knob_w / 2], [-knob_len / 2, 0], [0, -knob_w / 2]]);
}

module knob_cavity(h) {
    linear_extrude(h) offset(delta = fit) knob2d();
}

// Hülse um den Knopf; ab Knopfoberkante darf sie breiter werden (Dach = 2D-Kind)
module sleeve(z_top) {
    translate([0, 0, bell_z0]) linear_extrude(knob_h + fit - bell_z0 + 0.01)
        offset(r = wall) offset(delta = fit) knob2d();
    translate([0, 0, knob_h + fit]) linear_extrude(z_top - knob_h - fit) children();
}

// ---------------------------------------------------------------- Teile
// Mitnehmer „direkt“: Glocke über dem Knopf, oben eine Tasche für das Servohorn.
// Das Horn wird von innen mit zwei kleinen Schrauben in der Tasche fixiert.
module mitnehmer_direkt() {
    top = knob_h + fit + roof_t;
    module roof2d() hull() {
        offset(r = wall) offset(delta = fit) knob2d();
        rotate(servo_dir + 180) offset(r = 2.4) horn_pocket2d();
    }
    difference() {
        sleeve(top) roof2d();
        translate([0, 0, bell_z0 - 1]) knob_cavity(engage + 1 + fit);
        // Horntasche, Arm zeigt vom Servo weg
        translate([0, 0, top - horn_t]) rotate(servo_dir + 180) linear_extrude(horn_t + 1) horn_pocket2d();
        // Kopf der Hornschraube
        translate([0, 0, top - horn_t - 2]) cylinder(d = 5.5, h = 3);
        // zwei Schrauben von innen durch die Hornlöcher
        for (x = [horn_arm_len - 6, horn_arm_len - 2.5])
            rotate(servo_dir + 180) translate([x, 0, knob_h]) cylinder(d = 1.4, h = roof_t + 2);
    }
}

// Mitnehmer „getriebe“: Glocke + Zahnsegment Richtung Servo.
module mitnehmer_getriebe() {
    module roof2d() hull() {
        offset(r = wall) offset(delta = fit) knob2d();
        circle(d = axle_d + 6);
    }
    difference() {
        union() {
            sleeve(gear_z0) roof2d();
            translate([0, 0, gear_z0 - 0.01]) linear_extrude(gear_t + 0.01) offset(r = wall) offset(delta = fit) knob2d();
            translate([0, 0, gear_z0]) linear_extrude(gear_t) intersection() {
                gear2d(gear_m, z_knob);
                wedge2d(r_knob_gear + 2 * gear_m, servo_dir - sector / 2, servo_dir + sector / 2);
            }
            // Steg, der das Segment mit der Glocke verbindet
            translate([0, 0, gear_z0]) linear_extrude(gear_t)
                wedge2d(r_knob_gear - 1.25 * gear_m + 0.01, servo_dir - sector / 2, servo_dir + sector / 2);
        }
        translate([0, 0, bell_z0 - 1]) knob_cavity(engage + 1 + fit);
        // Lagerbohrung für den Zapfen am Halter
        translate([0, 0, gear_z0 + gear_t - 3]) cylinder(d = axle_d + 0.4, h = 4);
    }
}

module mitnehmer() { if (direct) mitnehmer_direkt(); else mitnehmer_getriebe(); }

// Ritzel (nur Getriebe): wird mit den Hornschrauben am gekürzten Horn befestigt.
module ritzel() {
    translate(pinion_pos) rotate(servo_dir + 180 + 180 / z_pinion) difference() {
        translate([0, 0, gear_z0]) linear_extrude(gear_t) gear2d(gear_m, z_pinion);
        translate([0, 0, gear_z0 + gear_t - horn_t]) linear_extrude(horn_t + 1) horn_pocket2d();
        translate([0, 0, gear_z0 - 1]) cylinder(d = 2.4, h = gear_t + 2);
        translate([0, 0, gear_z0 - 1]) cylinder(d = 4.8, h = gear_t - horn_t - 0.2);
        for (x = [4.5, 7]) translate([x, 0, gear_z0 + 1]) cylinder(d = 1.4, h = gear_t);
    }
}

module servo_outline(clear = 0) {
    // Gehäusequerschnitt, Welle im Ursprung, Gehäuse in servo_dir
    rotate(servo_dir) translate([-servo_shaft_off - clear, -servo_w / 2 - clear])
        square([servo_l + 2 * clear, servo_w + 2 * clear]);
}

module halter() {
    difference() {
        union() {
            translate([0, 0, plate_z0]) linear_extrude(plate_t) hull() {
                translate(servo_center) rotate(servo_dir) square([servo_hole_dist + 7, servo_w + 8], center = true);
                for (f = feet) translate(f) square(leg_w, center = true);
                if (!direct) circle(d = axle_d + 8);
            }
            for (f = feet) {
                translate([f[0] - leg_w / 2, f[1] - leg_w / 2, 0]) cube([leg_w, leg_w, plate_z0 + 0.01]);
                translate([f[0] - foot_size[0] / 2, f[1] - foot_size[1] / 2, 0]) cube([foot_size[0], foot_size[1], 2.5]);
            }
            // Führungszapfen in die Lagerbohrung des Mitnehmers
            if (!direct) translate([0, 0, gear_z0 + gear_t - 2.5]) cylinder(d = axle_d, h = plate_z0 - gear_z0 - gear_t + 2.6);
        }
        // Servo steckt von vorn durch die Platte, Laschen liegen auf
        translate([pinion_pos[0], pinion_pos[1], plate_z0 - 1]) linear_extrude(plate_t + 2) servo_outline(0.3);
        for (s = [-1, 1])
            translate(concat(servo_center + s * servo_hole_dist / 2 * dir(servo_dir), [plate_z0 - 1]))
                cylinder(d = servo_hole_d, h = plate_t + 2);
    }
}

// ---------------------------------------------------------------- Dummies
module servo_dummy() {
    color("royalblue") translate(pinion_pos) {
        translate([0, 0, horn_seat + 2.5]) linear_extrude(plate_front - horn_seat - 2.5 + 22.5) servo_outline();
        translate([0, 0, plate_front]) linear_extrude(2.5)
            translate(servo_center - pinion_pos) rotate(servo_dir) square([servo_hole_dist + 4.4, servo_w], center = true);
        translate([0, 0, horn_seat - 0.1]) cylinder(d = 4.8, h = 3);
    }
}

module frame_dummy() {
    // Rahmenrand ca. 30 mm breit, Knopf mittig; rechts beginnen die Lamellen
    color("silver", 0.6) translate([-15, -120, -1.5]) cube([30, 240, 1.5]);
    color("dimgray", 0.6) translate([15, -120, -6]) cube([200, 240, 1.5]);
    color("black") linear_extrude(knob_h) knob2d();
}

// ---------------------------------------------------------------- Ausgabe
module print_mitnehmer() {
    if (direct) translate([0, 0, -bell_z0]) mitnehmer();          // Öffnung unten, Dach überbrückt
    else rotate([180, 0, 0]) translate([0, 0, -(gear_z0 + gear_t)]) mitnehmer();  // Zahnsegment auf dem Bett
}
module print_halter() { rotate([180, 0, 0]) translate([0, 0, -plate_front]) halter(); }  // Platte auf dem Bett
module print_ritzel() { translate(concat(-pinion_pos, [-gear_z0])) ritzel(); }

if (part == "assembly") {
    frame_dummy();
    color("orange") mitnehmer();
    if (!direct) color("gold") ritzel();
    color("seagreen", 0.85) halter();
    servo_dummy();
} else if (part == "mitnehmer") print_mitnehmer();
else if (part == "halter") print_halter();
else if (part == "ritzel") print_ritzel();
else if (part == "print") {
    print_mitnehmer();
    translate([60, 0, 0]) print_halter();
    if (!direct) translate([0, 60, 0]) print_ritzel();
}
