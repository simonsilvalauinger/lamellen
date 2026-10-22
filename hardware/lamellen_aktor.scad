// Lamellen-Aktor für Edelstahl-Lüftungsgitter mit Drehknopf am Rahmenrand
//
// Koordinaten: Knopfachse im Ursprung, z zeigt aus der Wand heraus,
// y entlang des Rahmenrands (nach oben), x Richtung Lamellen.
// Der Aktor baut nur entlang des Rahmenrands, damit er neben Möbeln Platz hat
// und keine Lamellen verdeckt. Das Gehäuse ist gestuft: nur der Servoturm über
// dem Knopf ist hoch, Akku (oben) und Elektronik (unten) liegen flach daneben
// direkt auf dem Rahmen.
//
// Varianten:
//   "direkt"   – 180°-Servo (MG90S) sitzt koaxial vor dem Knopf, das Horn
//                treibt die Hülse direkt an. Kompakt, wenig Teile. Standard.
//   "getriebe" – 270°-Microservo versetzt, 24er-Ritzel auf 36er-Zahnrad an der
//                Hülse (1:1,5): 270° Servo = 180° Knopf, 1,5-faches Drehmoment
//                für schwergängige Knöpfe oder das große Wohnzimmergitter.
//
// Export:  openscad -D 'part="mitnehmer"' -o mitnehmer.stl lamellen_aktor.scad
// Teile:   "assembly", "mitnehmer", "gehaeuse", "deckel", "ritzel" (nur Getriebe), "print"
//
// Alle Maße in mm. Erst den Knopf vermessen, dann die Werte unten anpassen.

part     = "assembly";
show_lids = false;
variante = "direkt";   // "direkt" oder "getriebe"

/* [Knopf (rautenförmig, von vorn gesehen)] */
knob_len    = 35;   // Länge der Raute (Spitze bis Spitze)
knob_w      = 9;    // Breite an der breitesten Stelle
knob_angle  = 90;   // Richtung der Längsachse bei der Montage (90 = senkrecht)
knob_h      = 15;   // wie weit der Knopf aus dem Rahmen ragt (gemessen)
engage      = 10;   // so tief übergreift die Hülse den Knopf (≤ knob_h)
wall        = 2.4;  // Wandstärke der Hülse
knob_travel = 180;  // Drehweg des Knopfs zu → auf (Lamellen dabei ca. 75°)
fit         = 0.3;  // Spiel je Seite (PETG auf dem A1: 0,2–0,3)

/* [Aufbau] */
frame_w     = 25;   // Breite des Rahmenrands (gemessen), Knopf mittig
space_below = 107.5; // Knopfmitte bis Rahmenunterkante (gemessen)
space_above = 120;  // Knopfmitte bis Rahmenoberkante (gemessen)
servo_dir   = 90;   // Servo baut nach oben, Akku und Elektronik nach unten (fest)

/* [Getriebe] */
gear_m      = 1;
z_pinion    = 24;
z_knob      = 36;   // bei knob_travel ≥ 165° wird das volle Zahnrad gedruckt
gear_t      = 6;
backlash    = 0.15;

/* [Servo MG90S] */
servo_l          = 22.8;  // Gehäuselänge
servo_w          = 12.4;  // Gehäusebreite
servo_hole_dist  = 27.8;  // Abstand der Befestigungslöcher
servo_hole_d     = 2.0;   // Kernloch für die mitgelieferten Schrauben
servo_shaft_off  = 6.0;   // Wellenmitte ab Gehäuseende
servo_below_tab  = 10.0;  // Lasche bis Hornauflage (Wellenseite)
servo_above_tab  = 22.5;  // Lasche bis Gehäuseboden (Kabelseite)
horn_hub_d       = 7.4;   // Nabe des einarmigen Horns
horn_arm_w       = 5.6;
horn_t           = 1.8;
horn_arm_len     = variante == "direkt" ? 14 : 9;  // Getriebe: Horn kürzen

/* [Gehäuse] */
plate_t     = 3;        // Zwischenboden im Servoturm
case_wall   = 2;
base_t      = 1.6;      // Boden der flachen Fächer (wird auf den Rahmen geklebt)
lid_t       = 2;
chamber     = 8;        // Kabelschacht an beiden Enden des Servoturms
rib_h       = 2;        // Luftspalt unter dem Akku (Rippen)
axle_d      = 6;        // Führungszapfen am Zwischenboden (nur Getriebe)
// Akku: "lipo" = flacher LiPo 102050 (ca. 1000 mAh, 50 × 20 × 10),
//       "18650" = Rundzelle mit Lötfahnen und Schutzschaltung (ca. 3000 mAh)
akku        = "18650";
akku_dim    = akku == "lipo" ? [50, 20, 10] : [70, 18.6, 18.6];  // Länge, Breite, Höhe
board_len   = 24;       // Lochraster-Platine (MOSFETs, Teiler, 5-V-Wandler, Elko)
elec_h      = 11;       // Innenhöhe des Elektronikfachs
xiao_len    = 21.5;     // Seeed XIAO ESP32-C6 (21 × 17,8)
xiao_w      = 17.8;

$fn = 64;

// ---------------------------------------------------------------- Ableitungen
function dir(a) = [cos(a), sin(a)];

// Die Hülse ist auf den Drehkreis des Knopfs + 1,2 mm begrenzt: beim Drehen
// überstreicht sie kaum mehr Fläche als der Knopf selbst.
bell_r      = knob_len / 2 + fit + 1.2;
bell_z0     = knob_h - engage;
roof_t      = 4.5;
direct      = variante == "direkt";

r_knob_gear = gear_m * z_knob / 2;
r_pinion    = gear_m * z_pinion / 2;
center_dist = r_knob_gear + r_pinion;
pinion_pos  = direct ? [0, 0] : center_dist * dir(servo_dir);
sector      = min(360, 2 * knob_travel + 30);   // deckt beide Drehrichtungen ab

gear_z0     = knob_h + 1.5;
horn_seat   = direct ? knob_h + fit + roof_t : gear_z0 + gear_t;
plate_front = horn_seat + servo_below_tab;  // Servolaschen liegen hier auf
plate_z0    = plate_front - plate_t;
// Mitte zwischen den Servolöchern, vom Wellenmittelpunkt aus
servo_center = pinion_pos + (servo_l / 2 - servo_shaft_off) * dir(servo_dir);

echo(str("Variante ", variante, ", Bauhöhe ab Rahmen ca. ", plate_front + 23, " mm",
         direct ? "" : str(", Achsabstand ", center_dist, " mm, 1:", z_knob / z_pinion)));
assert(plate_z0 > horn_seat + 0.8, "servo_below_tab zu klein für die Platte");
assert(servo_dir == 90, "Gehäuse-Layout erwartet servo_dir = 90");

// ---------------------------------------------------------------- Gehäuse-Layout (y-Achse)
//
//   y_top ┌──────┐
//         │ Akku │  flaches Fach, Höhe z_akku_lid
//         ├──────┴──┐ tower_top
//         │ Schacht │
//         │  Servo  │  Turm, Höhe z_lid; unter dem Zwischenboden dreht der Mitnehmer
//         │ Schacht │
//         ├──────┬──┘ tower_bot
//         │ Plat.│  flaches Fach, Höhe z_elec_lid
//         │ XIAO │  Antenne zur Stirnwand
//   y_bot └──────┘
inner_w     = frame_w - 2 * case_wall;
inner_h     = servo_above_tab + 1;              // Zwischenboden bis Turmdeckel
z_lid       = plate_front + inner_h;
tab_half    = servo_hole_dist / 2 + 3.2;
tab_top     = servo_center[1] + tab_half;
tab_bot     = servo_center[1] - tab_half;
boss_d      = 5;
// Unter dem Zwischenboden müssen Mitnehmer (und beim Getriebe Ritzel und
// Servogehäuse) frei drehen können
mit_reach   = direct ? bell_r : r_knob_gear + gear_m;
servo_y0    = pinion_pos[1] - servo_shaft_off;
servo_y1    = servo_y0 + servo_l;
win_lo      = min(-mit_reach - 1.5, servo_y0 - 1);
win_hi      = max(direct ? mit_reach + 1.5 : pinion_pos[1] + r_pinion + gear_m + 1.5, servo_y1 + 1);
tower_in_top = max(tab_top + 1, win_hi + case_wall + chamber);
tower_in_bot = min(tab_bot - 1, win_lo - case_wall - chamber);
tower_top   = tower_in_top + case_wall;
tower_bot   = tower_in_bot - case_wall;
// oberes Fach: Akku
akku_y0     = tower_top + 1;
akku_y1     = akku_y0 + akku_dim[0];
boss_top_y  = akku_y1 + 1 + boss_d / 2;
y_top       = boss_top_y + boss_d / 2 + 0.5 + case_wall;
z_akku_lid  = base_t + rib_h + akku_dim[2] + 1;
// unteres Fach: Platine und XIAO
board_y1    = tower_bot - 1;
board_y0    = board_y1 - board_len;
xiao_y1     = board_y0 - 1;
xiao_y0     = xiao_y1 - xiao_len;
boss_bot_y  = xiao_y0 - 1 - boss_d / 2;
y_bot       = boss_bot_y - boss_d / 2 - 0.5 - case_wall;
z_elec_lid  = base_t + elec_h;

echo(str("Gehäuse ", y_top - y_bot, " × ", frame_w, " mm, ", y_top, " mm über und ",
         -y_bot, " mm unter der Knopfachse. Höhe ab Rahmen: Servoturm ", z_lid + lid_t,
         " mm (", tower_top - tower_bot, " mm lang), Akkufach ", z_akku_lid + lid_t,
         " mm, Elektronikfach ", z_elec_lid + lid_t, " mm"));
assert(akku_dim[1] <= inner_w, "Akku zu breit für den Rahmenrand");
assert(xiao_w <= inner_w, "XIAO zu breit für den Rahmenrand");
assert(servo_w + 0.6 <= inner_w, "Servo zu breit für den Rahmenrand");
assert(-y_bot <= space_below, str("Gehäuse ragt ", -y_bot - space_below, " mm unten über den Rahmen"));
assert(y_top <= space_above, str("Gehäuse ragt ", y_top - space_above, " mm oben über den Rahmen – kleineren Akku wählen"));

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

module sleeve2d() {
    intersection() {
        offset(r = wall) offset(r = fit) knob2d();
        circle(r = bell_r);
    }
}

module knob_cavity(h) {
    linear_extrude(h) offset(r = fit) knob2d();
}

// Hülse um den Knopf; ab Knopfoberkante darf sie breiter werden (Dach = 2D-Kind)
module sleeve(z_top) {
    translate([0, 0, bell_z0]) linear_extrude(knob_h + fit - bell_z0 + 0.01)
        sleeve2d();
    translate([0, 0, knob_h + fit]) linear_extrude(z_top - knob_h - fit) children();
}

// ---------------------------------------------------------------- Teile
// Mitnehmer „direkt“: Glocke über dem Knopf, oben eine Tasche für das Servohorn.
// Das Horn wird von innen mit zwei kleinen Schrauben in der Tasche fixiert.
module mitnehmer_direkt() {
    top = knob_h + fit + roof_t;
    module roof2d() hull() {
        sleeve2d();
        intersection() {
            rotate(servo_dir + 180) offset(r = 2.4) horn_pocket2d();
            circle(r = bell_r);
        }
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
        sleeve2d();
        circle(d = axle_d + 6);
    }
    difference() {
        union() {
            sleeve(gear_z0) roof2d();
            translate([0, 0, gear_z0 - 0.01]) linear_extrude(gear_t + 0.01) sleeve2d();
            translate([0, 0, gear_z0]) linear_extrude(gear_t)
                if (sector >= 360) gear2d(gear_m, z_knob);
                else intersection() {
                    gear2d(gear_m, z_knob);
                    wedge2d(r_knob_gear + 2 * gear_m, servo_dir - sector / 2, servo_dir + sector / 2);
                }
            // Steg, der das Segment mit der Glocke verbindet
            translate([0, 0, gear_z0]) linear_extrude(gear_t)
                wedge2d(r_knob_gear - 1.25 * gear_m + 0.01, servo_dir - sector / 2, servo_dir + sector / 2);
        }
        translate([0, 0, bell_z0 - 1]) knob_cavity(engage + 1 + fit);
        // Lagerbohrung für den Zapfen am Gehäuseboden
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

// Gehäuse in einem Stück: Servoturm über dem Knopf, flache Fächer oben und unten.
// Kabel laufen aus den Fächern in die Schächte an den Turmenden, durch den
// Zwischenboden und neben dem Servo entlang – nie durch den Drehbereich des Knopfs.
module span2d(y0, y1, inset = 0) {
    translate([-frame_w / 2 + inset, y0 + inset]) square([frame_w - 2 * inset, y1 - y0 - 2 * inset]);
}

module shell(y0, y1, h) {
    linear_extrude(h) difference() { span2d(y0, y1); span2d(y0, y1, case_wall); }
}

module gehaeuse() {
    difference() {
        union() {
            // Wände
            shell(tower_bot, tower_top, z_lid);
            shell(tower_top - case_wall, y_top, z_akku_lid);
            shell(y_bot, tower_bot + case_wall, z_elec_lid);
            // Böden der flachen Fächer und der Kabelschächte (Klebefläche)
            linear_extrude(base_t) {
                span2d(tower_top - case_wall, y_top, case_wall / 2);
                span2d(y_bot, tower_bot + case_wall, case_wall / 2);
                span2d(tower_bot, win_lo, case_wall / 2);
                span2d(win_hi, tower_top, case_wall / 2);
            }
            // Trennwände zwischen Drehbereich und Kabelschächten
            for (y = [win_lo - case_wall, win_hi])
                translate([-frame_w / 2, y, 0]) cube([frame_w, case_wall, plate_z0 + 0.01]);
            // Zwischenboden
            translate([0, 0, plate_z0]) linear_extrude(plate_t) span2d(tower_bot, tower_top, case_wall / 2);
            // Rippen unter dem Akku
            for (y = [akku_y0 + 5 : 15 : akku_y1 - 3])
                translate([-inner_w / 2, y, base_t - 0.01]) cube([inner_w, 2, rib_h + 0.01]);
            // Schraubdome der Fachdeckel
            translate([0, boss_top_y, base_t - 0.01]) cylinder(d = boss_d, h = z_akku_lid - base_t + 0.01);
            translate([0, boss_bot_y, base_t - 0.01]) cylinder(d = boss_d, h = z_elec_lid - base_t + 0.01);
            // Führungszapfen in die Lagerbohrung des Mitnehmers
            if (!direct) translate([0, 0, gear_z0 + gear_t - 2.5]) cylinder(d = axle_d, h = plate_z0 - gear_z0 - gear_t + 2.6);
        }
        // Drehbereich: Seitenwände unter dem Zwischenboden offen
        translate([-frame_w, win_lo, -1]) cube([2 * frame_w, win_hi - win_lo, plate_z0 + 1]);
        // Kabeldurchgänge Fach ↔ Schacht und Schacht ↔ Servoraum
        for (y = [tower_top - case_wall - 1, tower_bot - 1])
            translate([-5, y, base_t]) cube([10, case_wall + 2, 7]);
        for (y = [win_hi + case_wall + 1, tower_in_bot + 1])
            translate([-inner_w / 2 + 1, y, plate_z0 - 1]) cube([inner_w - 2, chamber - 2, plate_t + 2]);
        // Servo steckt von vorn durch den Zwischenboden, Laschen liegen auf
        translate([pinion_pos[0], pinion_pos[1], plate_z0 - 1]) linear_extrude(plate_t + 2) servo_outline(0.3);
        for (sgn = [-1, 1])
            translate(concat(servo_center + sgn * servo_hole_dist / 2 * dir(servo_dir), [plate_z0 - 1]))
                cylinder(d = servo_hole_d, h = plate_t + 2);
        // Schraublöcher der Fachdeckel (M2 × 6, selbstschneidend)
        translate([0, boss_top_y, z_akku_lid - 6]) cylinder(d = 1.8, h = 7);
        translate([0, boss_bot_y, z_elec_lid - 6]) cylinder(d = 1.8, h = 7);
    }
}

// Deckel mit Steg; die Fachdeckel werden verschraubt, der Turmdeckel nur gesteckt
module lid(y0, y1, z, screw_y = undef) {
    difference() {
        union() {
            translate([0, 0, z]) linear_extrude(lid_t) span2d(y0, y1);
            translate([0, 0, z - 1.5]) linear_extrude(1.51) difference() {
                span2d(y0, y1, case_wall + 0.25);
                span2d(y0, y1, case_wall + 1.45);
            }
        }
        if (screw_y != undef) translate([0, screw_y, z - 2]) {
            cylinder(d = 2.4, h = lid_t + 3);
            translate([0, 0, 2 + lid_t - 1.2]) cylinder(d1 = 2.4, d2 = 4.6, h = 1.21);
        }
    }
}

module deckel_turm() { lid(tower_bot, tower_top, z_lid); }
module deckel_akku() { lid(tower_top, y_top, z_akku_lid, boss_top_y); }
module deckel_elektronik() { lid(y_bot, tower_bot, z_elec_lid, boss_bot_y); }

// ---------------------------------------------------------------- Dummies
module servo_dummy() {
    color("royalblue") translate(pinion_pos) {
        translate([0, 0, horn_seat + 2.5]) linear_extrude(plate_front - horn_seat - 2.5 + servo_above_tab) servo_outline();
        translate([0, 0, plate_front]) linear_extrude(2.5)
            translate(servo_center - pinion_pos) rotate(servo_dir) square([servo_hole_dist + 4.4, servo_w], center = true);
        translate([0, 0, horn_seat - 0.1]) cylinder(d = 4.8, h = 3);
    }
}

module electronics_dummy() {
    z_akku = base_t + rib_h;
    color("dimgray")
        if (akku == "lipo") translate([-akku_dim[1] / 2, akku_y0, z_akku]) cube([akku_dim[1], akku_dim[0], akku_dim[2]]);
        else translate([0, akku_y0, z_akku + akku_dim[2] / 2]) rotate([-90, 0, 0]) cylinder(d = akku_dim[1], h = akku_dim[0]);
    color("tan") translate([-inner_w / 2 + 0.5, board_y0, base_t + 0.5]) cube([inner_w - 1, board_len, 1.6]);
    // XIAO auf Schaumklebeband; Antenne zur Stirnwand, USB-C zur Platine
    color("darkgreen") translate([-xiao_w / 2, xiao_y0, base_t + 1]) cube([xiao_w, xiao_len, 1.6]);
    color("silver") translate([-4.5, xiao_y1 - 7, base_t + 2.6]) cube([9, 7.5, 3.2]);
}

module frame_dummy() {
    // Rahmenrand, Knopf mittig; rechts beginnen die Lamellen
    color("silver", 0.6) translate([-frame_w / 2, -120, -1.5]) cube([frame_w, 240, 1.5]);
    color("dimgray", 0.6) translate([frame_w / 2, -120, -6]) cube([200, 240, 1.5]);
    color("black") linear_extrude(knob_h) knob2d();
}

// ---------------------------------------------------------------- Ausgabe
module print_mitnehmer() {
    if (direct) translate([0, 0, -bell_z0]) mitnehmer();          // Öffnung unten, Dach überbrückt
    else rotate([180, 0, 0]) translate([0, 0, -(gear_z0 + gear_t)]) mitnehmer();  // Zahnsegment auf dem Bett
}
// Rahmenseite aufs Bett; Baumstützen nur unter dem Zwischenboden (Drehbereich)
module print_gehaeuse() { gehaeuse(); }
module print_deckel() {
    rotate([180, 0, 0]) {
        translate([0, 0, -(z_lid + lid_t)]) deckel_turm();
        translate([30, 0, -(z_akku_lid + lid_t)]) deckel_akku();
        translate([30, 0, -(z_elec_lid + lid_t)]) deckel_elektronik();
    }
}
module print_ritzel() { translate(concat(-pinion_pos, [-gear_z0])) ritzel(); }

if (part == "assembly") {
    frame_dummy();
    color("orange") mitnehmer();
    if (!direct) color("gold") ritzel();
    color("seagreen", 0.6) gehaeuse();
    if (show_lids) color("seagreen", 0.3) { deckel_turm(); deckel_akku(); deckel_elektronik(); }
    servo_dummy();
    electronics_dummy();
} else if (part == "mitnehmer") print_mitnehmer();
else if (part == "gehaeuse" || part == "halter") print_gehaeuse();
else if (part == "deckel") print_deckel();
else if (part == "ritzel") print_ritzel();
else if (part == "print") {
    print_mitnehmer();
    translate([45, 0, 0]) print_gehaeuse();
    translate([75, 0, 0]) print_deckel();
    if (!direct) translate([0, 60, 0]) print_ritzel();
}
