################################################################
# Find the screen size
system("xrandr | grep '*' | awk '{print $1}'")
c(1920,1200)/100*1.75 # approx. cm
width <- 33.6 # cm
height <- 21  # cm
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
chords <- TRUE
strums <- TRUE
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
nmall <- c(dir("Songs", full.names = TRUE), dir("SongsTransposed", full.names = TRUE))

# Go
L <- lapply(nmall, function(nm){
  songnm <- pst("Songs/",basename(gsub("_trans\\d+","",nm)))
  switch(songnm,
         "Songs/Old_school_klassikere-:-Noget_om_Helte.txt"=
           add(nm, columns=2, fontsize=12, linespace=1.2),
         "Songs/Old_school_klassikere-:-Sensommervise.txt"=
           add(nm, columns=2, fontsize=14, linespace=1.2),
         "Songs/Old_school_klassikere-:-Kringsatt_av_fiender.txt"=
           add(nm, columns=3, fontsize=16, linespace=1.2,
               newlinesbefore = c("\\[Verse"=1,
                                  "\\[Verse 3"=2,
                                  "\\[Verse 5"=1)),
         "Songs/Flaming_Lips-:-Do_you_realize.txt"=
           add(nm, columns=2, fontsizestrum = 10, fontsize=12, linespace=1.2, vspace=0.35),
         "Songs/REM-:-Loosing_My_Religion.txt"=
           add(nm, fontsize=15, linespace=1.15),
#               newlinesbefore = c("\\[Intro"=74,
#                                  "\\[Verse 2"=7,
#                                  "\\[Verse 3"=7)),
         "Songs/Flaming_Lips-:-Race_for_the_prize.txt"=
           add(nm, columns=3, fontsize=15, fontsizestrum=8,
               newlinesbefore = c("\\[Intro"=74,
                                  "\\[Verse 2"=7)),
         "Songs/Radiohead-:-Creep.txt"=
           add(nm, fontsize=15, fontsizestrum=12,
               newlinesbefore = c("\\[Verse 1"=2,
                                  "\\[Chorus 2"=11)),
         "Songs/Radiohead-:-Karma_Police.txt"=
           add(nm, 
               newlinesbefore = c("\\[Chorus 2"=6)),
         "Songs/Mouritz-:-Allermindst_dig_selv.txt"=
           add(nm, columns=2, fontsize=17, linespace=1.3,
               newlinesbefore = c("\\["=1,
                                  "\\[Verse 1"=1,
                                  "\\[Verse 3"=11)),
         "Songs/Mouritz-:-Blik_bang_bang.txt"=
           add(nm,
               newlinesbefore = c("\\["=1,
                                  "\\[Verse 1"=1,
                                  "\\[Verse 2"=7)),
         "Songs/Kim_Larsen-:-Joanna.txt"=
           add(nm, columns=2, fontsize=17, linespace=1.3,
               newlinesbefore = c("\\[Verse"=1,
                                  "\\[Chorus"=2,
                                  "\\[Verse 3"=3)),
         "Songs/Kim_Larsen-:-Midt_om_natten.txt"=
           add(nm, columns=2, fontsize=15,
               newlinesbefore = c("\\[Verse 2"=1)),
         "Songs/Kim_Larsen-:-Jutlandia.txt"=
           add(nm, columns=3, fontsizestrum = 10, fontsize=13, linespace=1.1,
               newlinesbefore = c("\\[.*\\]"=1,
                                  "\\[Verse 2"=10,
                                  "\\[Verse 3"=15)),
         "Songs/Kim_Larsen-:-De_smukke_unge_mennesker.txt"=
           add(nm, columns=3, fontsize=15,
               newlinesbefore = c("\\[Verse"=1,
                                  "\\[Chorus 1"=5,
                                  "\\[Chorus 2"=5)),
         "Songs/Kim_Larsen-:-Susan_Himmelblå.txt"=
           add(nm, fontsize=13, linespace=1.05),
         "Songs/CV_Jørgensen-:-Costa_del_Sol.txt"=
           add(nm, fontsize=13, linespace=1, columns=2,
               newlinesbefore = c("\\[Chorus 1"=8)),
         "Songs/Cohen-:-Bird_on_a_wire.txt"=
           add(nm, fontsize=13, linespace=1.2, columns=2,
               newlinesbefore = c("\\[Verse 1"=3,
                                  "\\[Verse 2"=20)),
         "Songs/Cohen-:-So_long_Marianne.txt"=
           add(nm, fontsize=13, linespace=1.2, columns=2),
         "Songs/Bob_Dylan-:-Blowin’_in_the_wind.txt"=
           add(nm,
               insertbefore = c("\\[.*\\]"="\\vspace{1.5ex}",
                                "\\[Chorus 2]"="\\vspace{10ex}")),
         "Songs/Bob_Dylan-:-Hurricane.txt"=
           add(nm, fontsize=11, linespace=1, columns=2,
               newlinesbefore = c("\\[Intro"=1,
                                  "\\[Instrumental 1"=2,
                                  "\\[Verse 7"=3,
                                  "\\[Verse 9"=3,
                                  "\\[Verse 11"=3)),
         "Songs/Bob_Dylan-:-Mr._Tambourine_Man.txt"=
           add(nm, fontsize=13, linespace=1,
               insertbefore = c("\\[.*\\]"="\\vspace{3.5ex}",
                                "\\[Chorus 1"="\\vspace{5.5ex}",
                                "\\[Verse 3"="\\vspace{14.5ex}")),
         "Songs/Bob_Dylan-:-The_Times_They_Are_A-Changin.txt"=
             add(nm, fontsize=13, linespace=1),
         "Songs/Clash-:-London_Calling.txt"=
           add(nm, fontsize=13, linespace=0.95),
         "Songs/Neil_Young-:-Heart_of_gold.txt"=
           add(nm, fontsizestrum=12),
         "Songs/Ulige_Numre-:-Frit_land.txt"=
           add(nm, fontsize=14, columns=3),
         "Songs/Gnags-:-Vilde_kaniner.txt"=
           add(nm, columns=3, fontsize=12, linespace=1.1, vspace=0.4,
               newlinesbefore = c("\\[Intro"=2,
                                  "\\[Verse 1"=2,
                                  "\\[Verse 2"=1,
                                  "\\[Verse 3"=2,
                                  "\\[Chorus3 1"=2,
                                  "\\[Chorus3 2"=2,
                                  "\\[Chorus 2"=3)),
         "Songs/Nirvana-:-Come_as_you_are.txt"=
           add(nm, columns=3, fontsize=14, linespace=1.2, vspace=0.3,
               newlinesbefore = c("\\[Chorus 1"=8,
                                  "\\[Chorus 2"=5,
                                  "\\[Verse 3"=5)),
         "Songs/Neil_Young-:-Old_man.txt"=
           add(nm, columns=3, fontsize=14, linespace=1.2, vspace=0.3,
               newlinesbefore = c("\\[Chorus 1"=8,
                                  "\\[Chorus 2"=5)),
         "Songs/Nena-:-99_Luftballons.txt"=
           add(nm, fontsize=13, linespace=1, columns=2,
               newlinesbefore = c("\\[Verse 4"=12)),
         "Songs/Love_Shop-:-Leve_er_at_dø_med_stil.txt"=
           add(nm, columns=3, fontsize=14, linespace=1.2, vspace=0.3,
               newlinesbefore = c("\\[Chorus 3"=4)),
         "Songs/Love_Shop-:-Underdanmark.txt"=
           add(nm, fontsize=14, linespace=1.2, vspace=0.3,
               newlinesbefore = c("\\[Verse 3"=8)),
         "Songs/Skammens_vogn-:-Blicher.txt"=
           add(nm, fontsize=12, linespace=0.95,
               newlinesbefore = c("\\[Verse 1"=3,
                                  "\\[Verse 3"=11)),
         "Songs/Skammens_vogn-:-Brug_for_dig.txt"=
           add(nm, fontsize=14, linespace=1.2,
               newlinesbefore = c("\\[Verse 3"=3)),
         "Songs/Skammens_vogn-:-Kender_du_det.txt"=
           add(nm, fontsize=12, linespace=0.96,
               newlinesbefore = c("\\[Chorus 2"=2)),
         "Songs/Skammens_vogn-:-Kunst_og_rock.txt"=
           add(nm, fontsize=13, linespace=0.94,
               newlinesbefore = c("\\[Verse 3"=0)),
         "Songs/Skammens_vogn-:-Rens_mine_tanker.txt"=
           add(nm, columns=3, fontsize=13, linespace=1.1,
               newlinesbefore = c("\\[Verse 3"=2,
                                  "\\[Verse 5"=4)),
         "Songs/Stevie_Wonder-:-Pasttime_Paradise.txt"=
           add(nm, fontsize=12, linespace=0.96),
         ## Default
         add(nm))
})

names(L) <- nmall
################################################################
