// Lamellen-Aktor für Lüftungsgitter mit Flügelmutter-Drehknopf
//
// Aufbau (Seitenansicht, Gitter links):
//
//   Gitter | Knopf | Mitnehmer+Zahnrad | Halterplatte | Servo (MG90S)
//          |       |  (54 Z.)  <->  Ritzel (18 Z.) am Servohorn
//
// 1:3-Getriebe: 135° Servoweg = 45° Lamellenweg, dreifaches Drehmoment.
// Die Halterplatte steht auf zwei Füßen, die auf dem Gitterrahmen
// aufliegen und dort mit hitzefestem Klebeband (z. B. 3M VHB) oder
// M3-Schrauben befestigt werden.
//
// Export:  openscad -D 'part="mitnehmer"' -o mitnehmer.stl lamellen_aktor.scad
// Teile:   "assembly", "mitnehmer", "ritzel", "halter", "print" (alle flach)
//
// Alle Maße in mm. Erst den Knopf vermessen, dann die Werte unten anpassen.

part = "assembly";

/* [Knopf / Flügelmutter] */
knob_span   = 30;   // Spannweite über beide Flügel
knob_wing_t = 4;    // Dicke eines Flügels
knob_hub_d  = 12;   // Durchmesser der Nabe in der Mitte
knob_h      = 12;   // Höhe des Knopfs über der Gitterfläche
engage      = 7;    // so tief übergreift der Mitnehmer den Knopf
fit         = 0.3;  // Spiel je Seite (PETG auf dem A1: 0,2–0,3)

/* [Getriebe] */
gear_m      = 1;    // Modul
z_pinion    = 18;   // Zähne Ritzel (Servo)
z_knob      = 54;   // Zähne Knopfzahnrad
gear_t      = 6;    // Zahnbreite
backlash    = 0.15;

/* [Servo MG90S] */
servo_l          = 22.8;  // Gehäuselänge
servo_w          = 12.4;  // Gehäusebreite
servo_hole_dist  = 27.8;  // Abstand der Befestigungslöcher
servo_hole_d     = 2.0;   // Kernloch für die mitgelieferten Schrauben
servo_shaft_off  = 6.0;   // Wellenmitte ab Gehäuseende
servo_below_tab  = 10.0;  // Lasche bis Hornauflage (Wellenseite)
horn_hub_d       = 7.4;   // Nabe des einarmigen Horns
horn_arm_len     = 9;     // Horn auf diese Länge kürzen (ab Wellenmitte)
horn_arm_w       = 5.6;
horn_t           = 1.8;

/* [Halter] */
plate_t     = 3;
axle_d      = 8;        // Lagerzapfen des Knopfzahnrads
feet        = [[-34, 22], [-34, -22]];  // Fußpositionen relativ zur Knopfachse
foot_size   = [14, 26];
foot_screw  = true;     // M3-Durchgangslöcher in den Füßen
leg_w       = 8;

$fn = 64;

// ---------------------------------------------------------------- Ableitungen
r_knob_gear   = gear_m * z_knob / 2;
r_pinion      = gear_m * z_pinion / 2;
center_dist   = r_knob_gear + r_pinion;
gear_z0       = knob_h + 1.5;             // Unterkante Zahnräder
gear_z1       = gear_z0 + gear_t;         // Oberkante = Hornauflage
plate_front   = gear_z1 + servo_below_tab; // Laschen liegen hier auf
plate_z0      = plate_front - plate_t;
pinion_pos    = [center_dist, 0];

echo(str("Achsabstand ", center_dist, " mm, Übersetzung 1:", z_knob / z_pinion,
         ", Bauhöhe ab Gitter ca. ", plate_front + 23, " mm"));
assert(plate_z0 > gear_z1 + 0.8, "servo_below_tab zu klein für die Platte");
for (f = feet)
    if (norm(f) < r_knob_gear + gear_m + leg_w / 2 + 1)
        echo("WARNUNG: Fuß", f, "kollidiert mit dem Knopfzahnrad");

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

// ---------------------------------------------------------------- Teile
// Mitnehmer: Glocke über der Flügelmutter + Knopfzahnrad + Lagerzapfen.
module mitnehmer() {
    bell_r = knob_span / 2 + fit + 2.4;
    difference() {
        union() {
            translate([0, 0, gear_z0]) linear_extrude(gear_t) gear2d(gear_m, z_knob);
            // Kegel statt Stufe: druckt ohne Stützen (Glocke unten auf dem Bett)
            translate([0, 0, knob_h - engage])
                cylinder(r1 = bell_r, r2 = max(bell_r, r_knob_gear - 1.25 * gear_m - 0.3),
                         h = gear_z0 - (knob_h - engage) + 0.01);
            translate([0, 0, gear_z1 - 0.01]) cylinder(d = axle_d, h = plate_front - gear_z1 + 1);
        }
        // Aussparung für die Flügelmutter
        translate([0, 0, knob_h - engage - 1]) {
            translate([-(knob_span / 2 + fit), -(knob_wing_t / 2 + fit), 0])
                cube([knob_span + 2 * fit, knob_wing_t + 2 * fit, engage + 1 + fit]);
            cylinder(d = knob_hub_d + 2 * fit, h = engage + 1 + fit);
        }
        // Gewicht sparen
        for (a = [45:90:359])
            rotate(a) translate([r_knob_gear * 0.55, 0, gear_z0 - 1]) cylinder(d = r_knob_gear * 0.45, h = gear_t + 2);
    }
}

// Ritzel: wird mit den Hornschrauben am gekürzten Servohorn verschraubt.
module ritzel() {
    translate([pinion_pos[0], pinion_pos[1], 0]) rotate(180 / z_pinion) difference() {
        translate([0, 0, gear_z0]) linear_extrude(gear_t) gear2d(gear_m, z_pinion);
        // Taschen für Horn (oben) und Hornnabe
        translate([0, 0, gear_z1 - horn_t]) linear_extrude(horn_t + 1) hull() {
            circle(d = horn_hub_d + 2 * fit);
            translate([horn_arm_len - horn_arm_w / 2, 0]) circle(d = horn_arm_w + 2 * fit);
        }
        // Mittelschraube des Horns, von unten zugänglich
        translate([0, 0, gear_z0 - 1]) cylinder(d = 2.4, h = gear_t + 2);
        translate([0, 0, gear_z0 - 1]) cylinder(d = 4.8, h = 1 + gear_t - horn_t - 1.2);
        // zwei kleine Schrauben durch die Hornlöcher
        for (x = [4.5, 7]) translate([x, 0, gear_z0 + 1]) cylinder(d = 1.4, h = gear_t);
    }
}

module servo_outline(clear = 0) {
    // Gehäusequerschnitt, Welle im Ursprung, Gehäuse in +x
    translate([-servo_shaft_off - clear, -servo_w / 2 - clear])
        square([servo_l + 2 * clear, servo_w + 2 * clear]);
}

module halter() {
    servo_center_x = pinion_pos[0] - servo_shaft_off + servo_l / 2;
    difference() {
        union() {
            // Platte
            translate([0, 0, plate_z0]) linear_extrude(plate_t) hull() {
                circle(d = axle_d + 8);
                translate([servo_center_x, 0]) square([servo_hole_dist + 7, servo_w + 8], center = true);
                for (f = feet) translate(f) square(leg_w, center = true);
            }
            // Beine und Füße
            for (f = feet) {
                translate([f[0] - leg_w / 2, f[1] - leg_w / 2, 0]) cube([leg_w, leg_w, plate_z0 + 0.01]);
                translate([f[0] - foot_size[0] / 2, f[1] - foot_size[1] / 2, 0]) cube([foot_size[0], foot_size[1], 2.5]);
            }
        }
        // Lager für den Mitnehmer
        translate([0, 0, plate_z0 - 1]) cylinder(d = axle_d + 0.4, h = plate_t + 2);
        // Servo steckt von vorn durch die Platte, Laschen liegen auf
        translate([pinion_pos[0], pinion_pos[1], plate_z0 - 1]) linear_extrude(plate_t + 2) servo_outline(0.3);
        for (dx = [-servo_hole_dist / 2, servo_hole_dist / 2])
            translate([servo_center_x + dx, 0, plate_z0 - 1]) cylinder(d = servo_hole_d, h = plate_t + 2);
        if (foot_screw)
            // je zwei M3-Löcher neben dem Bein
            for (f = feet, dy = [-1, 1])
                translate([f[0], f[1] + dy * (foot_size[1] / 2 - 4.5), -1]) cylinder(d = 3.4, h = 5);
    }
}

// Vereinfachter MG90S, nur zur Kontrolle in der Baugruppe
module servo_dummy() {
    color("royalblue") translate([pinion_pos[0], pinion_pos[1], 0]) {
        translate([0, 0, gear_z1 + 2.5]) linear_extrude(plate_front - gear_z1 - 2.5 + 22.5) servo_outline();
        translate([0, 0, plate_front]) linear_extrude(2.5)
            translate([-servo_shaft_off - (servo_hole_dist - servo_l) / 2 - 2.2, -servo_w / 2]) square([servo_hole_dist + 4.4, servo_w]);
        translate([0, 0, gear_z1 - 0.1]) cylinder(d = 4.8, h = 3);
    }
}

module knob_dummy() {
    color("gray") {
        cylinder(d = knob_hub_d, h = knob_h);
        translate([-knob_span / 2, -knob_wing_t / 2, knob_h - engage]) cube([knob_span, knob_wing_t, engage]);
    }
    color("lightgray", 0.5) translate([-60, -40, -2]) cube([120, 80, 2]);
}

// ---------------------------------------------------------------- Ausgabe
if (part == "assembly") {
    knob_dummy();
    color("orange") mitnehmer();
    color("gold") ritzel();
    color("seagreen", 0.85) halter();
    servo_dummy();
} else if (part == "mitnehmer") {
    // Glocke unten auf dem Bett, Zapfen oben: keine Stützen nötig
    translate([0, 0, -(knob_h - engage)]) mitnehmer();
} else if (part == "ritzel") {
    translate([-pinion_pos[0], -pinion_pos[1], -gear_z0]) ritzel();
} else if (part == "halter") {
    // Platte auf das Bett, Beine nach oben; Füße mit Baumstützen drucken
    rotate([180, 0, 0]) translate([0, 0, -plate_front]) halter();
} else if (part == "print") {
    translate([0, 0, -(knob_h - engage)]) mitnehmer();
    translate([0, 70, 0]) translate([-pinion_pos[0], -pinion_pos[1], -gear_z0]) ritzel();
    translate([90, 0, 0]) rotate([180, 0, 0]) translate([0, 0, -plate_front]) halter();
}
