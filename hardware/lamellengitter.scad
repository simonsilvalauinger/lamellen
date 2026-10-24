// Komplett gedrucktes, steuerbares Lamellengitter als Ersatz für das Edelstahlgitter
//
// Koordinaten: Mitte der Wandöffnung (Schacht) auf der Wandoberfläche im Ursprung,
// x nach rechts, y nach oben, z aus der Wand heraus in den Raum.
//
// Aufbau:
//   rahmen       – Blende vor der Wand und Einschub, der im Schacht klemmt (Federzungen
//                  oben und unten, keine Schrauben). Links im Einschub liegt hinter einer
//                  Lagerwand eine geschlossene Tasche für das Gestänge, rechts davon der
//                  Luftkanal mit den Lamellen.
//   lamelle      – n gleiche Lamellen. Die Zapfen schnappen von hinten in Schlitze der
//                  beiden Lagerwände. Links trägt jede Lamelle eine Kurbel in der Tasche.
//   koppelstange – verbindet alle Kurbelzapfen (Parallelkurbel: alle Lamellen drehen
//                  gleich). Unten trägt sie einen Kulissenstein mit Langloch.
//   kurbel       – sitzt auf dem Servohorn; ihr Zapfen greift durch einen Bogenschlitz
//                  in der Blende in das Langloch der Koppelstange.
//   haube        – deckt den linken Blendenrand ab und trägt Servo (kopfüber, an den
//                  Laschen verschraubt), 18650-Akku, Platine und XIAO. Wird mit 4 × M2
//                  von hinten durch die Blende verschraubt. USB-C liegt oben frei.
//
// Lamellen: zu = 15° (überlappen sich), offen = 90° (quer zur Wand), Hub 75°.
// Servo: nur ±40° um die Mitte (ca. 1060–1940 µs), siehe hardware/README.md.
//
// Export:  openscad -D 'part="rahmen"' -o rahmen.stl lamellengitter.scad
// Teile:   "assembly", "rahmen", "lamelle", "koppelstange", "kurbel", "haube",
//          "probe_einschub", "probe_lager"
//
// Alle Maße in mm.

part      = "assembly";
oeffnung  = 1;      // nur für die Ansicht: 0 = zu, 1 = offen
show_haube = true;
show_rahmen = true;
nr        = 0;      // einzelne Lamelle für "einbau_lamelle" (Kollisionsprüfung)

/* [Schacht – vor dem Druck messen] */
schacht_w = 180;    // lichte Breite der Wandöffnung (Annahme, MESSEN)
schacht_h = 180;    // lichte Höhe der Wandöffnung (Annahme, MESSEN)
einschub  = 30;     // so tief steckt der Rahmen im Schacht (mind. 27, MESSEN ob frei)
spiel     = 1;      // Luft je Seite zwischen Einschub und Schachtwand
rand      = 23.75;  // Blende überdeckt die Wand: 180 + 2 × 23,75 = 227,5 wie das alte Gitter

/* [Rahmen] */
blende_t  = 3;      // Dicke der Blende
wand      = 2;      // Wände des Einschubs
lager_wand = 2.4;   // Wände mit den Lagerschlitzen
r_ecke    = 3;      // Eckenradius der Blende
klemm_n   = 2;      // Federzungen je Seite (oben und unten)
klemm_b   = 25;     // Breite einer Zunge
klemm_l   = 20;     // Länge einer Zunge (ab Hinterkante)
klemm_ueber = 0.8;  // Übermaß der Nase gegenüber der Schachtwand

/* [Lamellen] */
teilung   = 20;     // Achsabstand
sehne     = 24;     // Breite einer Lamelle (Überlappung zu: sehne·cos15° − teilung)
lam_t     = 2;      // Dicke
winkel_zu = 15;     // kleiner geht nicht: dann stoßen die Kurbeln aneinander
winkel_auf = 90;
achse_z   = -14;    // Lage der Drehachsen hinter der Wandoberfläche
zapfen_d  = 4;      // Lager- und Kurbelzapfen
zapfen_spiel = 0.3; // Bohrung = zapfen_d + zapfen_spiel
schnapp   = 0.35;   // Engstelle im Schlitz: zapfen_d − schnapp
kurbel_r  = 8;      // Kurbelradius (Achse bis Kurbelzapfen)
kurbel_t  = 3;      // Dicke der Kurbel (x)
lauf      = 0.5;    // Spalt zwischen bewegten Teilen

/* [Koppelstange und Kulisse] */
stange_b  = 4;      // Dicke (x)
stange_h  = 8;      // Höhe (z)
stein_h   = 9;      // Höhe des Kulissensteins (y)
kulisse_r = 6;      // Radius des Kurbelzapfens am Servo
kulisse_d = 4;      // Zapfen der Servokurbel
kurbel_s_t = 4.5;   // Dicke der Servokurbel

/* [Servo MG90S] */
servo_l          = 22.8;
servo_w          = 12.4;
servo_hole_dist  = 27.8;
servo_hole_d     = 2.0;
servo_shaft_off  = 6.0;
servo_body_h     = 22.7;
servo_shaft_h    = 7.0;   // Oberseite bis Hornauflage – nachmessen
servo_tab_from_top = 4.6; // Oberseite bis Unterseite der Laschen – nachmessen
servo_tab_t      = 2.5;
servo_boss_d     = 11.8;
horn_hub_d       = 7.4;
horn_arm_w       = 5.6;
horn_t           = 1.8;
horn_arm_len     = 14;

/* [Haube] */
h_wand    = 2;
lid_t     = 2;
dom_d     = 6;      // Schraubdome M2
akku_dim  = [70, 18.6];  // 18650: Länge, Durchmesser
board_len = 24;
xiao_len  = 21.5;
xiao_w    = 17.8;
fit       = 0.3;

$fn = 48;

// ---------------------------------------------------------------- Ableitungen
// x-Lagen von links: Außenwand | Koppelstange | Kurbeln | Lagerwand | Lamellen | Lagerwand
xo      = -schacht_w / 2 + spiel;     // Außenseite Einschub links
xr      =  schacht_w / 2 - spiel;     // Außenseite Einschub rechts
x_bar0  = xo + wand + lauf;
x_bar1  = x_bar0 + stange_b;
x_fin0  = x_bar1 + lauf;
x_fin1  = x_fin0 + kurbel_t;
x_bw    = x_fin1 + lauf;              // Lagerwand links
x_bw1   = x_bw + lager_wand;          // = Innenkante der Blende links
x_rw    = xr - lager_wand;            // Lagerwand rechts
x_lam0  = x_bw1 + lauf;
x_lam1  = x_rw - lauf;
yb_out  = -schacht_h / 2 + spiel;
yt_out  =  schacht_h / 2 - spiel;
yb      = yb_out + wand;              // Innenkante Kanal / Tasche unten
yt      = yt_out - wand;

z_r     = zapfen_d / 2;
hole_d  = zapfen_d + zapfen_spiel;
// Kurbelzapfen liegt in der Lamellenebene: Kurbelwinkel = Lamellenwinkel
dy_zu   = kurbel_r * cos(winkel_zu);   // Stangenhub in y gegenüber der Achse
dy_auf  = kurbel_r * cos(winkel_auf);
dy_mid  = (dy_zu + dy_auf) / 2;

// Kulissenstein unter dem untersten Kurbelzapfen: muss beim Hub unter der untersten Kurbel bleiben
stein_ab = dy_zu + z_r + lauf;        // Oberkante Stein unter dem untersten Kurbelzapfen
// Lamellenpaket: oben bündig, unten Platz für den Kulissenstein
lam_top  = sehne / 2 * cos(winkel_zu) + lam_t * sin(winkel_zu);   // Oberkante zu, ab Achse
y_first  = yt - lauf - max(lam_top, dy_zu + stange_h / 2);
y_last_min = yb + lauf + stein_ab + stein_h - dy_auf;
n_lam    = floor((y_first - y_last_min) / teilung) + 1;
function lam_y(i) = y_first - i * teilung;
y_last   = lam_y(n_lam - 1);
// Blende unten bis knapp über die Unterkante der untersten geschlossenen Lamelle
y_sill   = y_last - sehne / 2 * cos(winkel_zu) + 3;

// Servo kopfüber auf der Blende, Welle zeigt in die Wand
psi_max  = asin((dy_zu - dy_auf) / 2 / kulisse_r);
x_c      = (x_bar0 + x_fin1) / 2;                          // Mitte Langloch
x_s      = x_c - kulisse_r * (1 + cos(psi_max)) / 2;       // Servowelle
y_s      = y_last + dy_mid - stein_ab - stein_h / 2;       // Servowelle
slot_len = kulisse_r * (1 - cos(psi_max));                 // Weg des Zapfens im Langloch
z_kurbel0 = blende_t + 0.5;                                // Unterseite Servokurbel
z_face   = z_kurbel0 + servo_shaft_h;                      // Servo-Oberseite (zeigt zur Wand)
z_tab    = z_face + servo_tab_from_top;
z_servo_top = z_face + servo_body_h;
servo_cy = y_s + servo_l / 2 - servo_shaft_off;            // Servo baut nach oben
tab_half = servo_hole_dist / 2 + 3.2;
// Zapfen der Servokurbel endet im Stein, auch wenn die Stange ganz hinten steht
z_zapfen_end = achse_z + kurbel_r * sin(winkel_zu) + stange_h / 2 - 3;

// Haube
xL      = -schacht_w / 2 - rand;
xH      = x_bw1;
yB      = -schacht_h / 2 - rand;
yT      =  schacht_h / 2 + rand;
z_lid_in = z_servo_top + 0.6;
z_top   = z_lid_in + lid_t;
h_x0    = xL + h_wand;
h_x1    = xH - h_wand;
akku_x  = (h_x0 + h_x1) / 2;
akku_z  = z_kurbel0 + 1.5 + akku_dim[1] / 2 + fit;
akku_y0 = servo_cy + tab_half + 3;
akku_y1 = akku_y0 + akku_dim[0];
xiao_y1 = yT - h_wand - 0.5;            // USB-C an der oberen Stirnwand
xiao_y0 = xiao_y1 - xiao_len;
board_y0 = xiao_y0 - 1 - board_len;
dom_a   = dom_d / 2 - 0.5;              // Dome stehen 0,5 mm in den Wänden
dome    = [[h_x0 + dom_a, yB + h_wand + dom_a], [h_x1 - dom_a, yB + h_wand + dom_a],
           [h_x0 + dom_a, yT - h_wand - dom_a], [h_x1 - dom_a, yT - h_wand - dom_a]];

function oeffnungswinkel(o) = winkel_zu + o * (winkel_auf - winkel_zu);
function psi(beta) = asin((kurbel_r * cos(beta) - dy_mid) / kulisse_r);

echo(str("Lamellengitter: ", schacht_w + 2 * rand, " × ", schacht_h + 2 * rand, " mm, ",
         n_lam, " Lamellen à ", x_lam1 - x_lam0, " mm, Haube ", xH - xL, " mm breit und ",
         z_top, " mm hoch, Servo ±", psi_max, "°"));

assert(schacht_w + 2 * rand <= 256 && schacht_h + 2 * rand <= 256,
       "Blende größer als die Druckplatte des A1 (256 mm) – rand verkleinern oder Rahmen teilen");
assert(teilung * sin(winkel_zu) >= zapfen_d + 0.8, "Kurbeln stoßen in Stellung zu aneinander – winkel_zu oder teilung erhöhen");
assert(sehne * cos(winkel_zu) > teilung + 1, "Lamellen überlappen sich in Stellung zu nicht");
assert(achse_z + sehne / 2 <= -1, "offene Lamellen ragen aus der Wand – achse_z tiefer legen");
assert(-(achse_z - sehne / 2) + 1 <= einschub, "offene Lamellen ragen hinten aus dem Einschub – einschub erhöhen");
assert(achse_z + kurbel_r + stange_h / 2 <= -1, "Koppelstange stößt an die Blende");
assert(psi_max <= 50, "kulisse_r zu klein");
assert(kulisse_d + 0.4 + slot_len <= x_fin1 - x_bar0 - 1.4, "Langloch zu lang für den Kulissenstein");
assert(akku_y1 + 2 < board_y0, "Akku, Platine und XIAO passen nicht in die Haube");
assert(akku_x - akku_dim[1] / 2 > h_x0 && akku_x + akku_dim[1] / 2 < h_x1, "Akku zu breit für die Haube");
assert(x_s + kulisse_r + kulisse_d / 2 + 1.2 < h_x1 - 0.4, "Servokurbel stößt an die Haube");

// ---------------------------------------------------------------- Hilfen
module rbox(p0, size, r) {   // Quader mit senkrecht gerundeten Kanten
    translate(p0) linear_extrude(size[2])
        offset(r) offset(-r) square([size[0], size[1]]);
}
module box(p0, p1) { translate(p0) cube(p1 - p0); }

// Profil in der y-z-Ebene, entlang x extrudiert
module yz_extrude(x0, x1) {
    translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(x1 - x0) children();
}

// Schnappschlitz von hinten: Bohrung, kurze Engstelle, breiter Einführschlitz;
// daneben je ein Entlastungsschlitz, damit die Engstelle federt.
module schnapp_schlitz_2d(z_end) {
    neck_l = 1.5;
    circle(d = hole_d);
    translate([-(zapfen_d - schnapp) / 2, -hole_d / 2 - neck_l]) square([zapfen_d - schnapp, hole_d / 2 + neck_l]);
    translate([-hole_d / 2, z_end]) square([hole_d, -z_end - hole_d / 2 - neck_l]);
    // Einführschräge an der Engstelle
    translate([0, -hole_d / 2 - neck_l]) polygon([[-hole_d / 2, 0], [hole_d / 2, 0],
                                                  [(zapfen_d - schnapp) / 2, 0.6], [-(zapfen_d - schnapp) / 2, 0.6]]);
    for (s = [-1, 1]) translate([s * (hole_d / 2 + 1.2 + 0.4) - 0.4, -hole_d / 2 - neck_l - 1.5])
        square([0.8, hole_d + neck_l + 1.5 + 0.5]);
}

// ---------------------------------------------------------------- Rahmen
module federzunge(x_c, oben, l = klemm_l) {
    // Zwei Schlitze ab Hinterkante bilden die Zunge, außen sitzt eine Nase
    y_w = oben ? yt_out - wand : yb_out;
    for (dx = [-klemm_b / 2 - 1, klemm_b / 2]) box([x_c + dx, y_w - 1, -einschub - 1], [x_c + dx + 1, y_w + wand + 1, -einschub + l]);
}
module federnase(x_c, oben) {
    s = oben ? 1 : -1;
    y_o = oben ? yt_out : yb_out;
    nase = spiel + klemm_ueber;
    translate([x_c - klemm_b / 2 + 0.5, 0, 0]) yz_extrude(0, klemm_b - 1)
        polygon([[y_o - s * 0.01, -einschub], [y_o + s * nase, -einschub + 3],
                 [y_o + s * nase, -einschub + 5], [y_o - s * 0.01, -einschub + 9]]);
}
function klemm_x(k) = x_bw1 + (k + 0.5) * (xr - x_bw1) / klemm_n;

module bogenschlitz(spalt) {
    // Weg des Zapfens der Servokurbel
    w = psi_max + 4;   // Reserve für die Kalibrierung
    for (a = [-w : w / 8 : w - 0.01])
        hull() for (b = [a, a + w / 8])
            translate([x_s + kulisse_r * cos(b), y_s + kulisse_r * sin(b)]) circle(d = kulisse_d + 2 * spalt);
}

module rahmen() {
    difference() {
        union() {
            // Blende
            rbox([xL, yB, 0], [schacht_w + 2 * rand, schacht_h + 2 * rand, blende_t], r_ecke);
            // Einschub
            box([xo, yb_out, -einschub], [xr, yt_out, 0.01]);
            for (k = [0 : klemm_n - 1], oben = [true, false]) federnase(klemm_x(k), oben);
        }
        // Lichte Öffnung der Blende (über dem Luftkanal)
        box([x_bw1, y_sill, -1], [x_rw, yt, blende_t + 1]);
        // Tasche und Kanal im Einschub (vorn von der Blende abgedeckt bzw. offen)
        box([xo + wand, yb, -einschub - 1], [x_bw, yt, 0]);
        box([x_bw1, yb, -einschub - 1], [x_rw, yt, 0]);
        // Lagerschlitze links und rechts
        for (i = [0 : n_lam - 1])
            for (xw = [[x_bw - 0.01, x_bw1 + 0.01], [x_rw - 0.01, xr + 0.01]])
                yz_extrude(xw[0], xw[1]) translate([lam_y(i), achse_z]) schnapp_schlitz_2d(-einschub - 1);
        // Federzungen
        for (k = [0 : klemm_n - 1], oben = [true, false]) federzunge(klemm_x(k), oben);
        // Bogenschlitz für den Zapfen der Servokurbel
        translate([0, 0, -1]) linear_extrude(blende_t + 2) bogenschlitz(0.6);
        // Schraublöcher der Haube, von hinten versenkt (M2)
        for (d = dome) translate([d[0], d[1], -0.01]) {
            cylinder(d = 2.4, h = blende_t + 1);
            cylinder(d1 = 4.4, d2 = 2.4, h = 1);
        }
    }
}

// ---------------------------------------------------------------- Lamelle
// Lokal: Achse auf x, Sehne entlang y, die Oberseite der Platte liegt in der Achse.
// So liegen Platte, Zapfen und Kurbel flach auf dem Druckbett (z = −zapfen_d/2).
module lamelle_profil() {
    hull() for (u = [-sehne / 2 + lam_t / 2, sehne / 2 - lam_t / 2])
        translate([u, -lam_t / 2]) circle(d = lam_t);
}
module lamelle() {
    // Platte
    yz_extrude(x_lam0, x_lam1) lamelle_profil();
    // Zapfen links (durch die Lagerwand bis zur Kurbel) und rechts
    yz_extrude(x_fin0, x_lam0 + 0.01) circle(d = zapfen_d);
    yz_extrude(x_lam1 - 0.01, xr - 0.3) circle(d = zapfen_d);
    // Kurbel in der Tasche, in der Ebene der Lamelle
    yz_extrude(x_fin0, x_fin1) hull() { circle(d = zapfen_d); translate([kurbel_r, 0]) circle(d = zapfen_d); }
    // Kurbelzapfen durch die Koppelstange
    yz_extrude(x_bar0, x_fin0 + 0.01) translate([kurbel_r, 0]) circle(d = zapfen_d);
    // Übergang Platte – Zapfen verstärken
    for (x = [[x_lam0, x_lam0 + 4], [x_lam1 - 4, x_lam1]])
        yz_extrude(x[0], x[1]) hull() { circle(d = zapfen_d); translate([-2 * zapfen_d, -lam_t / 2]) circle(d = lam_t); translate([2 * zapfen_d, -lam_t / 2]) circle(d = lam_t); }
}
module lamelle_einbau(i, beta) {
    translate([0, lam_y(i), achse_z]) rotate([beta, 0, 0]) lamelle();
}

// ---------------------------------------------------------------- Koppelstange
// Lokal: Ursprung im untersten Kurbelzapfen, z = 0 in der Zapfenachse.
// Die Kerben sind nach hinten offen: Stange von hinten auf die Kurbelzapfen klipsen.
module koppelstange() {
    span = (n_lam - 1) * teilung;
    y_st = -stein_ab - stein_h;
    difference() {
        union() {
            box([x_bar0, y_st, -stange_h / 2], [x_bar1, span + stange_h / 2, stange_h / 2]);
            // Kulissenstein reicht in die Ebene der Kurbeln
            box([x_bar0, y_st, -stange_h / 2], [x_fin1, -stein_ab, stange_h / 2]);
        }
        for (i = [0 : n_lam - 1])
            yz_extrude(x_bar0 - 1, x_bar1 + 1) translate([i * teilung, 0]) schnapp_schlitz_2d(-stange_h / 2 - 1);
        // Langloch für den Zapfen der Servokurbel (z durchgehend, Weg in x)
        translate([0, y_st + stein_h / 2, -stange_h / 2 - 1]) linear_extrude(stange_h + 2)
            hull() for (dx = [-slot_len / 2, slot_len / 2]) translate([x_c + dx, 0]) circle(d = kulisse_d + 0.4);
    }
}
module koppelstange_einbau(beta) {
    translate([0, y_last + kurbel_r * cos(beta), achse_z + kurbel_r * sin(beta)]) koppelstange();
}

// ---------------------------------------------------------------- Servokurbel
// Lokal: Servowelle im Ursprung, Unterseite (Blendenseite) bei z = 0, Horntasche oben.
// Zapfen zeigt bei psi = 0 nach +x, das Horn nach −x.
module kurbel() {
    t = kurbel_s_t;
    difference() {
        union() {
            linear_extrude(t) {
                hull() { circle(d = horn_hub_d + 3.2); translate([kulisse_r, 0]) circle(d = kulisse_d + 2.4); }
                hull() { circle(d = horn_hub_d + 3.2); translate([-(horn_arm_len - horn_arm_w / 2), 0]) circle(d = horn_arm_w + 3.2); }
            }
            translate([kulisse_r, 0, z_zapfen_end - z_kurbel0]) {
                cylinder(d = kulisse_d, h = z_kurbel0 - z_zapfen_end + 0.01);
                translate([0, 0, z_kurbel0 - z_zapfen_end - 0.4]) cylinder(d1 = kulisse_d, d2 = kulisse_d + 0.8, h = 0.41);
            }
        }
        // Horntasche (einarmiges Horn, ungekürzt)
        translate([0, 0, t - horn_t - 0.2]) linear_extrude(horn_t + 1) offset(fit)
            hull() { circle(d = horn_hub_d); translate([-(horn_arm_len - horn_arm_w / 2), 0]) circle(d = horn_arm_w); }
        // Hornschraube von der Blendenseite
        translate([0, 0, -1]) cylinder(d = 2.6, h = t + 2);
        translate([0, 0, -1]) cylinder(d = 5, h = 1 + 1.5);
    }
}
module kurbel_einbau(beta) {
    translate([x_s, y_s, z_kurbel0]) rotate(psi(beta)) kurbel();
}

// ---------------------------------------------------------------- Haube
module servo_ausschnitt() {
    translate([x_s - servo_w / 2 - fit, y_s - servo_shaft_off - fit, z_face - 1])
        cube([servo_w + 2 * fit, servo_l + 2 * fit, servo_body_h + 2]);
}
module haube() {
    difference() {
        union() {
            difference() {
                rbox([xL, yB, blende_t], [xH - xL, yT - yB, z_top - blende_t], r_ecke);
                translate([0, 0, -0.01]) rbox([h_x0, yB + h_wand, blende_t], [h_x1 - h_x0, yT - yB - 2 * h_wand, z_lid_in - blende_t], max(0.5, r_ecke - h_wand));
            }
            // Säulen für die Servolaschen (der Servo hängt kopfüber daran)
            for (s = [-1, 1]) translate([x_s, servo_cy + s * servo_hole_dist / 2, z_tab + servo_tab_t])
                cylinder(d = 5, h = z_lid_in - z_tab - servo_tab_t + 0.01);
            // Schraubdome
            for (d = dome) translate([d[0], d[1], blende_t]) cylinder(d = dom_d, h = z_lid_in - blende_t + 0.01);
            // Akkuwiegen: der Akku wird von der Blendenseite eingeklipst
            for (y = [akku_y0 + 8, akku_y1 - 10])
                difference() {
                    box([h_x0 - 0.01, y, z_kurbel0], [h_x1 + 0.01, y + 2, z_lid_in + 0.01]);
                    translate([akku_x, y - 1, akku_z]) rotate([-90, 0, 0]) cylinder(d = akku_dim[1] + 2 * fit, h = 4);
                    box([akku_x - 8, y - 1, z_kurbel0 - 1], [akku_x + 8, y + 3, akku_z]);
                }
        }
        servo_ausschnitt();
        for (s = [-1, 1]) translate([x_s, servo_cy + s * servo_hole_dist / 2, z_tab]) cylinder(d = servo_hole_d, h = 8);
        for (d = dome) translate([d[0], d[1], blende_t - 0.01]) cylinder(d = 1.8, h = 10);
        // USB-C des XIAO (Platine mit der Rückseite unter den Deckel geklebt)
        translate([akku_x - 6, yT - h_wand - 1, z_lid_in - 1 - 1.6 - 1.6 - 3.5]) cube([12, h_wand + 2, 7]);
    }
}

// ---------------------------------------------------------------- Platzhalter
module servo_dummy() {
    color("royalblue") {
        translate([x_s - servo_w / 2, y_s - servo_shaft_off, z_face]) cube([servo_w, servo_l, servo_body_h]);
        translate([x_s - servo_w / 2, servo_cy - tab_half, z_tab]) cube([servo_w, 2 * tab_half, servo_tab_t]);
        translate([x_s, y_s, z_kurbel0 + kurbel_s_t]) cylinder(d = 4.8, h = z_face - z_kurbel0 - kurbel_s_t + 0.01);
    }
}
module elektronik_dummy() {
    color("dimgray") translate([akku_x, akku_y0, akku_z]) rotate([-90, 0, 0]) cylinder(d = akku_dim[1], h = akku_dim[0]);
    color("tan") translate([akku_x - 10.5, board_y0, z_lid_in - 1 - 1.6]) cube([21, board_len, 1.6]);
    color("darkgreen") translate([akku_x - xiao_w / 2, xiao_y0, z_lid_in - 1 - 1.6]) cube([xiao_w, xiao_len, 1.6]);
}
module schacht_dummy() {
    color("silver", 0.5) difference() {
        box([xL - 30, yB - 30, -einschub - 20], [-xL + 30, -yB + 30, 0]);
        box([-schacht_w / 2, -schacht_h / 2, -einschub - 21], [schacht_w / 2, schacht_h / 2, 1]);
    }
}

// ---------------------------------------------------------------- Proben
// Schneller Passtest für den Schacht: Rahmenkontur, 15 mm tief, mit Federzungen
module probe_einschub() {
    t = 15;
    difference() {
        union() {
            rbox([xo - 6, yb_out - 6, 0], [xr - xo + 12, yt_out - yb_out + 12, 2], r_ecke);
            box([xo, yb_out, -t], [xr, yt_out, 0.01]);
            for (k = [0 : klemm_n - 1], oben = [true, false])
                translate([0, 0, einschub - t]) federnase(klemm_x(k), oben);
        }
        box([xo + 1.6, yb_out + 1.6, -t - 1], [xr - 1.6, yt_out - 1.6, 3]);
        for (k = [0 : klemm_n - 1], oben = [true, false])
            translate([0, 0, einschub - t]) federzunge(klemm_x(k), oben, t - 3);
    }
}
// Schnapplager: Wandstück mit Schlitz und eine kurze Lamelle
module probe_lager() {
    difference() {
        union() {
            box([0, -14, 0], [lager_wand, 14, -achse_z + 10]);
            box([-6, -14, 0], [lager_wand + 6, 14, 2]);
        }
        translate([0, 0, -achse_z]) mirror([0, 0, 1])
            yz_extrude(-1, lager_wand + 1) schnapp_schlitz_2d(-20);
    }
    // Stummel mit Zapfen, flach daneben
    translate([20, 0, z_r]) {
        rotate([0, 90, 0]) cylinder(d = zapfen_d, h = 20);
        translate([5, 0, 0]) yz_extrude(0, 15) lamelle_profil();
    }
}

// ---------------------------------------------------------------- Ausgabe
module print_rahmen() { rotate([180, 0, 0]) translate([0, 0, -blende_t]) rahmen(); }  // Blende auf dem Bett
module print_lamelle() { translate([0, 0, z_r]) lamelle(); }                        // flach
module print_koppelstange() { rotate([0, -90, 0]) translate([-x_bar0, 0, 0]) koppelstange(); }   // Kerben senkrecht
module print_kurbel() { rotate([180, 0, 0]) translate([0, 0, -kurbel_s_t]) kurbel(); }  // Horntasche auf dem Bett
module print_haube() { rotate([180, 0, 0]) translate([0, 0, -z_top]) haube(); }        // Deckel auf dem Bett
module print_probe_einschub() { rotate([180, 0, 0]) translate([0, 0, -2]) probe_einschub(); }

beta = oeffnungswinkel(oeffnung);
if (part == "assembly") {
    if (show_rahmen) color("whitesmoke") rahmen();
    for (i = [0 : n_lam - 1]) color("lightsteelblue") lamelle_einbau(i, beta);
    color("orange") koppelstange_einbau(beta);
    color("gold") kurbel_einbau(beta);
    servo_dummy();
    elektronik_dummy();
    if (show_haube) color("seagreen", 0.35) haube();
} else if (part == "rahmen") print_rahmen();
else if (part == "lamelle") print_lamelle();
else if (part == "koppelstange") print_koppelstange();
else if (part == "kurbel") print_kurbel();
else if (part == "haube") print_haube();
else if (part == "probe_einschub") print_probe_einschub();
else if (part == "probe_lager") probe_lager();
// Teile in Einbaulage (STEP für Onshape), Lamellen in der Stellung „oeffnung“
else if (part == "einbau_rahmen") rahmen();
else if (part == "einbau_lamellen") for (i = [0 : n_lam - 1]) lamelle_einbau(i, beta);
else if (part == "einbau_lamelle") lamelle_einbau(nr, beta);
else if (part == "einbau_koppelstange") koppelstange_einbau(beta);
else if (part == "einbau_kurbel") kurbel_einbau(beta);
else if (part == "einbau_haube") haube();
else if (part == "ref_servo") servo_dummy();
else if (part == "ref_elektronik") elektronik_dummy();
else if (part == "ref_schacht") schacht_dummy();
