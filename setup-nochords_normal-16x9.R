################################################################
# Find the screen size
system("xrandr | grep '*' | awk '{print $1}'")
c(1920,1080)/100*1.75 # approx. cm
width <- 33.6 # cm
height <- 18.9  # cm
################################################################


################################################################
# Setup (in cm)
left <- 1
right <- 1
top <- 1
bottom <- 1
font <- c("lmtt","courier","helvet","lmodern","courierpcr","avant")[1]
################################
# Table of content
toc <- TRUE
toccolumns <- 3
################################
# Default values for songs
columns <- 2
vspace <- 0.125 # in em (i.e. font size)
linespace <- 1.25
chords <- FALSE
strums <- FALSE
headers <- FALSE
color <- "Amber"
newpage <- TRUE
pagenumbers <- FALSE
##
fontsize <- 16
fontsizestrum <- 12
################################################################


################################################################
# Process all (adding the transposed)
nmall <- c(dir("cache/Songs", full.names = TRUE), dir("cache/SongsTransposed", full.names = TRUE))

# Go
L <- lapply(nmall, function(nm){
  songnm <- pst("Songs/",basename(gsub("_trans\\d+","",nm)))
  switch(songnm,
         "Songs/Old_school_klassikere-:-Noget_om_Helte.txt"=
           add(nm, columns=2, fontsize=12, linespace=1.2),
         "Songs/Old_school_klassikere-:-Sensommervise.txt"=
           add(nm, columns=2, fontsize=14, linespace=1.2),
         "Songs/Old_school_klassikere-:-Kringsatt_av_fiender.txt"=
           add(nm, columns=3, fontsize=16, linespace=1.2),
         "Songs/Flaming_Lips-:-Do_you_realize.txt"=
           add(nm, columns=2, fontsizestrum = 10, fontsize=12, linespace=1.2, vspace=0.35),
         "Songs/REM-:-Loosing_My_Religion.txt"=
           add(nm, fontsize=15, linespace=1.15),
         "Songs/Flaming_Lips-:-Race_for_the_prize.txt"=
           add(nm, columns=3, fontsize=15, fontsizestrum=8),
         "Songs/Radiohead-:-Creep.txt"=
           add(nm, fontsize=15, fontsizestrum=12),
         "Songs/Radiohead-:-Karma_Police.txt"=
           add(nm),
         "Songs/Mouritz-:-Allermindst_dig_selv.txt"=
           add(nm, columns=2, fontsize=17, linespace=1.3),
         "Songs/Mouritz-:-Blik_bang_bang.txt"=
           add(nm),
         "Songs/Kim_Larsen-:-Joanna.txt"=
           add(nm, columns=2, fontsize=17, linespace=1.3),
         "Songs/Kim_Larsen-:-Midt_om_natten.txt"=
           add(nm, columns=2, fontsize=15),
         "Songs/Kim_Larsen-:-Jutlandia.txt"=
           add(nm, columns=3, fontsizestrum = 10, fontsize=13, linespace=1.1),
         "Songs/Kim_Larsen-:-De_smukke_unge_mennesker.txt"=
           add(nm, columns=3, fontsize=15),
         "Songs/Kim_Larsen-:-Susan_Himmelblå.txt"=
           add(nm, fontsize=13, linespace=1.05),
         "Songs/CV_Jørgensen-:-Costa_del_Sol.txt"=
           add(nm, fontsize=13, linespace=1, columns=2),
         "Songs/Cohen-:-Bird_on_a_wire.txt"=
           add(nm, fontsize=13, linespace=1.2, columns=2),
         "Songs/Cohen-:-So_long_Marianne.txt"=
           add(nm, fontsize=13, linespace=1.2, columns=2),
         "Songs/Bob_Dylan-:-Blowin’_in_the_wind.txt"=
           add(nm),
         "Songs/Bob_Dylan-:-Hurricane.txt"=
           add(nm, fontsize=11, linespace=1, columns=2),
         "Songs/Bob_Dylan-:-Mr._Tambourine_Man.txt"=
           add(nm, fontsize=13, linespace=1),
         "Songs/Bob_Dylan-:-The_Times_They_Are_A-Changin.txt"=
             add(nm, fontsize=13, linespace=1),
         "Songs/Clash-:-London_Calling.txt"=
           add(nm, fontsize=13, linespace=0.95),
         "Songs/Neil_Young-:-Heart_of_gold.txt"=
           add(nm, fontsizestrum=12),
         "Songs/Ulige_Numre-:-Frit_land.txt"=
           add(nm, fontsize=14, columns=3),
         "Songs/Gnags-:-Vilde_kaniner.txt"=
           add(nm, columns=3, fontsize=12, linespace=1.1, vspace=0.4),
         "Songs/Nirvana-:-Come_as_you_are.txt"=
           add(nm, columns=3, fontsize=14, linespace=1.2, vspace=0.3),
         "Songs/Neil_Young-:-Old_man.txt"=
           add(nm, columns=3, fontsize=14, linespace=1.2, vspace=0.3),
         "Songs/Nena-:-99_Luftballons.txt"=
           add(nm, fontsize=13, linespace=1, columns=2),
         "Songs/Love_Shop-:-Leve_er_at_dø_med_stil.txt"=
           add(nm, columns=3, fontsize=14, linespace=1.2, vspace=0.3),
         "Songs/Love_Shop-:-Underdanmark.txt"=
           add(nm, fontsize=14, linespace=1.2, vspace=0.3),
         "Songs/Skammens_vogn-:-Blicher.txt"=
           add(nm, fontsize=12, linespace=0.95),
         "Songs/Skammens_vogn-:-Brug_for_dig.txt"=
           add(nm, fontsize=14, linespace=1.2),
         "Songs/Skammens_vogn-:-Kender_du_det.txt"=
           add(nm, fontsize=12, linespace=0.96),
         "Songs/Skammens_vogn-:-Kunst_og_rock.txt"=
           add(nm, fontsize=13, linespace=0.94),
         "Songs/Skammens_vogn-:-Rens_mine_tanker.txt"=
           add(nm, columns=3, fontsize=13, linespace=1.1),
         "Songs/Stevie_Wonder-:-Pasttime_Paradise.txt"=
           add(nm, fontsize=12, linespace=0.96),
         ## Default
         add(nm))
})

names(L) <- nmall
################################################################
