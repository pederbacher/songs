html_make_index <- function(collection="", writeit=TRUE, outfile=""){
    extra_headers <- character(0)   # names for extra columns (from # header line)
    extra_lookup  <- list()         # nm -> character vector of extra values
    collection_src <- collection    # remember original before it gets overwritten

    if(length(collection) == 1){
        if(collection == ""){
            # All the songs — no extra columns
            collection <- songs
            if(outfile == ""){
                outfile <- "index.html"
            }
        }else{
            # Collection is a file — parse CSV format
            if(outfile == ""){
                outfile <- pst(getnm(basename(collection)), ".html")
                outfile <- gsub("^collection-", "", outfile)
            }
            raw <- readLines(collection)

            # Optional header line: first line starting with #
            if(length(raw) > 0 && grepl("^#", raw[1])){
                hdr_parts    <- trimws(strsplit(sub("^#\\s*", "", raw[1]), ",")[[1]])
                extra_headers <- hdr_parts[-1]   # skip the filename column
                raw          <- raw[-1]
            }

            # Parse each line: first field = filename, rest = extra values
            parsed <- lapply(raw, function(line){
                parts <- trimws(strsplit(line, ",")[[1]])
                if(length(parts) == 0) return(NULL)
                list(file = parts[1], extra = parts[-1])
            })
            parsed <- Filter(Negate(is.null), parsed)

            filenames <- sapply(parsed, `[[`, "file")

            # Build lookup: nm (without extension) -> extra values
            for(p in parsed){
                nm_key <- getnm(p$file)
                extra_lookup[[nm_key]] <- p$extra
            }

            # Pad extra_headers if fewer headers than max columns
            max_extra <- max(c(0L, sapply(parsed, function(p) length(p$extra))))
            if(length(extra_headers) < max_extra){
                extra_headers <- c(extra_headers,
                    rep("", max_extra - length(extra_headers)))
            }

            collection <- filenames
        }
    }

    max_extra <- length(extra_headers)

    # Find the songs matching the collection (base songs)
    collection <- songs[basename(songs) %in% basename(collection)]
    # Also include versioned variants of those base songs
    base_keys <- sub("\\..*$", "", sapply(collection, function(s) getnm(basename(s))))
    all_keys  <- sub("\\..*$", "", sapply(songs, function(s) getnm(basename(s))))
    collection <- songs[all_keys %in% base_keys]

    # Parse each song into: artist, base song name, version
    nms        <- sapply(collection, getnm)
    artist_ids <- sapply(strsplit(nms, "___"), `[`, 1)
    song_parts <- sapply(strsplit(nms, "___"), `[`, 2)
    song_base_ids <- sub("\\..*$", "", song_parts)
    versions      <- sub("^[^.]*\\.?", "", song_parts)

    df <- data.frame(
        nm           = nms,
        artist_id    = artist_ids,
        song_base_id = song_base_ids,
        version      = versions,
        key          = paste0(artist_ids, "___", song_base_ids),
        stringsAsFactors = FALSE
    )

    # Sort: artist then song base
    df <- df[order(df$artist_id, df$song_base_id), ]
    keys <- unique(df$key)

    # Load template
    xhtml <- scan("templates/html/index.html", what="character", sep="\n", blank.lines.skip=FALSE)

    # Replace thead <tr> with dynamically generated header (adds extra <th> if needed)
    # Header format: "Label (val1;val2;...)" → display "Label", data-order="val1;val2;..."
    make_th <- function(hdr){
        m <- regmatches(hdr, regexec("^(.+?)\\s*\\(([^)]+)\\)\\s*$", hdr))[[1]]
        if(length(m) == 3){
            pst("      <th data-order=\"", m[3], "\">", trimws(m[2]), "</th>")
        } else {
            pst("      <th>", hdr, "</th>")
        }
    }
    thead_tr_start <- grep("<tr>",  xhtml)[1]
    thead_tr_end   <- grep("</tr>", xhtml)[1]
    new_thead <- c(
        "    <tr>",
        "      <th>Artist</th>",
        "      <th>Song</th>",
        "      <th>Versions</th>",
        if(max_extra > 0) sapply(extra_headers, make_th),
        "    </tr>"
    )
    xhtml <- c(xhtml[1:(thead_tr_start-1)], new_thead, xhtml[(thead_tr_end+1):length(xhtml)])

    # Find the template tbody <tr> block (now the second <tr> after the rewrite)
    i <- grep("<tr>", xhtml)[2]:grep("</tr>", xhtml)[2]

    # Generate rows
    x <- NULL
    for(key in keys){
        rows         <- df[df$key == key, ]
        base_rows    <- rows[rows$version == "", ]
        version_rows <- rows[rows$version != "", ]

        ref <- if(nrow(base_rows) > 0) base_rows[1, ] else version_rows[1, ]
        artist_name <- gsub("_", " ", ref$artist_id)
        song_name   <- substr(gsub("_", " ", ref$song_base_id), 1, 48)

        song_cell <- if(nrow(base_rows) > 0){
            pst('<a href="', ref$nm, '.html">', song_name, '</a>')
        } else {
            song_name
        }

        version_cell <- ""
        if(nrow(version_rows) > 0){
            links <- sapply(seq_len(nrow(version_rows)), function(j){
                vr <- version_rows[j, ]
                pst('<a href="', vr$nm, '.html">', vr$version, '</a>')
            })
            version_cell <- paste(links, collapse=", ")
        }

        # Extra columns: look up by key (base nm)
        extra_vals <- if(key %in% names(extra_lookup)){
            ev <- extra_lookup[[key]]
            # Pad to max_extra
            length(ev) <- max_extra
            ev[is.na(ev)] <- ""
            ev
        } else {
            rep("", max_extra)
        }
        extra_tds <- if(max_extra > 0)
            paste0("      <td>", extra_vals, "</td>")
        else character(0)

        x <- c(x,
            "    <tr>",
            pst("      <td>", artist_name, "</td>"),
            pst("      <td>", song_cell, "</td>"),
            pst("      <td>", version_cell, "</td>"),
            extra_tds,
            "    </tr>"
        )
    }

    val <- c(xhtml[1:(i[1]-1)], x, xhtml[(i[length(i)]+1):length(xhtml)])

    # --- Build TOC nav links (all collection pages + main index) ---
    make_toc_title <- function(f) {
        nm <- gsub("^collection-", "", gsub("\\.txt$", "", basename(f)))
        nm <- gsub("_", " ", nm)
        paste0(toupper(substr(nm, 1, 1)), substr(nm, 2, nchar(nm)))
    }
    coll_files  <- sort(dir("songs", "^collection-.*\\.txt$"))
    coll_htmls  <- gsub("^collection-", "", gsub("\\.txt$", ".html", coll_files))
    coll_titles <- sapply(coll_files, make_toc_title)
    nav_links <- c(
        '<a href="index.html">All songs</a>',
        paste0('<a href="', coll_htmls, '">', coll_titles, '</a>')
    )
    toc_nav <- paste(nav_links, collapse="\n    ")

    # --- TOC_META: which collection .txt backs this page ---
    if(is.character(collection_src) && length(collection_src) == 1 &&
       grepl("^collection-", basename(collection_src))){
        coll_file_json <- pst('"', basename(collection_src), '"')
    } else {
        coll_file_json <- "null"
    }
    toc_meta_json <- pst('{"collectionFile":', coll_file_json, '}')

    # --- Page title ---
    page_title <- if(outfile == "index.html") "All songs" else make_toc_title(outfile)

    # --- Replace placeholders ---
    val <- gsub("TocNavLinks",  toc_nav,       val, fixed=TRUE)
    val <- gsub("TocMetaJSON",  toc_meta_json, val, fixed=TRUE)
    val <- gsub("PageTitle",    page_title,    val, fixed=TRUE)

    if(writeit){
        write(val, pst("output_html/", outfile))
    }
    invisible(val)
}
