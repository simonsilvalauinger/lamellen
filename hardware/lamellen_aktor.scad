// Lamellen-Aktor für Edelstahl-Lüftungsgitter mit Drehknopf am Rahmenrand
//
// Koordinaten: Knopfachse im Ursprung, z zeigt aus der Wand heraus,
// y entlang des Rahmenrands (nach oben), x Richtung Lamellen.
// Der Aktor baut nur entlang des Rahmenrands, damit er neben Möbeln Platz hat
// und keine Lamellen verdeckt. Das Gehäuse ist gestuft: nur der Servoturm am
// Knopf ist hoch, der Akku (oben) liegt flach daneben direkt auf dem Rahmen.
//
// Varianten:
//   "stirn"    – Die Hülse trägt unten einen Zahnkranz (42 Z.) direkt über dem
//                Rahmen. Der MG90S steht kopfüber unter dem Knopf, sein Ritzel
//                (42 Z., 1:1) kämmt in derselben Ebene. Robuste Stirnräder, Servo
//                verschraubt, ca. 35 mm hoch; die Zahnräder ragen auf beiden
//                Seiten 9,5 mm über den Rahmenrand. Standard.
//   "kegel"    – MG90S (180°) liegt flach unter dem Knopf, zwei gleiche
//                Kegelräder (1:1) lenken um 90° auf den Knopf um, ca. 39 mm hoch.
//                Nur der Servo ragt 4,3 mm zur Lamellenseite über. (Ein Kronenrad
//                geht bei 1:1 nicht: seine Zähne würden innen unterschnitten.)
//   "direkt"   – MG90S steht koaxial vor dem Knopf, das Horn treibt die Hülse
//                direkt an. Wenigste Teile, aber ca. 55 mm hoch.
//   "getriebe" – 270°-Microservo steht versetzt, 24er-Ritzel auf 36er-Zahnrad
//                (1:1,5) für mehr Drehmoment, ca. 58 mm hoch.
//
// Export:  openscad -D 'part="mitnehmer"' -o mitnehmer.stl lamellen_aktor.scad
// Teile:   "assembly", "mitnehmer", "gehaeuse", "deckel", "ritzel"
//          (Ritzel bzw. Kegelrad am Servo, nicht bei „direkt“), "print"
//
// Alle Maße in mm.

part      = "assembly";
show_lids = false;
variante  = "stirn";   // "stirn", "kegel", "direkt" oder "getriebe"

/* [Knopf (rautenförmig, von vorn gesehen)] */
knob_len    = 35;   // Länge der Raute (Spitze bis Spitze)
knob_w      = 9;    // Breite an der breitesten Stelle
knob_angle  = 90;   // Richtung der Längsachse bei der Montage (90 = senkrecht)
knob_h      = 15;   // wie weit der Knopf aus dem Rahmen ragt (gemessen)
engage      = 10;   // so tief übergreift die Hülse den Knopf (≤ knob_h)
wall        = 2.4;  // Wandstärke der Hülse
knob_travel = 180;  // Drehweg des Knopfs zu → auf (Lamellen dabei ca. 75°)
fit         = 0.3;  // Spiel je Seite (PETG auf dem A1: 0,2–0,3)

/* [Rahmen] */
frame_w     = 25;    // Breite des Rahmenrands (gemessen), Knopf mittig
space_below = 107.5; // Knopfmitte bis Rahmenunterkante (gemessen)
space_above = 120;   // Knopfmitte bis Rahmenoberkante (gemessen)

/* [Kegelräder (Variante kegel)] */
bevel_m     = 1;    // Modul am äußeren Ende
bevel_z     = 16;   // Zähne je Rad (1:1, 180° Servo = 180° Knopf)
bevel_b     = 3.5;  // Zahnbreite entlang der Mantellinie (≤ 1/3 Kegellänge)
bevel_hub_r = 6.5;  // Nabe hinter den Zähnen; kleiner als der Fußkreis, damit das
                    // Gegenrad mit seinen Zahnköpfen vorbeikommt
sleeve_roof = 3;    // Dach der Hülse unter dem Kegelrad
servo_side  = 1;    // Servogehäuse ragt nach +x (1 = Lamellenseite) oder −x

/* [Zahnkranz an der Hülse (Variante stirn)] */
spur_m      = 1;
spur_z      = 42;   // Zahnkranz; Fußkreis muss die Hülse umschließen
spur_pz     = 42;   // Ritzel am Servo (= spur_z → 1:1 für 180°-Servo)
spur_t      = 4.5;  // Zahnbreite
spur_gap    = 2.5;  // Rahmen bis Unterseite Ritzel/Zahnkranz (Platz für Hornschraube)
servo_tab_from_top = 4.6;  // Servo-Oberseite bis Unterseite der Laschen – nachmessen
shelf_t     = 1.6;  // Ablage für Platine und XIAO über der Hülse

/* [Stirnrad (Variante getriebe)] */
gear_m      = 1;
z_pinion    = 24;
z_knob      = 36;   // bei knob_travel ≥ 165° wird das volle Zahnrad gedruckt
gear_t      = 6;
backlash    = 0.15;
servo_dir   = 90;   // stehender Servo baut nach oben (fest)

/* [Servo MG90S] */
servo_l          = 22.8;  // Gehäuselänge
servo_w          = 12.4;  // Gehäusebreite
servo_hole_dist  = 27.8;  // Abstand der Befestigungslöcher
servo_hole_d     = 2.0;   // Kernloch für die mitgelieferten Schrauben
servo_shaft_off  = 6.0;   // Wellenmitte ab Gehäuseende
servo_below_tab  = 10.0;  // Lasche bis Hornauflage (Wellenseite)
servo_above_tab  = 22.5;  // Lasche bis Gehäuseboden (Kabelseite)
servo_body_h     = 22.7;  // Gehäuseboden bis Oberseite (ohne Wellendom)
servo_shaft_h    = 7.0;   // Oberseite bis Hornauflage – nachmessen
servo_boss_d     = 11.8;  // Wellendom auf der Oberseite
horn_hub_d       = 7.4;   // Nabe des einarmigen Horns
horn_arm_w       = 5.6;
horn_t           = 1.8;
horn_arm_len     = variante == "direkt" || variante == "stirn" ? 14 : variante == "kegel" ? 5 : 6;  // sonst Horn kürzen

/* [Gehäuse] */
plate_t     = 3;        // Zwischenboden (stehender Servo)
bed_t       = 2;        // Servobett (liegender Servo)
case_wall   = 2;
base_t      = 1.6;      // Boden der flachen Fächer (wird auf den Rahmen geklebt)
lid_t       = 2;
chamber     = 8;        // Kabelschacht an den Turmenden
rib_h       = 2;        // Luftspalt unter dem Akku (Rippen)
axle_d      = 6;        // Führungszapfen am Zwischenboden (nur getriebe)
// Akku: "18650" = Rundzelle mit Lötfahnen und Schutzschaltung (ca. 3000 mAh),
//       "lipo"  = flacher LiPo 102050 (ca. 1000 mAh, 50 × 20 × 10)
akku        = "18650";
akku_dim    = akku == "lipo" ? [50, 20, 10] : [70, 18.6, 18.6];  // Länge, Breite, Höhe
board_len   = 24;       // Lochraster-Platine (MOSFETs, Teiler, 5-V-Wandler, Elko)
elec_h      = 11;       // Innenhöhe des Elektronikfachs
xiao_len    = 21.5;     // Seeed XIAO ESP32-C6 (21 × 17,8)
xiao_w      = 17.8;

$fn = 64;

// ---------------------------------------------------------------- Ableitungen
function dir(a) = [cos(a), sin(a)];

direct      = variante == "direkt";
krone       = variante == "kegel";   // liegender Servo
geared      = variante == "getriebe";
stirn       = variante == "stirn";
assert(direct || krone || geared || stirn, "variante muss \"kegel\", \"stirn\", \"direkt\" oder \"getriebe\" sein");

// Die Hülse ist auf den Drehkreis des Knopfs + 1,2 mm begrenzt: beim Drehen
// überstreicht sie kaum mehr Fläche als der Knopf selbst.
bell_r      = knob_len / 2 + fit + 1.2;
// Bei „stirn“ reicht die Hülse bis zum Zahnkranz hinunter
bell_z0     = variante == "stirn" ? spur_gap : knob_h - engage;
roof_t      = 4.5;

// --- stehender Servo (direkt, getriebe)
r_knob_gear = gear_m * z_knob / 2;
r_pinion    = gear_m * z_pinion / 2;
center_dist = r_knob_gear + r_pinion;
pinion_pos  = geared ? center_dist * dir(servo_dir) : [0, 0];
sector      = min(360, 2 * knob_travel + 30);   // deckt beide Drehrichtungen ab
gear_z0     = knob_h + 1.5;
horn_seat   = direct ? knob_h + fit + roof_t : gear_z0 + gear_t;
plate_front = horn_seat + servo_below_tab;      // Servolaschen liegen hier auf
plate_z0    = plate_front - plate_t;
servo_center = pinion_pos + (servo_l / 2 - servo_shaft_off) * dir(servo_dir);
tab_half    = servo_hole_dist / 2 + 3.2;

// --- liegender Servo mit Kegelradpaar (kegel)
// Beide Achsen schneiden sich im Kegelspitzenpunkt (0, 0, c_zp) über dem Knopf.
c_root      = knob_h + fit + sleeve_roof;       // Oberkante Hülsendach
c_R         = bevel_m * bevel_z / 2;            // Teilkreisradius am äußeren Ende
c_hub_len   = horn_t + 1.2;
// Zahnköpfe des Servo-Kegelrads müssen 0,5 mm über dem Hülsendach bleiben
c_zp        = c_root + c_R + bevel_m + 0.5;     // Höhe der Servowelle = Kegelspitze
c_gear_z0   = c_zp - c_R;                       // Rückseite des Knopf-Kegelrads
c_y_back    = -c_R;                             // Rückseite des Servo-Kegelrads
c_y_horn    = c_y_back - c_hub_len;             // Nabenende mit Horntasche
c_y_face    = c_y_horn - servo_shaft_h;         // Servo-Oberseite
c_y_end     = c_y_face - servo_body_h;          // Servo-Boden (Kabelausgang)
c_x0        = servo_side > 0 ? -servo_shaft_off : -(servo_l - servo_shaft_off);
c_x1        = c_x0 + servo_l;
c_bed_top   = c_zp - servo_w / 2;
c_bed_z0    = c_bed_top - bed_t;
assert(!krone || c_bed_z0 > c_root + 0.4, "Servobett kollidiert mit der Hülse");
assert(!krone || bevel_hub_r < bevel_m * (bevel_z / 2 - 1.25), "Kegelradnabe größer als Fußkreis");
assert(!krone || horn_arm_len + fit < bevel_hub_r - 0.8, "Horn ragt aus der Kegelradnabe");
assert(!krone || bevel_b <= c_R * sqrt(2) / 3 + 0.01, "bevel_b zu groß für die Kegellänge");

// --- Zahnkranz an der Hülse, Servo kopfüber (stirn)
s_z0        = spur_gap;                         // Ebene von Ritzel und Zahnkranz
s_z1        = s_z0 + spur_t;
s_rk        = spur_m * spur_z / 2;
s_rp        = spur_m * spur_pz / 2;
s_pin_y     = -(s_rk + s_rp);                   // Servowelle unter dem Knopf
s_top_face  = s_z0 + servo_shaft_h;             // Servo-Oberseite (zeigt zum Rahmen)
s_tab_z     = s_top_face + servo_tab_from_top;  // Laschen liegen auf dem Boden auf
s_floor_z0  = s_tab_z - plate_t;
s_servo_top = s_top_face + servo_body_h;        // Servoboden = höchster Punkt
// Servogehäuse liegt zwischen Welle und Knopf
s_body_y0   = s_pin_y - servo_shaft_off;
s_body_y1   = s_body_y0 + servo_l;
s_center_y  = (s_body_y0 + s_body_y1) / 2;
s_tab_y1    = s_center_y + tab_half - 1.1;
s_cap_top   = knob_h + fit + 2;                 // Hülsendach
s_shelf_z0  = s_cap_top + 0.5;
s_shelf_y0  = -bell_r - 0.5;
assert(!stirn || spur_m * (spur_z / 2 - 1.25) > bell_r + 0.3, "Zahnkranz zu klein für die Hülse");
assert(!stirn || s_tab_y1 < -bell_r - 0.5, "Servolaschen ragen in den Drehbereich der Hülse");
assert(!stirn || s_floor_z0 > s_z1 + 0.5, "Servoboden kollidiert mit dem Ritzel");
assert(!stirn || spur_m * (spur_pz / 2 - 1.25) > horn_arm_len + 1, "Horn größer als das Ritzel");

// --- Turm und Drehbereich (y-Achse)
// Unter dem Zwischenboden bzw. Dach dreht der Mitnehmer; dort sind die
// Seitenwände offen.
mit_reach   = geared ? r_knob_gear + gear_m : bell_r;
servo_y0    = pinion_pos[1] - servo_shaft_off;
servo_y1    = servo_y0 + servo_l;
win_lo      = krone ? -mit_reach - 1.5 : min(-mit_reach - 1.5, servo_y0 - 1);
win_hi      = krone ? mit_reach + 1.5
            : max(direct ? mit_reach + 1.5 : pinion_pos[1] + r_pinion + gear_m + 1.5, servo_y1 + 1);
win_z       = krone ? c_root + 0.7 : plate_z0;  // Höhe des seitlich offenen Bereichs
z_lid       = stirn ? max(s_servo_top, s_shelf_z0 + shelf_t + elec_h) + 0.6
            : krone ? max(c_zp + servo_w / 2, c_zp + c_R + bevel_m) + 0.6
            : plate_front + servo_above_tab + 1;
inner_w     = frame_w - 2 * case_wall;
tower_in_top = stirn ? max(s_rk + spur_m + 1.5, s_shelf_y0 + board_len + 1 + xiao_len + 1)
             : krone ? win_hi + case_wall + chamber
             : max(servo_center[1] + tab_half + 1, win_hi + case_wall + chamber);
tower_in_bot = stirn ? s_pin_y - s_rp - spur_m - 1.5
             : krone ? min(c_y_end - 4, win_lo - case_wall - chamber)
             : min(servo_center[1] - tab_half - 1, win_lo - case_wall - chamber);
tower_top   = tower_in_top + case_wall;
tower_bot   = tower_in_bot - case_wall;
// Ausbuchtung für das Servogehäuse über den Rahmenrand hinaus (nur krone)
ext_x0      = servo_side > 0 ? frame_w / 2 - case_wall : c_x0 - 0.3 - case_wall;
ext_x1      = servo_side > 0 ? c_x1 + 0.3 + case_wall : -frame_w / 2 + case_wall;
ext_y0      = tower_bot;
ext_y1      = c_y_face + 2 + case_wall;
needs_ext   = krone && (c_x1 + 0.3 > inner_w / 2 || c_x0 - 0.3 < -inner_w / 2);
boss_d      = 5;
// oberes Fach: Akku
akku_y0     = tower_top + 1;
akku_y1     = akku_y0 + akku_dim[0];
boss_top_y  = akku_y1 + 1 + boss_d / 2;
y_top       = boss_top_y + boss_d / 2 + 0.5 + case_wall;
z_akku_lid  = base_t + rib_h + akku_dim[2] + 1;
// unteres Fach: Platine und XIAO (bei „stirn“ auf der Ablage über der Hülse)
foot_len    = 10;                               // Klebefuß am unteren Turmende (stirn)
board_y1    = stirn ? s_shelf_y0 + board_len : tower_bot - 1;
board_y0    = board_y1 - board_len;
xiao_y1     = stirn ? board_y1 + 1 + xiao_len : board_y0 - 1;
xiao_y0     = xiao_y1 - xiao_len;
boss_bot_y  = xiao_y0 - 1 - boss_d / 2;
y_bot       = stirn ? tower_bot - foot_len : boss_bot_y - boss_d / 2 - 0.5 - case_wall;
z_elec_lid  = base_t + elec_h;
z_elec      = stirn ? s_shelf_z0 + shelf_t : base_t;  // Auflage von Platine und XIAO

echo(str("Variante ", variante, ": Gehäuse ", y_top - y_bot, " mm lang, ", y_top,
         " mm über und ", -y_bot, " mm unter der Knopfachse. Höhe ab Rahmen: Servoturm ",
         z_lid + lid_t, " mm (", tower_top - tower_bot, " mm lang), Akkufach ",
         z_akku_lid + lid_t, " mm", stirn ? ". Platine und XIAO im Turm über der Hülse"
         : str(", Elektronikfach ", z_elec_lid + lid_t, " mm"),
         stirn ? str(". Zahnräder ragen ", s_rk + spur_m - frame_w / 2, " mm über den Rahmenrand (beide Seiten)") : "",
         needs_ext ? str(". Servo ragt ", (servo_side > 0 ? c_x1 : -c_x0) - frame_w / 2,
                         " mm über den Rahmenrand (", servo_side > 0 ? "Lamellenseite" : "Möbelseite", ")") : ""));
assert(akku_dim[1] <= inner_w, "Akku zu breit für den Rahmenrand");
assert(xiao_w <= inner_w, "XIAO zu breit für den Rahmenrand");
assert(krone || servo_w + 0.6 <= inner_w, "Servo zu breit für den Rahmenrand");
assert(krone || stirn || plate_z0 > horn_seat + 0.8, "servo_below_tab zu klein für die Platte");
assert(-y_bot <= space_below, str("Gehäuse ragt ", -y_bot - space_below, " mm unten über den Rahmen"));
assert(y_top <= space_above, str("Gehäuse ragt ", y_top - space_above, " mm oben über den Rahmen – kleineren Akku wählen"));

// ---------------------------------------------------------------- Zahnrad 2D
function invd(a) = (tan(a) - a * PI / 180) * 180 / PI;

// Zahnprofil; mit center = true als Keil ab Radmitte (für gear2d), sonst nur der
// Zahn über dem Fußkreis (zum Abwälzen des Kronenrads)
function tooth2d(m, z, pa = 20, bl = backlash, center = true) =
    let(rp = m * z / 2, rb = rp * cos(pa), ra = rp + m, rf = rp - 1.25 * m,
        psi = 90 / z - (bl / 2) / rp * 180 / PI,  // halber Zahnwinkel am Teilkreis
        r0 = max(rb, rf), n = 8,
        rs = [for (i = [0:n]) r0 + (ra - r0) * i / n],
        phi = function(r) psi + invd(pa) - invd(acos(rb / r)))
    concat(
        center ? [[0, 0], rf * dir(-phi(r0))] : [rf * dir(-phi(r0))],
        [for (r = rs) r * dir(-phi(r))],
        [for (i = [n:-1:0]) rs[i] * dir(phi(rs[i]))],
        [rf * dir(phi(r0))]);

module gear2d(m, z, pa = 20, bl = backlash) {
    union() {
        circle(r = m * z / 2 - 1.25 * m);
        for (i = [0:z - 1]) rotate(i * 360 / z) polygon(tooth2d(m, z, pa, bl));
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

// ---------------------------------------------------------------- Hülse
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

// ---------------------------------------------------------------- Kegelrad
// Gerades Kegelrad (Achswinkel 90°, 1:1): Stirnradprofil am äußeren Ende,
// zur Kegelspitze hin linear verjüngt. Rückseite bei z = 0, Spitze bei z = c_R.
module bevel3d(m, z, b) {
    R = m * z / 2;
    h = b * cos(45);
    linear_extrude(height = h, scale = 1 - h / R) gear2d(m, z);
}

// ---------------------------------------------------------------- Mitnehmer
// „direkt“: Glocke über dem Knopf, oben eine Tasche für das Servohorn.
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

// „kegel“: Hülse mit flachem Dach, darauf Nabe und Kegelrad (Zähne nach oben).
module mitnehmer_krone() {
    module roof2d() intersection() {
        hull() { sleeve2d(); circle(r = bevel_hub_r); }
        circle(r = bell_r);
    }
    difference() {
        union() {
            sleeve(c_root) roof2d();
            translate([0, 0, c_root - 0.01]) cylinder(r = bevel_hub_r, h = c_gear_z0 - c_root + 0.02);
            // Lücke Richtung Servo (−y), damit dort ein Zahn des Servo-Kegelrads greift
            translate([0, 0, c_gear_z0]) rotate(180 / bevel_z) bevel3d(bevel_m, bevel_z, bevel_b);
        }
        translate([0, 0, bell_z0 - 1]) knob_cavity(engage + 1 + fit);
    }
}

// „getriebe“: Glocke + Zahnrad bzw. Zahnsegment Richtung Servo.
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

// „stirn“: Hülse mit Zahnkranz unten; zwischen den Zähnen bei −y greift das Ritzel.
module mitnehmer_stirn() {
    difference() {
        union() {
            sleeve(s_cap_top) sleeve2d();
            // Lücke bei −90° (zum Ritzel hin)
            translate([0, 0, s_z0]) rotate(-90 + 180 / spur_z) linear_extrude(spur_t) gear2d(spur_m, spur_z);
        }
        translate([0, 0, bell_z0 - 1]) knob_cavity(knob_h - bell_z0 + 1 + fit);
    }
}

module mitnehmer() {
    if (stirn) mitnehmer_stirn();
    else if (direct) mitnehmer_direkt();
    else if (krone) mitnehmer_krone();
    else mitnehmer_getriebe();
}

// ---------------------------------------------------------------- Ritzel
// Wird mit den Hornschrauben am gekürzten Horn befestigt (Tasche auf der
// Servoseite, Mittelschraube durch die Senkung auf der anderen Seite).
module ritzel_flach(m, z, t) {
    difference() {
        linear_extrude(t) gear2d(m, z);
        translate([0, 0, t - horn_t]) linear_extrude(horn_t + 1) horn_pocket2d();
        translate([0, 0, -1]) cylinder(d = 2.4, h = t + 2);
        translate([0, 0, -1]) cylinder(d = 4.8, h = t - horn_t - 0.2);
        for (x = [horn_arm_len - 3.5, horn_arm_len - 1.5]) if (x > horn_hub_d / 2)
            translate([x, 0, 1]) cylinder(d = 1.4, h = t);
    }
}

// Kegelrad für die Servowelle: Nabe mit Horntasche bei z < 0, Zähne bei z > 0.
// Die Hornschraube wird von der Zahnseite eingedreht.
module kegelrad_servo() {
    difference() {
        union() {
            bevel3d(bevel_m, bevel_z, bevel_b);
            translate([0, 0, -c_hub_len]) cylinder(r = bevel_hub_r, h = c_hub_len + 0.01);
        }
        translate([0, 0, -c_hub_len - 1]) linear_extrude(horn_t + 1) horn_pocket2d();
        translate([0, 0, -c_hub_len - 1]) cylinder(d = 2.4, h = c_hub_len + bevel_b + 2);
        translate([0, 0, bevel_b * cos(45) - 1]) cylinder(d = 4.4, h = 2);   // Schraubenkopf
    }
}

// Ritzel für den kopfüber stehenden Servo: Horn liegt in der Tasche auf der
// Rahmenseite, die Bohrung nimmt Hornnabe und Wellendom auf.
module ritzel_stirn() {
    difference() {
        linear_extrude(spur_t) gear2d(spur_m, spur_pz);
        translate([0, 0, -1]) linear_extrude(horn_t + 1) horn_pocket2d();
        translate([0, 0, -1]) cylinder(d = servo_boss_d + 0.8, h = spur_t + 2);
        for (x = [horn_arm_len - 5, horn_arm_len - 2]) translate([x, 0, -1]) cylinder(d = 1.4, h = spur_t);
    }
}

module ritzel() {
    if (stirn)
        // ein Zahn zeigt zum Knopf (+y); der Zahnkranz hat dort eine Lücke
        translate([0, s_pin_y, s_z0]) rotate(90) ritzel_stirn();
    else if (krone)
        // Achse entlang y; ein Zahn zeigt nach −z in die Lücke des Knopf-Kegelrads
        translate([0, c_y_back, c_zp]) rotate([-90, 0, 0]) kegelrad_servo();
    else if (geared)
        translate(concat(pinion_pos, [gear_z0])) rotate(servo_dir + 180 + 180 / z_pinion)
            ritzel_flach(gear_m, z_pinion, gear_t);
}

// ---------------------------------------------------------------- Gehäuse
// Gehäuse in einem Stück: Servoturm am Knopf, flache Fächer oben und unten.
// Kabel laufen aus den Fächern in die Schächte an den Turmenden und von dort
// oberhalb der Hülse weiter – nie durch den Drehbereich des Knopfs.
module span2d(y0, y1, inset = 0) {
    translate([-frame_w / 2 + inset, y0 + inset]) square([frame_w - 2 * inset, y1 - y0 - 2 * inset]);
}

module shell(y0, y1, h) {
    linear_extrude(h) difference() { span2d(y0, y1); span2d(y0, y1, case_wall); }
}

module servo_outline(clear = 0) {
    // stehender Servo: Gehäusequerschnitt, Welle im Ursprung, Gehäuse in servo_dir
    rotate(servo_dir) translate([-servo_shaft_off - clear, -servo_w / 2 - clear])
        square([servo_l + 2 * clear, servo_w + 2 * clear]);
}

// Innenraum von Turm + Ausbuchtung neben dem liegenden Servo (ab Servobett)
module ext_opening() {
    translate([servo_side > 0 ? 0 : min(ext_x0, ext_x1) + case_wall, ext_y0 + case_wall, c_bed_top])
        cube([servo_side > 0 ? max(ext_x0, ext_x1) - case_wall : -min(ext_x0, ext_x1) - case_wall,
              ext_y1 - ext_y0 - 2 * case_wall, z_lid]);
}

// Außenkontur der Ausbuchtung für den liegenden Servo
module ext2d(inset = 0) {
    translate([min(ext_x0, ext_x1) + inset, ext_y0 + inset])
        square([abs(ext_x1 - ext_x0) - 2 * inset, ext_y1 - ext_y0 - 2 * inset]);
}

module tower_walls() {
    if (needs_ext) {
        difference() {
            shell(tower_bot, tower_top, z_lid);
            // Turmwand zur Ausbuchtung hin öffnen (oberhalb des Servobetts)
            ext_opening();
        }
        // Ausbuchtung ab dem Servobett, darunter 45° angeschrägt
        difference() {
            union() {
                translate([0, 0, c_bed_z0]) linear_extrude(z_lid - c_bed_z0) ext2d();
                hull() {
                    translate([0, 0, c_bed_z0]) linear_extrude(0.01) ext2d();
                    translate([servo_side * (frame_w / 2 - case_wall / 2), 0, c_bed_z0 - abs(ext_x1 - ext_x0)])
                        linear_extrude(0.01) translate([-0.01, ext_y0]) square([0.02, ext_y1 - ext_y0]);
                }
            }
            ext_opening();
            translate([0, 0, -1]) linear_extrude(c_bed_z0 + 1) span2d(tower_bot, tower_top, case_wall);
        }
    } else shell(tower_bot, tower_top, z_lid);
}

module gehaeuse() { if (stirn) gehaeuse_stirn(); else gehaeuse_turm(); }

// „stirn“: Turm mit Servoboden (unten) und Ablage über der Hülse (oben), unten
// seitlich offen für die Zahnräder. Geklebt wird mit dem Akkufach-Boden und dem
// Fuß am unteren Ende.
module gehaeuse_stirn() {
    win_k = s_rk + spur_m + 1;       // Zahnkranz
    difference() {
        union() {
            shell(tower_bot, tower_top, z_lid);
            shell(tower_top - case_wall, y_top, z_akku_lid);
            linear_extrude(base_t) {
                span2d(tower_top - case_wall, y_top, case_wall / 2);
                span2d(y_bot, tower_bot + case_wall, 0);
            }
            // Stützrippen zwischen Fuß und Turmwand
            for (x = [-frame_w / 2, frame_w / 2 - case_wall])
                hull() {
                    translate([x, tower_bot, 0]) cube([case_wall, case_wall, s_floor_z0]);
                    translate([x, y_bot, 0]) cube([case_wall, 0.01, base_t]);
                }
            // Servoboden
            translate([0, 0, s_floor_z0]) linear_extrude(plate_t) span2d(tower_bot, s_shelf_y0, case_wall / 2);
            // Ablage für Platine und XIAO über der Hülse
            translate([0, 0, s_shelf_z0]) linear_extrude(shelf_t) span2d(s_shelf_y0 - 1, tower_top, case_wall / 2);
            // Rippen unter dem Akku, Schraubdom des Akkudeckels
            for (y = [akku_y0 + 5 : 15 : akku_y1 - 3])
                translate([-inner_w / 2, y, base_t - 0.01]) cube([inner_w, 2, rib_h + 0.01]);
            translate([0, boss_top_y, base_t - 0.01]) cylinder(d = boss_d, h = z_akku_lid - base_t + 0.01);
        }
        // Seitenwände unten offen: Zahnkranz und Hülse …
        for (sgn = [-1, 1]) translate([sgn > 0 ? inner_w / 2 - 0.01 : -3 * frame_w, -win_k, -1])
            cube([3 * frame_w - inner_w / 2 + 0.01, 2 * win_k, s_shelf_z0 + 1]);
        // … und Ritzel (bis knapp über die Zahnräder)
        for (sgn = [-1, 1]) translate([sgn > 0 ? inner_w / 2 - 0.01 : -3 * frame_w, s_pin_y - s_rp - spur_m - 1, -1])
            cube([3 * frame_w - inner_w / 2 + 0.01, 2 * (s_rp + spur_m + 1), s_z1 + 1.7]);
        // Servo steckt kopfüber durch den Boden, Laschen liegen oben auf
        translate([-servo_w / 2 - 0.3, s_body_y0 - 0.3, s_floor_z0 - 1]) cube([servo_w + 0.6, servo_l + 0.6, plate_t + 2]);
        for (sgn = [-1, 1]) translate([0, s_center_y + sgn * servo_hole_dist / 2, s_floor_z0 - 1])
            cylinder(d = servo_hole_d, h = plate_t + 2);
        // Kabel vom Akkufach auf die Ablage
        translate([-5, tower_top - case_wall - 1, s_shelf_z0 + shelf_t]) cube([10, case_wall + 2, z_akku_lid - s_shelf_z0 - shelf_t - 0.5]);
        // Schraubloch des Akkudeckels
        translate([0, boss_top_y, z_akku_lid - 6]) cylinder(d = 1.8, h = 7);
    }
}

module gehaeuse_turm() {
    difference() {
        union() {
            tower_walls();
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
            translate([-frame_w / 2, win_lo - case_wall, 0])
                cube([frame_w, case_wall, (krone ? c_bed_z0 : plate_z0) + 0.01]);
            translate([-frame_w / 2, win_hi, 0]) cube([frame_w, case_wall, (krone ? win_z : plate_z0) + 0.01]);
            if (krone) {
                // Servobett mit Anschlägen
                translate([0, 0, c_bed_z0]) linear_extrude(bed_t) {
                    span2d(tower_bot, c_y_face + 2 + case_wall, case_wall / 2);
                    if (needs_ext) ext2d(case_wall / 2);
                }
                // Anschlag an der Oberseite neben dem Wellendom
                for (x = [c_x0, c_x1]) if (abs(x) > servo_boss_d / 2 + 1)
                    translate([min(x, sign(x) * (servo_boss_d / 2 + 0.5)), c_y_face, c_bed_top - 0.01])
                        cube([abs(x) - servo_boss_d / 2 - 0.5, 2, servo_w * 0.6]);
                // seitlicher Anschlag auf der kurzen Seite
                if (abs(servo_side > 0 ? c_x0 : c_x1) + 0.3 < inner_w / 2)
                    translate([servo_side > 0 ? -inner_w / 2 : c_x1 + 0.3, c_y_end, c_bed_top - 0.01])
                        cube([inner_w / 2 - abs(servo_side > 0 ? c_x0 : c_x1) - 0.3, servo_body_h, 5]);
            } else {
                // Zwischenboden
                translate([0, 0, plate_z0]) linear_extrude(plate_t) span2d(tower_bot, tower_top, case_wall / 2);
            }
            // Rippen unter dem Akku
            for (y = [akku_y0 + 5 : 15 : akku_y1 - 3])
                translate([-inner_w / 2, y, base_t - 0.01]) cube([inner_w, 2, rib_h + 0.01]);
            // Schraubdome der Fachdeckel
            translate([0, boss_top_y, base_t - 0.01]) cylinder(d = boss_d, h = z_akku_lid - base_t + 0.01);
            translate([0, boss_bot_y, base_t - 0.01]) cylinder(d = boss_d, h = z_elec_lid - base_t + 0.01);
            // Führungszapfen in die Lagerbohrung des Mitnehmers
            if (geared) translate([0, 0, gear_z0 + gear_t - 2.5]) cylinder(d = axle_d, h = plate_z0 - gear_z0 - gear_t + 2.6);
        }
        // Drehbereich: Seitenwände unten offen (beim liegenden Servo nur die Wände,
        // das Servobett ragt über den Rand des Drehbereichs)
        if (krone) for (sgn = [-1, 1])
            translate([sgn > 0 ? inner_w / 2 - 0.01 : -3 * frame_w, win_lo, -1])
                cube([3 * frame_w - inner_w / 2 + 0.01, win_hi - win_lo, win_z + 1]);
        else translate([-frame_w, win_lo, -1]) cube([2 * frame_w, win_hi - win_lo, win_z + 1]);
        // Kabeldurchgänge Fach ↔ Schacht
        for (y = [tower_top - case_wall - 1, tower_bot - 1])
            translate([-5, y, base_t]) cube([10, case_wall + 2, 7]);
        if (krone) {
            // Kabel vom Servoraum in den unteren Schacht (hinter dem Servoboden)
            translate([-inner_w / 2 + 1, tower_in_bot + 0.5, c_bed_z0 - 1]) cube([inner_w - 2, c_y_end - tower_in_bot - 1, bed_t + 2]);
        } else {
            // Kabel durch den Zwischenboden in die Schächte
            for (y = [win_hi + case_wall + 1, tower_in_bot + 1])
                translate([-inner_w / 2 + 1, y, plate_z0 - 1]) cube([inner_w - 2, chamber - 2, plate_t + 2]);
            // Servo steckt von vorn durch den Zwischenboden, Laschen liegen auf
            translate([pinion_pos[0], pinion_pos[1], plate_z0 - 1]) linear_extrude(plate_t + 2) servo_outline(0.3);
            for (sgn = [-1, 1])
                translate(concat(servo_center + sgn * servo_hole_dist / 2 * dir(servo_dir), [plate_z0 - 1]))
                    cylinder(d = servo_hole_d, h = plate_t + 2);
        }
        // Schraublöcher der Fachdeckel (M2 × 6, selbstschneidend)
        translate([0, boss_top_y, z_akku_lid - 6]) cylinder(d = 1.8, h = 7);
        translate([0, boss_bot_y, z_elec_lid - 6]) cylinder(d = 1.8, h = 7);
    }
}

// Deckel mit Steg (Umriss als 2D-Kind); die Fachdeckel werden verschraubt,
// der Turmdeckel nur gesteckt
module lid(z, screw_y = undef) {
    difference() {
        union() {
            translate([0, 0, z]) linear_extrude(lid_t) children();
            translate([0, 0, z - 1.5]) linear_extrude(1.51) difference() {
                offset(delta = -(case_wall + 0.25)) children();
                offset(delta = -(case_wall + 1.45)) children();
            }
        }
        if (screw_y != undef) translate([0, screw_y, z - 2]) {
            cylinder(d = 2.4, h = lid_t + 3);
            cylinder(d = boss_d + 0.6, h = 2);   // Steg am Schraubdom aussparen
            translate([0, 0, 2 + lid_t - 1.2]) cylinder(d1 = 2.4, d2 = 4.6, h = 1.21);
        }
    }
}

module deckel_turm() {
    lid(z_lid) union() {
        span2d(tower_bot, tower_top);
        if (needs_ext) ext2d();
    }
    // Niederhalter: drückt den liegenden Servo ins Bett (0,3 mm Luft für Schaumstoff)
    if (krone) for (y = [c_y_end + 4, c_y_face - 5])
        translate([c_x0 + 1, y - 1, c_zp + servo_w / 2 + 0.3]) cube([servo_l - 2, 2, z_lid - c_zp - servo_w / 2 - 0.3 + 0.01]);
}
module deckel_akku() { lid(z_akku_lid, boss_top_y) span2d(tower_top, y_top); }
module deckel_elektronik() { if (!stirn) lid(z_elec_lid, boss_bot_y) span2d(y_bot, tower_bot); }

// ---------------------------------------------------------------- Dummies
module servo_dummy() {
    color("royalblue")
    if (stirn) {
        translate([-servo_w / 2, s_body_y0, s_top_face]) cube([servo_w, servo_l, servo_body_h]);
        translate([-servo_w / 2, s_center_y - servo_hole_dist / 2 - 2.2, s_tab_z]) cube([servo_w, servo_hole_dist + 4.4, 2.5]);
        translate([0, s_pin_y, s_top_face - 4]) cylinder(d = servo_boss_d, h = 4.01);
        translate([0, s_pin_y, s_z0]) cylinder(d = 4.8, h = s_top_face - s_z0);
    } else if (krone) {
        translate([c_x0, c_y_end, c_zp - servo_w / 2]) cube([servo_l, servo_body_h, servo_w]);
        translate([0, c_y_face - 0.01, c_zp]) rotate([-90, 0, 0]) {
            cylinder(d = servo_boss_d, h = 4);
            cylinder(d = 4.8, h = servo_shaft_h);
        }
    } else translate(pinion_pos) {
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
    color("tan") translate([-inner_w / 2 + 0.5, board_y0, z_elec + 0.5]) cube([inner_w - 1, board_len, 1.6]);
    // XIAO auf Schaumklebeband; Antenne zur Stirnwand, USB-C zur Platine
    color("darkgreen") translate([-xiao_w / 2, xiao_y0, z_elec + 1]) cube([xiao_w, xiao_len, 1.6]);
    color("silver") translate([-4.5, stirn ? xiao_y0 - 0.5 : xiao_y1 - 7, z_elec + 2.6]) cube([9, 7.5, 3.2]);
}

module frame_dummy() {
    // Rahmenrand, Knopf mittig; rechts beginnen die Lamellen
    color("silver", 0.6) translate([-frame_w / 2, -120, -1.5]) cube([frame_w, 240, 1.5]);
    color("dimgray", 0.6) translate([frame_w / 2, -120, -6]) cube([200, 240, 1.5]);
    color("black") linear_extrude(knob_h) knob2d();
}

// ---------------------------------------------------------------- Ausgabe
module print_mitnehmer() {
    if (geared) rotate([180, 0, 0]) translate([0, 0, -(gear_z0 + gear_t)]) mitnehmer();  // Zahnrad auf dem Bett
    else translate([0, 0, -bell_z0]) mitnehmer();  // Öffnung unten, Dach überbrückt
}
// Rahmenseite aufs Bett; Baumstützen nur im Drehbereich unter Dach bzw. Servobett
module print_gehaeuse() { gehaeuse(); }
module print_deckel() {
    rotate([180, 0, 0]) {
        translate([0, 0, -(z_lid + lid_t)]) deckel_turm();
        translate([30, 0, -(z_akku_lid + lid_t)]) deckel_akku();
        translate([30, 0, -(z_elec_lid + lid_t)]) deckel_elektronik();
    }
}
module print_ritzel() {
    if (stirn) translate([0, 0, spur_t]) mirror([0, 0, 1]) ritzel_stirn();   // Horntasche oben
    else if (krone) translate([0, 0, c_hub_len]) kegelrad_servo();   // Horntasche auf dem Bett
    else if (geared) ritzel_flach(gear_m, z_pinion, gear_t);
}

if (part == "assembly") {
    frame_dummy();
    color("orange") mitnehmer();
    color("gold") ritzel();
    color("seagreen", 0.6) gehaeuse();
    if (show_lids) color("seagreen", 0.3) { deckel_turm(); deckel_akku(); deckel_elektronik(); }
    servo_dummy();
    electronics_dummy();
} else if (part == "mitnehmer") print_mitnehmer();
else if (part == "gehaeuse" || part == "halter") print_gehaeuse();
else if (part == "deckel") print_deckel();
else if (part == "ritzel") print_ritzel();
// Einzelne Deckel in Druckorientierung (für 3MF/STL-Export)
else if (part == "deckel_turm") rotate([180, 0, 0]) translate([0, 0, -(z_lid + lid_t)]) deckel_turm();
else if (part == "deckel_akku") rotate([180, 0, 0]) translate([0, 0, -(z_akku_lid + lid_t)]) deckel_akku();
else if (part == "deckel_elektronik") rotate([180, 0, 0]) translate([0, 0, -(z_elec_lid + lid_t)]) deckel_elektronik();
// Teile in Einbaulage (für den STEP-Export nach Onshape); ref_* sind Platzhalter
// für Servo, Knopf, Akku/Elektronik und Rahmen
else if (part == "einbau_mitnehmer") mitnehmer();
else if (part == "einbau_ritzel") ritzel();
else if (part == "einbau_gehaeuse") gehaeuse();
else if (part == "einbau_deckel_turm") deckel_turm();
else if (part == "einbau_deckel_akku") deckel_akku();
else if (part == "einbau_deckel_elektronik") deckel_elektronik();
else if (part == "ref_servo") servo_dummy();
else if (part == "ref_elektronik") electronics_dummy();
else if (part == "ref_rahmen") frame_dummy();
else if (part == "print") {
    print_mitnehmer();
    translate([45, 0, 0]) print_gehaeuse();
    translate([75, 0, 0]) print_deckel();
    if (!direct) translate([0, 60, 0]) print_ritzel();
}
