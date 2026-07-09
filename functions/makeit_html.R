makeit_html <- function(songs){
    ################################################################
    cat("\nGenerating the html files\n")
    # Prepare
    unlink("output_html", recursive=TRUE)
    dir.create("output_html", recursive=TRUE)
    #    
    xhtml <- scan("templates/html/song.html", what="character", sep="\n", blank.lines.skip=FALSE, quiet=TRUE)
    #
    # Make an html file for each song
    for(isong in 1:length(songs)){
        # Song file name
        nm <- getnm(songs[isong])
        # Parse # key=value metadata from raw .txt source
        raw <- scan(songs[isong], what="character", sep="\n", blank.lines.skip=FALSE, quiet=TRUE)
        meta <- list()
        for(line in raw){
            m <- regmatches(line, regexpr("^#\\s*(\\w+)\\s*=\\s*(.+)$", line, perl=TRUE))
            if(length(m) > 0){
                parts <- strsplit(sub("^#\\s*", "", m), "\\s*=\\s*", perl=TRUE)[[1]]
                if(length(parts) == 2) meta[[trimws(parts[1])]] <- trimws(parts[2])
            }
        }
        # Build a JS object literal from the metadata (values are unquoted — expected to be numeric)
        if(length(meta) > 0){
            pairs <- paste(sapply(names(meta), function(k) pst('"',k,'":',meta[[k]])), collapse=", ")
            metajson <- pst("{", pairs, "}")
        } else {
            metajson <- "{}"
        }
        # Read no transpose
        x <- scan(pst(dirname(songs[isong]),"Transposed/",nm,"_trans0.txt"), what="character", sep="\n", blank.lines.skip=FALSE, quiet=TRUE)
        i <- grep("chordline", x)
        x[i] <- ""
        # Strip metadata lines from visible content
        imeta <- grep("^#\\s*\\w+\\s*=", x)
        if(length(imeta) > 0) x[imeta] <- ""
        # Add all the transposed chordlines
        for(trstep in 0:11){
            tmp <- scan(pst(dirname(songs[isong]),"Transposed/",nm,"_trans",trstep,".txt"), what="character", sep="\n", blank.lines.skip=FALSE, quiet=TRUE)
            # Take chordlines and stack them
            tmp <- gsub("chordline|tabsblock", "", tmp[i])
            tmp <- trimws(tmp, which="right")
            tmp <- pst("<span class='chordline no",trstep,"'>",tmp,"</span>")
            x[i] <- pst(x[i], tmp)
        }
        # Replace markdown score-image tags, e.g. ![Tema](midi/song_tema.mid)[2], with <img> tags
        ################################
        score_re <- "^!\\[(.*)\\]\\((.+\\.mid)\\)(\\[([0-9]+)\\])?\\s*$"
        iscore <- grep(score_re, x)
        for(si in iscore){
            m <- regmatches(x[si], regexec(score_re, x[si]))[[1]]
            alt <- m[2]
            n <- if(nchar(m[5]) > 0) m[5] else "1"
            pngname <- pst(tools::file_path_sans_ext(basename(m[3])), "_n", n, ".png")
            x[si] <- pst("<img class='score' src='midiscores/", pngname, "' alt='", alt, "'>")
        }
        # Wrap in the html
        isplit <- grep("SongContent", xhtml)
        x <- c(xhtml[1:(isplit-1)], x, xhtml[(isplit+1):length(xhtml)])
        # Final stuff
        x <- gsub("SongTitle", gsub("_"," ",gsub("___",": ",nm)), x)
        x <- gsub("SongName", gsub("_"," ",strsplit(nm, "___")[[1]][2]), x)
        x <- gsub("SongMetaJSON", metajson, x)
        # Write it
        write(x, pst("./output_html/",nm,".html"))
    }
}
