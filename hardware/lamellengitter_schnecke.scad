// Gedrucktes Lamellengitter, Variante „schnecke“: flach, ohne Haube
//
// Koordinaten wie in lamellengitter.scad: Mitte der Wandöffnung (Schacht) auf der
// Wandoberfläche im Ursprung, x nach rechts, y nach oben, z aus der Wand in den Raum.
//
// Unterschiede zur Servo-Variante:
//   - Alles sitzt im Schacht. Links im Einschub liegt eine Kammer für Akku, XIAO,
//     Treiber, Winkelsensor und Motor. Zum Luftkanal trennt sie ein 6-mm-Luftspalt,
//     nach hinten und zur Schachtwand eine doppelte Wand mit 2,5 mm Luft. Vorn
//     schließt sie ein dünner Deckel in der Blende ab, der Wärme an den Raum abgibt.
//   - Antrieb: N20-Getriebemotor mit Schneckengetriebe (selbsthemmend). Seine
//     Abtriebswelle treibt über eine Klauenkupplung die Lamelle „antrieb_nr“.
//   - Stellung: Ein Diametralmagnet (6 × 2,5 mm) im Magnethalter auf dem Zapfen der
//     Lamelle „sensor_nr“, der AS5600 liest ihn durch die 1,2 mm dünne Kammerwand.
//   - Die Koppelstange liegt rechts in einer Tasche und hält alle Lamellen gleich.
//   - Die Lamellen überlappen sich nicht: zu = 0° (in einer Ebene, 1 mm Spalt),
//     offen = 90°.
//
// Export:  openscad -D 'part="rahmen"' -o rahmen.stl lamellengitter_schnecke.scad
// Teile:   "assembly", "rahmen", "lamelle", "lamelle_antrieb", "koppelstange",
//          "kupplung", "magnethalter", "deckel", "probe_einschub", "probe_lager"
//
// Alle Maße in mm.

part       = "assembly";
oeffnung   = 1;      // nur für die Ansicht: 0 = zu, 1 = offen
nr         = 0;      // einzelne Lamelle für "einbau_lamelle" (Kollisionsprüfung)
show_deckel = true;
show_rahmen = true;

/* [Schacht – vor dem Druck messen] */
schacht_w = 180;    // lichte Breite der Wandöffnung (Annahme, MESSEN)
schacht_h = 180;    // lichte Höhe der Wandöffnung (Annahme, MESSEN)
einschub  = 30;     // so tief steckt der Rahmen im Schacht (MESSEN ob frei)
spiel     = 1;      // Luft je Seite zwischen Einschub und Schachtwand
rand      = 23.75;  // Blende überdeckt die Wand: 180 + 2 × 23,75 = 227,5 wie das alte Gitter

/* [Rahmen] */
blende_t  = 3;
wand      = 2;      // Wände des Einschubs (oben, unten, rechts)
lager_wand = 2.4;   // Wände mit den Lagerschlitzen
r_ecke    = 3;
klemm_n   = 2;
klemm_b   = 25;
klemm_l   = 20;
klemm_ueber = 0.8;

/* [Kammer und Dämmung] */
kammer_b  = 21;     // lichte Breite der Kammer (18650 + Luft)
dw        = 1.2;    // Wände der Doppelwand
luft      = 2.5;    // Luftschicht in der Doppelwand (hinten und zur Schachtwand)
spalt     = 6;      // Luftspalt zwischen Kammer und Lagerwand (Kupplung, Magnethalter)
deckel_t  = 2;      // dünn: über den Deckel gibt die Kammer Wärme an den Raum ab
deckel_rand = 4;    // Deckel überlappt die Öffnung

/* [Lamellen] */
teilung   = 20;
sehne     = 19;     // < teilung: keine Überlappung, zu = 1 mm Spalt
lam_t     = 2;
winkel_zu = 0;
winkel_auf = 90;
achse_z   = -12;
zapfen_d  = 4;
zapfen_spiel = 0.3;
schnapp   = 0.35;
d_flach   = 0.5;    // Abflachung der Zapfenenden im Spalt (Verdrehsicherung Magnethalter)
kurbel_r  = 7;
kurbel_t  = 3;
lauf      = 0.5;
zunge_t   = 1.6;    // Klaue der Antriebslamelle

/* [Koppelstange] */
stange_b  = 4;
stange_h  = 7;

/* [Schneckengetriebemotor N20 – nachmessen] */
// Getriebeblock: Länge entlang der Motorachse, Breite, Dicke (entlang der Abtriebswelle)
getr_l    = 26;
getr_b    = 12;
getr_h    = 10;
motor_l   = 15;     // Motorbecher (12 × 10) unter dem Getriebe
welle_d   = 3;      // Abtrieb mit Abflachung
welle_flach = 2.5;
welle_l   = 9;      // freie Wellenlänge ab Getriebe
welle_ab  = 7;      // Wellenmitte ab dem motorfernen Getriebeende
bohr_tief = 3.4;    // so tief steckt die Welle in der Kupplung

/* [Elektronik] */
akku_dim  = [70, 18.6];
as_b      = 23;     // AS5600-Modul (quadratisch), Chip mittig
as_t      = 1.6;
as_chip   = 1.2;    // Chip + Luft zur Kammerwand
magnet    = [6, 2.5];
xiao      = [21.5, 17.8];
board_len = 24;
drv       = [18.5, 16];
fit       = 0.3;

$fn = 48;

// ---------------------------------------------------------------- Ableitungen
// x-Lagen von links: Doppelwand | Kammer | Kammerwand | Spalt | Lagerwand | Lamellen |
//                    Lagerwand | Kurbeln | Koppelstange | Außenwand
xo      = -schacht_w / 2 + spiel;
xr      =  schacht_w / 2 - spiel;
x_k0    = xo + 2 * dw + luft;          // Kammer innen
x_k1    = x_k0 + kammer_b;
x_kw1   = x_k1 + dw;                   // Kammerwand außen
x_bw    = x_kw1 + spalt;               // Lagerwand links
x_bw1   = x_bw + lager_wand;
x_lam0  = x_bw1 + lauf;
x_rw0   = xr - wand;                   // Außenwand rechts, innen
x_bar1  = x_rw0 - lauf;
x_bar0  = x_bar1 - stange_b;
x_fin1  = x_bar0 - lauf;
x_fin0  = x_fin1 - kurbel_t;
x_rbw1  = x_fin0 - lauf;               // Lagerwand rechts
x_rbw0  = x_rbw1 - lager_wand;
x_lam1  = x_rbw0 - lauf;
x_sp0   = x_kw1 + lauf;                // Kupplung und Magnethalter im Spalt
x_sp1   = x_bw - lauf;
yb_out  = -schacht_h / 2 + spiel;
yt_out  =  schacht_h / 2 - spiel;
yb      = yb_out + wand;
yt      = yt_out - wand;
z_kr    = -einschub + 2 * dw + luft;   // Kammerboden (hinten) innen

z_r     = zapfen_d / 2;
hole_d  = zapfen_d + zapfen_spiel;

// Lamellen mittig verteilt
lam_rand = max(sehne / 2, kurbel_r + stange_h / 2) + lauf;
n_lam    = floor((yt - yb - 2 * lam_rand) / teilung) + 1;
function lam_y(i) = (n_lam - 1) / 2 * teilung - i * teilung;
y_open   = lam_y(0) + sehne / 2 - 2;   // Blendenöffnung: Lamellenkanten liegen 2 mm darunter

antrieb_nr = n_lam - 2;
sensor_nr  = n_lam - 4;
y_k     = lam_y(antrieb_nr);
y_j     = lam_y(sensor_nr);

// Motor: Becher nach unten, Welle zeigt zur Kammerwand
x_gf    = x_sp0 + bohr_tief - welle_l;    // Getriebefläche
g_y1    = y_k + welle_ab;                 // Getriebe oben
g_y0    = g_y1 - getr_l;
m_y0    = g_y0 - motor_l;
x_mitte = (x_k0 + x_k1) / 2;

// AS5600 stehend an der Kammerwand, Chip zum Magneten
x_as1   = x_k1 - as_chip;
x_as0   = x_as1 - as_t;

// Akku liegt hinten, XIAO und Lochraster hängen am Deckel davor, der DRV8833 vor dem Motor
akku_y0 = y_j + as_b / 2 + 4;
akku_y1 = akku_y0 + akku_dim[0];
akku_z  = z_kr + fit + akku_dim[1] / 2;
board_y0 = akku_y0 + 3;

dom_unten = [x_mitte, yb + 3];   // Dome stehen in den Stirnwänden
dom_oben  = [x_mitte, yt - 3];

xL      = -schacht_w / 2 - rand;
yB      = -schacht_h / 2 - rand;

function oeffnungswinkel(o) = winkel_zu + o * (winkel_auf - winkel_zu);

echo(str("Lamellengitter (schnecke): ", schacht_w + 2 * rand, " × ", schacht_h + 2 * rand, " mm, ",
         n_lam, " Lamellen à ", x_lam1 - x_lam0, " mm, Luftkanal ", x_rbw0 - x_bw1, " mm breit, ",
         "Kammer ", kammer_b, " × ", yt - yb, " × ", -z_kr, " mm"));

assert(schacht_w + 2 * rand <= 256 && schacht_h + 2 * rand <= 256,
       "Blende größer als die Druckplatte des A1 (256 mm)");
assert(sehne <= teilung - 0.8, "Lamellen stoßen in Stellung zu aneinander – sehne verkleinern");
assert(achse_z + sehne / 2 <= -1, "offene Lamellen ragen aus der Wand");
assert(-(achse_z - sehne / 2) + 1 <= einschub, "offene Lamellen ragen hinten aus dem Einschub");
assert(achse_z + kurbel_r + stange_h / 2 <= -1, "Koppelstange stößt an die Blende");
assert(akku_dim[1] + 2 * fit <= kammer_b, "Akku zu dick für die Kammer");
assert(akku_dim[1] + 2 * fit <= -z_kr, "Akku zu dick für die Kammertiefe");
assert(achse_z - as_b / 2 >= z_kr && achse_z + as_b / 2 <= 0, "AS5600-Modul passt nicht in die Kammertiefe");
assert(x_gf <= x_k1 - 0.5, "Motorwelle zu kurz: Getriebe stößt an die Kammerwand");
assert(x_gf - getr_h >= x_k0, "Getriebe zu dick für die Kammer");
assert(m_y0 - 2.5 >= yb, "Motor stößt unten an die Kammer – antrieb_nr höher legen");
assert(g_y1 + 2.5 < y_j - as_b / 2 - 1.5, "Motor stößt an den AS5600");
assert(akku_y1 + 2 < dom_oben[1] - 3.5, "Akku passt nicht in die Kammer");
assert(board_y0 + xiao[0] + board_len + 2 < akku_y1, "Platinen passen nicht vor den Akku");
assert(drv[0] < getr_l && achse_z + getr_b / 2 < blende_t - 4 - 0.5, "DRV8833 passt nicht vor den Motor");

// ---------------------------------------------------------------- Hilfen
module rbox(p0, size, r) {
    translate(p0) linear_extrude(size[2])
        offset(r) offset(-r) square([size[0], size[1]]);
}
module box(p0, p1) { translate(p0) cube(p1 - p0); }
module yz_extrude(x0, x1) {
    translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(x1 - x0) children();
}
module schnapp_schlitz_2d(z_end) {
    neck_l = 1.5;
    circle(d = hole_d);
    translate([-(zapfen_d - schnapp) / 2, -hole_d / 2 - neck_l]) square([zapfen_d - schnapp, hole_d / 2 + neck_l]);
    translate([-hole_d / 2, z_end]) square([hole_d, -z_end - hole_d / 2 - neck_l]);
    translate([0, -hole_d / 2 - neck_l]) polygon([[-hole_d / 2, 0], [hole_d / 2, 0],
                                                  [(zapfen_d - schnapp) / 2, 0.6], [-(zapfen_d - schnapp) / 2, 0.6]]);
    for (s = [-1, 1]) translate([s * (hole_d / 2 + 1.2 + 0.4) - 0.4, -hole_d / 2 - neck_l - 1.5])
        square([0.8, hole_d + neck_l + 1.5 + 0.5]);
}
// Zapfen mit Abflachung (unten, liegt beim Druck auf dem Bett)
module d_profil(d, extra = 0) {
    intersection() {
        circle(d = d + extra);
        translate([-d, -d / 2 + d_flach - extra / 2]) square([2 * d, 2 * d]);
    }
}

// ---------------------------------------------------------------- Rahmen
module federzunge(x_c, oben, l = klemm_l) {
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

module kammer_innen() { box([x_k0, yb, z_kr], [x_k1, yt, blende_t + 1]); }

// Einbauten der Kammer; alle reichen bis zur Blendenvorderseite, damit sie beim
// Druck (Blende auf dem Bett) vom Bett aus wachsen. Der Deckel liegt davor.
module kammer_einbauten() {
    zf = blende_t;
    // Motor: Anschläge oben und unten, Abstandsring an der Kammerwand, Rippe links, Auflage hinten
    box([x_k0, g_y1 + fit, z_kr], [x_k1, g_y1 + fit + 2, zf]);
    box([x_k0, m_y0 - fit - 2, z_kr], [x_k1, m_y0 - fit, zf]);
    yz_extrude(x_gf, x_k1 + 0.01) translate([y_k, achse_z]) difference() { circle(d = 8); circle(d = welle_d + 1); }
    if (x_gf - getr_h - fit - x_k0 > 0.8)
        box([x_k0 - 0.01, g_y0, z_kr], [x_gf - getr_h - fit, g_y1, achse_z + getr_b / 2]);
    box([x_k0 - 0.01, m_y0, z_kr - 0.01], [x_k1 + 0.01, g_y1, achse_z - getr_b / 2 - fit]);
    // AS5600: zwei Schienen mit Nut, das Modul wird von vorn eingeschoben
    for (s = [-1, 1]) {
        ya = y_j + s * (as_b / 2 - 1.2);           // greift 1,2 mm über den Modulrand
        yn = y_j + s * (as_b / 2 + fit);
        ye = y_j + s * (as_b / 2 + fit + 1.5);
        difference() {
            box([x_as0 - 2.5, min(ya, ye), z_kr], [x_k1 + 0.01, max(ya, ye), zf]);
            box([x_as0 - fit, min(ya, yn) - 0.01, z_kr + 1], [x_as1 + fit, max(ya, yn), zf + 1]);
        }
    }
    // Akkuwiegen: Akku von vorn einklipsen. Sie enden hinter den Platinen am Deckel
    // (beim Druck eine 21-mm-Brücke).
    for (y = [akku_y0 + 6, akku_y1 - 8])
        difference() {
            box([x_k0 - 0.01, y, z_kr - 0.01], [x_k1 + 0.01, y + 2, akku_z + akku_dim[1] / 2 - 2]);
            translate([x_mitte, y - 1, akku_z]) rotate([-90, 0, 0]) cylinder(d = akku_dim[1] + 2 * fit, h = 4);
            box([x_mitte - 7.5, y - 1, akku_z], [x_mitte + 7.5, y + 3, zf + 1]);
        }
    // Schraubdome für den Deckel
    translate([dom_unten[0], dom_unten[1], -4]) cylinder(d = 6.5, h = zf + 4);
    translate([dom_oben[0], dom_oben[1], -10]) cylinder(d = 6.5, h = zf + 10);
}

module rahmen() {
    difference() {
        union() {
            difference() {
                union() {
                    rbox([xL, yB, 0], [schacht_w + 2 * rand, schacht_h + 2 * rand, blende_t], r_ecke);
                    box([xo, yb_out, -einschub], [xr, yt_out, 0.01]);
                    for (k = [0 : klemm_n - 1], oben = [true, false]) federnase(klemm_x(k), oben);
                }
                // Kammer samt Luftschicht der Doppelwand
                box([xo + dw, yb, -einschub + dw], [x_k1, yt, 0]);
                // Spalt (hinten offen, für Kupplung und Magnethalter), Luftkanal, Tasche rechts
                box([x_kw1, yb, -einschub - 1], [x_bw, yt, 0]);
                box([x_bw1, yb, -einschub - 1], [x_rbw0, yt, 0]);
                box([x_rbw1, yb, -einschub - 1], [x_rw0, yt, 0]);
                kammer_innen();
            }
            // innere Wände der Doppelwand
            difference() {
                box([x_k0 - dw, yb - 0.01, z_kr - dw], [x_k1 + 0.01, yt + 0.01, 0.01]);
                kammer_innen();
            }
            kammer_einbauten();
            // Dome reichen vorn bis in die Blendenebene
            for (d = [dom_unten, dom_oben]) translate([d[0], d[1], 0]) cylinder(d = 6.5, h = blende_t);
        }
        // Öffnung über dem Luftkanal
        box([x_bw1, -y_open, -1], [x_rbw0, y_open, blende_t + 1]);
        // Lagerschlitze
        for (i = [0 : n_lam - 1])
            for (xw = [[x_bw - 0.01, x_bw1 + 0.01], [x_rbw0 - 0.01, x_rbw1 + 0.01]])
                yz_extrude(xw[0], xw[1]) translate([lam_y(i), achse_z]) schnapp_schlitz_2d(-einschub - 1);
        for (k = [0 : klemm_n - 1], oben = [true, false]) federzunge(klemm_x(k), oben);
        // Motorwelle durch die Kammerwand
        yz_extrude(x_gf - 0.1, x_kw1 + 0.1) translate([y_k, achse_z]) circle(d = welle_d + 1);
        // Gewinde der Deckelschrauben (M2)
        for (d = [dom_unten, dom_oben]) translate([d[0], d[1], -4]) cylinder(d = 1.8, h = blende_t + 5);
    }
}

// ---------------------------------------------------------------- Deckel
module deckel() {
    difference() {
        rbox([x_k0 - deckel_rand, yb - deckel_rand, blende_t], [kammer_b + 2 * deckel_rand, yt - yb + 2 * deckel_rand, deckel_t], 2);
        for (d = [dom_unten, dom_oben]) translate([d[0], d[1], blende_t - 0.01]) {
            cylinder(d = 2.4, h = deckel_t + 1);
            translate([0, 0, deckel_t - 1.2 + 0.02]) cylinder(d1 = 2.4, d2 = 4.4, h = 1.2);
        }
    }
}

// ---------------------------------------------------------------- Lamellen
// Lokal: Achse auf x, Sehne entlang y, Oberseite der Platte in der Achse.
module lamelle_profil() {
    hull() for (u = [-sehne / 2 + lam_t / 2, sehne / 2 - lam_t / 2])
        translate([u, -lam_t / 2]) circle(d = lam_t);
}
module lamelle(antrieb = false) {
    yz_extrude(x_lam0, x_lam1) lamelle_profil();
    // Zapfen rechts durch die Lagerwand, Kurbel, Kurbelzapfen durch die Koppelstange
    yz_extrude(x_lam1 - 0.01, x_fin1) circle(d = zapfen_d);
    yz_extrude(x_fin0, x_fin1) hull() { circle(d = zapfen_d); translate([kurbel_r, 0]) circle(d = zapfen_d); }
    yz_extrude(x_fin1 - 0.01, x_bar1) translate([kurbel_r, 0]) circle(d = zapfen_d);
    // Zapfen links durch die Lagerwand in den Spalt
    if (antrieb) {
        yz_extrude(x_bw - 0.3, x_lam0 + 0.01) circle(d = zapfen_d);
        // Klaue: steht bei „zu“ in z, so lässt sich die Lamelle von hinten in die Kupplung schieben
        yz_extrude(x_sp1 - 1.4, x_bw - 0.29) translate([-zunge_t / 2, -z_r]) square([zunge_t, z_r + 5]);
    } else {
        yz_extrude(x_bw - 0.01, x_lam0 + 0.01) circle(d = zapfen_d);
        yz_extrude(x_sp1 - 2, x_bw) d_profil(zapfen_d);
    }
    for (x = [[x_lam0, x_lam0 + 4], [x_lam1 - 4, x_lam1]])
        yz_extrude(x[0], x[1]) hull() { circle(d = zapfen_d); translate([-2 * zapfen_d, -lam_t / 2]) circle(d = lam_t); translate([2 * zapfen_d, -lam_t / 2]) circle(d = lam_t); }
}
module lamelle_einbau(i, beta) {
    translate([0, lam_y(i), achse_z]) rotate([beta, 0, 0]) lamelle(i == antrieb_nr);
}

// ---------------------------------------------------------------- Kupplung und Magnethalter
// Lokal wie die Lamelle (Achse auf x); beide drehen mit ihrer Lamelle.
module kupplung() {
    difference() {
        yz_extrude(x_sp0, x_sp1) circle(d = 12);
        // Motorwelle mit Abflachung
        yz_extrude(x_sp0 - 1, x_sp0 + bohr_tief) intersection() {
            circle(d = welle_d + 0.2);
            translate([-welle_d, -welle_d / 2 + (welle_d - welle_flach) - 0.1]) square([2 * welle_d, 2 * welle_d]);
        }
        // Nut für die Klaue, quer durch
        yz_extrude(x_sp1 - 1.5, x_sp1 + 1) translate([-(zunge_t + 0.4) / 2, -7]) square([zunge_t + 0.4, 14]);
    }
}
module magnethalter() {
    difference() {
        yz_extrude(x_sp0, x_sp1) circle(d = magnet[0] + 2.5);
        yz_extrude(x_sp0 - 1, x_sp0 + magnet[1] + 0.1) circle(d = magnet[0] + 0.2);
        yz_extrude(x_sp1 - 2.2, x_sp1 + 1) d_profil(zapfen_d, zapfen_spiel);
    }
}
module kupplung_einbau(beta) { translate([0, y_k, achse_z]) rotate([beta, 0, 0]) kupplung(); }
module magnethalter_einbau(beta) { translate([0, y_j, achse_z]) rotate([beta, 0, 0]) magnethalter(); }

// ---------------------------------------------------------------- Koppelstange (rechts)
module koppelstange() {
    span = (n_lam - 1) * teilung;
    difference() {
        box([x_bar0, -stange_h / 2, -stange_h / 2], [x_bar1, span + stange_h / 2, stange_h / 2]);
        for (i = [0 : n_lam - 1])
            yz_extrude(x_bar0 - 1, x_bar1 + 1) translate([i * teilung, 0]) schnapp_schlitz_2d(-stange_h / 2 - 1);
    }
}
module koppelstange_einbau(beta) {
    translate([0, lam_y(n_lam - 1) + kurbel_r * cos(beta), achse_z + kurbel_r * sin(beta)]) koppelstange();
}

// ---------------------------------------------------------------- Platzhalter
module motor_dummy() {
    color("silver") {
        box([x_gf - getr_h, g_y0, achse_z - getr_b / 2], [x_gf, g_y1, achse_z + getr_b / 2]);
        box([x_gf - getr_h, m_y0, achse_z - getr_b / 2], [x_gf, g_y0 + 0.01, achse_z + getr_b / 2]);
    }
    // Welle dreht mit der Antriebslamelle (Abflachung wie in der Kupplung)
    color("gold") translate([0, y_k, achse_z]) rotate([beta, 0, 0]) yz_extrude(x_gf - 0.01, x_gf + welle_l) intersection() {
        circle(d = welle_d);
        translate([-welle_d, -welle_d / 2 + (welle_d - welle_flach)]) square([2 * welle_d, 2 * welle_d]);
    }
}
module elektronik_dummy() {
    color("dimgray") translate([x_mitte, akku_y0, akku_z]) rotate([-90, 0, 0]) cylinder(d = akku_dim[1], h = akku_dim[0]);
    color("purple") box([x_as0, y_j - as_b / 2, achse_z - as_b / 2], [x_as1, y_j + as_b / 2, achse_z + as_b / 2]);
    // Platinen am Deckel: XIAO, Lochraster, DRV8833
    z_p = blende_t - 4;
    color("darkgreen") box([x_mitte - xiao[1] / 2, board_y0, z_p], [x_mitte + xiao[1] / 2, board_y0 + xiao[0], z_p + 1.6]);
    color("tan") box([x_k0 + 0.5, board_y0 + xiao[0] + 2, z_p], [x_k1 - 0.5, board_y0 + xiao[0] + 2 + board_len, z_p + 1.6]);
    // DRV8833 vor dem Motor
    color("red") box([x_mitte - drv[1] / 2, g_y1 - drv[0] - 1, z_p], [x_mitte + drv[1] / 2, g_y1 - 1, z_p + 1.6]);
    color("gray") translate([0, y_j, achse_z]) yz_extrude(x_sp0 + 0.01, x_sp0 + magnet[1]) circle(d = magnet[0]);
}
module schacht_dummy() {
    color("silver", 0.5) difference() {
        box([xL - 30, yB - 30, -einschub - 20], [-xL + 30, -yB + 30, 0]);
        box([-schacht_w / 2, -schacht_h / 2, -einschub - 21], [schacht_w / 2, schacht_h / 2, 1]);
    }
}

// ---------------------------------------------------------------- Proben
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
module probe_lager() {
    difference() {
        union() {
            box([0, -14, 0], [lager_wand, 14, -achse_z + 10]);
            box([-6, -14, 0], [lager_wand + 6, 14, 2]);
        }
        translate([0, 0, -achse_z]) mirror([0, 0, 1])
            yz_extrude(-1, lager_wand + 1) schnapp_schlitz_2d(-20);
    }
    translate([20, 0, z_r]) {
        rotate([0, 90, 0]) cylinder(d = zapfen_d, h = 20);
        translate([5, 0, 0]) yz_extrude(0, 15) lamelle_profil();
    }
}

// ---------------------------------------------------------------- Ausgabe
module print_rahmen() { rotate([180, 0, 0]) translate([0, 0, -blende_t]) rahmen(); }   // Blende auf dem Bett
module print_lamelle(antrieb) { translate([0, 0, z_r]) lamelle(antrieb); }          // flach
module print_koppelstange() { rotate([0, -90, 0]) translate([-x_bar0, 0, 0]) koppelstange(); }
module print_kupplung() { rotate([0, 90, 0]) translate([-x_sp1, 0, 0]) kupplung(); }     // Nut oben
module print_magnethalter() { rotate([0, 90, 0]) translate([-x_sp1, 0, 0]) magnethalter(); }  // Magnettasche oben
module print_deckel() { rotate([180, 0, 0]) translate([0, 0, -(blende_t + deckel_t)]) deckel(); }  // Außenseite aufs Bett
module print_probe_einschub() { rotate([180, 0, 0]) translate([0, 0, -2]) probe_einschub(); }

beta = oeffnungswinkel(oeffnung);
if (part == "assembly") {
    if (show_rahmen) color("whitesmoke") rahmen();
    for (i = [0 : n_lam - 1]) color("lightsteelblue") lamelle_einbau(i, beta);
    color("orange") koppelstange_einbau(beta);
    color("gold") kupplung_einbau(beta);
    color("gold") magnethalter_einbau(beta);
    motor_dummy();
    elektronik_dummy();
    if (show_deckel) color("seagreen", 0.4) deckel();
} else if (part == "rahmen") print_rahmen();
else if (part == "lamelle") print_lamelle(false);
else if (part == "lamelle_antrieb") print_lamelle(true);
else if (part == "koppelstange") print_koppelstange();
else if (part == "kupplung") print_kupplung();
else if (part == "magnethalter") print_magnethalter();
else if (part == "deckel") print_deckel();
else if (part == "probe_einschub") print_probe_einschub();
else if (part == "probe_lager") probe_lager();
else if (part == "einbau_rahmen") rahmen();
else if (part == "einbau_lamellen") for (i = [0 : n_lam - 1]) lamelle_einbau(i, beta);
else if (part == "einbau_lamelle") lamelle_einbau(nr, beta);
else if (part == "einbau_koppelstange") koppelstange_einbau(beta);
else if (part == "einbau_kupplung") kupplung_einbau(beta);
else if (part == "einbau_magnethalter") magnethalter_einbau(beta);
else if (part == "einbau_deckel") deckel();
else if (part == "ref_motor") motor_dummy();
else if (part == "ref_elektronik") elektronik_dummy();
else if (part == "ref_schacht") schacht_dummy();
