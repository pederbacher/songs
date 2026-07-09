process_songs <- function(infolder="songs", outfolder="cache/songsprocessed"){
    # Open the songs
    files <- dir(infolder, "___.*\\.txt$", recursive=TRUE, full.names=TRUE)
    #
    unlink(pst(outfolder,"/"), recursive=TRUE)
    dir.create(outfolder)
    #
    cat("\nReading:",length(files),"files\nFrom folder:",infolder,"\nWriting to:",outfolder,"\n")
    #
    L <- list()
    
    for(nm in files){
        # Identify chordlines
        x <- scan(nm, what="character", sep="\n", blank.lines.skip=FALSE, quiet=TRUE)
        # Remove whitespace in the end
        x <- trimws(x, which="right") 
        # Identify chord lines
        #browser()
        #i <- grep("(^| |\\|)[ABHCDEFG]([b#])?/[ABHCDEFG][b#]?\\*?m?(maj)?\\d?(sus4)?( |$)|¤|\\([sS]tar|sweep pick|syng på", x)
        i <- grep("[ABHCDEFGb#\\|]", x)

        if(length(i) > 0){
            # Remove
            # Ratio between normal letters and capitalized
            ratio <- lengths(regmatches(x[i], gregexpr("[a-z]", x[i]))) / lengths(regmatches(x[i], gregexpr("[A-Z]", x[i])))
            irm <- which(ratio > 4)
            # Special words?
            irm <- c(irm, grep("nuclear", x[i]))
            # Remove them
            if(length(irm) > 0){ i <- i[-irm]}
            # Add some special cases
            i <- c(i, grep("¤|[sS]tart|nochord", x))
        }
        # Also tag all lines inside [chords]...[next section] blocks
        chord_starts <- grep("^\\[chords\\]$|^\\[guideline", x, ignore.case=TRUE)
        next_sections <- grep("^\\[.+\\]$", x)
        for(cs in chord_starts){
            # Find the next section marker after this [chords] line
            after <- next_sections[next_sections > cs]
            end <- if(length(after) > 0) after[1] - 1 else length(x)
            block <- (cs+1):end
            block <- block[block <= length(x)]
            # Tag non-empty lines in the block that aren't already chord lines
            for(bi in block){
                if(nchar(trimws(x[bi])) > 0 && !grepl("chordline", x[bi])){
                    i <- c(i, bi)
                }
            }
        }
        # Tag [Tabs]...[next section] block content with "tabsblock" so
        # make-pdfs.R can still find and drop the ASCII tab diagram for
        # print, even though the [Tabs] marker line itself is about to be
        # deleted below (along with every other bracket-marker line).
        tabs_starts <- grep("^\\[[Tt]abs?\\]$", x)
        for(ts in tabs_starts){
            after <- next_sections[next_sections > ts]
            end <- if(length(after) > 0) after[1] - 1 else length(x)
            block <- (ts+1):end
            block <- block[block <= length(x)]
            block <- block[nchar(trimws(x[block])) > 0]
            x[block] <- pst(x[block], " tabsblock")
        }
        i <- sort(unique(i))
        # Never chord-tag a line containing [ and ] (section markers, annotations
        # like [x2], and markdown score-image tags like ![Tema](song_tema.mid)) --
        # otherwise such a line can slip through chord detection (e.g. "[Hook]"
        # matches on its capital H) and later removal steps can't find it because
        # it's been rewritten into a <span> before they run.
        has_brackets <- grepl("\\[.*\\]", x)
        i <- i[!has_brackets[i]]
        # Finally, remove the specifically marked textlines
        ii <- grep("textline$", x)
        if(length(ii) > 0){
            i <- i[!(i %in% ii)]
            x[ii] <- trimws(gsub("textline", "", x[ii]))
        }
        # Add a tag in the end of the lines
        x[i] <- pst(x[i], " chordline")
        # Remove section-marker/annotation lines entirely (not just blanked --
        # otherwise stacked markers like repeated [Verse] tags leave behind
        # stacked blank lines downstream) -- e.g. [Verse], [Hook], [x2] -- but
        # keep markdown score-image tags (![Alt](midi/file.mid)[N]), which
        # still need to reach makeit_html.R (turned into <img>) / make-pdfs.R
        # (explicitly dropped there).
        is_score_tag <- grepl("^!\\[.*\\]\\(.*\\.mid\\)(\\[[0-9]+\\])?\\s*$", x)
        x <- x[is_score_tag | !grepl("\\[.*\\]", x)]
        # Keep it
        newnm <- pst(outfolder,"/",basename(nm))
        L[[newnm]] <- x
        write(x, newnm)
    }

    # Make transposed versions
    outfoldernew <- pst(outfolder,"Transposed")
    unlink(pst(outfoldernew,"/"), recursive=TRUE)
    dir.create(outfoldernew)
    for(ii in 0:11){
        transpose(L, trstep=ii, outfolder=outfoldernew)
    }

    # Return names of the songs
    return(names(L))
}
