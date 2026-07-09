# Convert a .mid file into a small cropped notation-image (5-line staff + notes).
#
# Pipeline: functions/vendor/midi2ly (.mid -> .ly) -> lilypond (.ly -> .png) -> convert -trim (autocrop).
#
# functions/vendor/midi2ly is a patched copy of the midi2ly script shipped with
# the system's lilypond package: the upstream version divides with "/" where it
# means integer division, which produces a float and crashes under Python 3
# (`"'" * commas` in Note.dump()). We vendor a one-line fix instead of relying
# on a system install being patched.
midi_to_score <- function(mid_path, out_dir="songs/scores", overwrite=FALSE,
                           duration_quant=16, start_quant=16, resolution=200){
    stopifnot(file.exists(mid_path))
    out_png <- pst(out_dir, "/", tools::file_path_sans_ext(basename(mid_path)), ".png")

    # Cache: skip if already rendered and up to date
    if(!overwrite && file.exists(out_png) &&
       file.mtime(out_png) > file.mtime(mid_path)){
        return(invisible(out_png))
    }

    tmp <- tempfile("score")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive=TRUE), add=TRUE)

    # .mid -> .ly
    ly_path <- pst(tmp, "/score.ly")
    midi2ly_cmd <- pst(
        "python3 functions/vendor/midi2ly --absolute-pitches",
        " --duration-quant=", duration_quant,
        " --start-quant=", start_quant,
        " -o ", shQuote(ly_path), " ", shQuote(mid_path)
    )
    status <- system(midi2ly_cmd)
    if(status != 0 || !file.exists(ly_path)){
        stop("midi2ly failed for ", mid_path)
    }

    # Drop the GM instrument-name label (redundant with the HTML alt text)
    ly <- scan(ly_path, what="character", sep="\n", blank.lines.skip=FALSE, quiet=TRUE)
    ly <- ly[!grepl("Staff\\.instrumentName", ly)]
    write(ly, ly_path)

    # Wrap with a tight, single-system, title-less paper block
    wrapper_path <- pst(tmp, "/wrapper.ly")
    writeLines(c(
        "\\paper {",
        "  indent = 0",
        "  ragged-right = ##t",
        "  print-page-number = ##f",
        "  tagline = ##f",
        "}",
        "\\include \"score.ly\""
    ), wrapper_path)

    # .ly -> .png
    lilypond_cmd <- pst(
        "cd ", shQuote(tmp), " && lilypond --png -dresolution=", resolution,
        " -o out wrapper.ly"
    )
    status <- system(lilypond_cmd)
    raw_png <- pst(tmp, "/out.png")
    if(status != 0 || !file.exists(raw_png)){
        stop("lilypond failed to render ", mid_path)
    }

    # Autocrop the whitespace margins
    dir.create(out_dir, recursive=TRUE, showWarnings=FALSE)
    crop_cmd <- pst(
        "convert ", shQuote(raw_png),
        " -trim +repage -bordercolor white -border 12 ", shQuote(out_png)
    )
    status <- system(crop_cmd)
    if(status != 0 || !file.exists(out_png)){
        stop("convert (autocrop) failed for ", mid_path)
    }

    return(invisible(out_png))
}

# Render every midi/*.mid into songs/scores/*.png (skipping up-to-date ones).
# Score PNGs are committed to the repo (they're small, derived assets that
# only need regenerating when a .mid changes), so CI does not install
# lilypond/midi2ly/convert -- it just ships whatever is already committed
# under songs/scores/. If those tools aren't present (e.g. on CI), skip
# rendering entirely rather than failing the whole html build.
render_scores <- function(midi_dir="midi", out_dir="songs/scores"){
    mids <- dir(midi_dir, pattern="\\.mid$", full.names=TRUE)
    if(length(mids) == 0) return(invisible(character(0)))
    if(Sys.which("lilypond") == "" || Sys.which("convert") == "" || Sys.which("python3") == ""){
        warning("lilypond/convert/python3 not found -- skipping score rendering; ",
                "using whatever is already committed under ", out_dir)
        return(invisible(character(0)))
    }
    cat("\nRendering scores from:", midi_dir, "\n")
    out <- character(0)
    for(mid in mids){
        res <- tryCatch(midi_to_score(mid, out_dir=out_dir), error=function(e){
            warning("score render failed for ", mid, ": ", conditionMessage(e))
            NULL
        })
        if(!is.null(res)){
            cat("  ", mid, "->", res, "\n")
            out <- c(out, res)
        }
    }
    return(invisible(out))
}
