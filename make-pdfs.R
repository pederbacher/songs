################################################################
# make-pdfs.R
# Generate printable PDFs from each songs/collection-*.txt
# Two variants per collection: with chords and lyrics-only.
# Reads cache/songsprocessedTransposed/ (regenerates it if missing).
################################################################

rm(list=ls())
pst <- paste0
sapply(dir("functions/", pattern="\\.R$", full.names=TRUE), source)

################################################################
# OPTIONS
trstep     <- 0                       # 0..11 — transpose step (0 = original key)
fontsize   <- 11                      # lyric/chord font size (pt)
monofont   <- "Latin Modern Mono"     # monospace font for chord+lyric blocks
engine     <- "lualatex"              # pandoc --pdf-engine
margin     <- "1.2cm"                 # page margin, all sides
chordcolor <- "0.80,0.29,0.00"        # rgb for chord lines (amber)
linespace  <- 0.9                     # Verbatim line-spacing multiplier (1 = normal, <1 = tighter)
################################################################


# Ensure cache exists; regenerate it if not
cat("\nCache missing — running process_songs()\n")
dir.create("cache", showWarnings=FALSE)
process_songs()

dir.create("output_pdf", showWarnings=FALSE)


# LaTeX header (loaded via pandoc -H). Enables \color{...} inside Verbatim.
header_path <- "output_pdf/header.tex"
writeLines(c(
    "\\usepackage{fancyvrb}",
    "\\usepackage{xcolor}",
    pst("\\definecolor{chordcolor}{rgb}{", chordcolor, "}"),
    pst("\\fvset{commandchars=\\\\\\{\\},baselinestretch=", linespace, "}")
), header_path)


# Read a collection file: one filename per non-comment line (comma-separated fields).
# A line whose first field is "regex: <pattern>" expands to every song filename
# matching <pattern> (sorted), inserted at that line's position.
read_collection <- function(path){
    x <- scan(path, what="character", sep="\n", blank.lines.skip=TRUE, quiet=TRUE)
    x <- x[!grepl("^\\s*#", x)]
    x <- x[nchar(trimws(x)) > 0]
    first <- sapply(strsplit(x, ","), function(p) trimws(p[1]))
    all_songs <- basename(dir("songs", "___.*\\.txt$", recursive=TRUE))
    out <- character(0)
    for(f in first){
        if(grepl("^regex:", f)){
            pat  <- trimws(sub("^regex:", "", f))
            hits <- sort(all_songs[grepl(pat, all_songs)])
            if(length(hits) == 0) warning("collection regex matched no songs: ", pat)
            out <- c(out, hits)
        }else{
            out <- c(out, f)
        }
    }
    unique(out)
}


# Build the markdown chunk for one song at a given transpose step and variant
song_md <- function(filename, trstep, variant){
    nm <- sub("\\.txt$", "", filename)
    path <- pst("cache/songsprocessedTransposed/", nm, "_trans", trstep, ".txt")
    if(!file.exists(path)){
        warning("missing cached song: ", path)
        return(NULL)
    }
    x <- scan(path, what="character", sep="\n", blank.lines.skip=FALSE, quiet=TRUE)
    # Drop metadata lines (# key=value)
    x <- x[!grepl("^#\\s*\\w+\\s*=", x)]
    # Drop markdown score-image tags, e.g. ![Tema](song_tema.mid) -- HTML-only
    x <- x[!grepl("^!\\[.*\\]\\(.*\\.mid\\)\\s*$", x)]
    # Drop entire [Tabs] blocks (from the [Tabs] marker up to the next section marker)
    sec_idx    <- grep("^\\[.+\\]$", x)
    tabs_start <- grep("^\\[[Tt]abs?\\]$", x)
    if(length(tabs_start) > 0){
        drop <- integer(0)
        for(ts in tabs_start){
            after <- sec_idx[sec_idx > ts]
            end   <- if(length(after) > 0) after[1] - 1 else length(x)
            drop  <- c(drop, ts:end)
        }
        x <- x[-drop]
    }
    # Drop any line containing a [ ... ] annotation (section markers,
    # [x2]-style repeat notes, etc.)
    x <- x[!grepl("\\[.*\\]", x)]
    # Chord vs lyric handling
    is_chord <- grepl("chordline$", x)
    if(variant == "nochords"){
        x <- x[!is_chord]
        is_chord <- rep(FALSE, length(x))
    }else{
        x <- sub(" chordline$", "", x)
    }
    # Trim leading/trailing blank lines
    while(length(x) > 0 && nchar(trimws(x[1]))          == 0){ x <- x[-1]; is_chord <- is_chord[-1] }
    while(length(x) > 0 && nchar(trimws(x[length(x)]))  == 0){ x <- x[-length(x)]; is_chord <- is_chord[-length(is_chord)] }
    # Color chord lines. Works because the header enables \color inside Verbatim
    # via commandchars=\\\{\}. Chord lines contain no { } \, so it's safe.
    if(any(is_chord)){
        x[is_chord] <- pst("\\color{chordcolor}", x[is_chord], "\\color{black}")
    }
    # Heading "Artist - Title"
    parts  <- strsplit(nm, "___")[[1]]
    artist <- gsub("_", " ", parts[1])
    title  <- gsub("_", " ", parts[2])
    heading <- pst("## ", artist, " - ", title)
    ## Finally, remove double empty lines
    if(variant == "nochords"){
        x <- trimws(x)
    }
    i <- grep("^$",x)
    irm <- i[-1][diff(i) == 1]
    if(length(irm) > 0){
        x <- x[-irm]
    }
    # Raw LaTeX Verbatim block so \color commands are respected, monospace kept
    c(heading, "", "\\begin{Verbatim}", x, "\\end{Verbatim}", "")
}


# Assemble and compile one collection+variant -> PDF
build <- function(collection, variant){
    songs <- read_collection(collection)
    chunks <- lapply(songs, song_md, trstep=trstep, variant=variant)
    # For the chords variant, force each song onto a new page
    if(variant == "chords"){
        chunks <- lapply(chunks, function(ch) c("\\newpage", "", ch))
    }
    md <- unlist(chunks)

    stem     <- sub("^collection-", "", sub("\\.txt$", "", basename(collection)))
    md_path  <- pst("output_pdf/", stem, "_", variant, ".md")
    pdf_path <- pst("output_pdf/", stem, "_", variant, ".pdf")

    md <- c(
        "---",
        pst("title: '", gsub("_", " ", stem),
            if(variant == "nochords") " (lyrics)" else "", "'"),
        "---",
        "",
        "\\clearpage",
        "",
        md
    )
    write(md, md_path)

    cmd <- pst(
        "pandoc --pdf-engine=", engine,
        " --toc --toc-depth=2",
        " -H ", shQuote(header_path),
        " -V geometry:a4paper,landscape,margin=", margin,
        " -V classoption=twocolumn",
        " -V fontsize=", fontsize, "pt",
        " -V monofont=\"", monofont, "\"",
        " -o ", shQuote(pdf_path),
        " ", shQuote(md_path)
    )
    cat("\n", cmd, "\n", sep="")
    system(cmd)
}


collections <- dir("songs", pattern="^collection-.*\\.txt$", full.names=TRUE)
for(coll in collections){
    for(variant in c("chords", "nochords")){
        build(coll, variant)
    }
}

cat("\nDone. Output in output_pdf/\n")

process_songs()
coll <- "songs/collection-roskilde_2026_final.txt"
build(coll, "chords")
build(coll, "nochords")
