################################
makeit_pdfs <- function(L, collection, trsteps=0:11, clean=TRUE, pdfname=NA, pdfcopy=TRUE, pdfopen=TRUE){
  nms <- getnm(basename(collection))
  dirs <- pst(dirname(collection))
  #
  if(length(trsteps) == 1){
    # Only transpose once, no links, change of titles etc.
    if(trsteps == 0){
      L <- L[collection]
    }else{
      L <- L[pst(dirs,"Transposed/",nms,"_trans",trsteps,".txt")]
    }
  }else{
    # Multiple transpose steps (make links etc. is default)
    tmp <- NULL
    #for(i in 1:length(nms)){
    #  tmp <- c(tmp,pst(dirs[i],"Transposed/",nms[i],"_trans",trsteps,".txt"))
    #}
    for(trstep in trsteps){
      tmp <- c(tmp,pst(dirs,"Transposed/",nms,"_trans",trstep,".txt"))
    }
    L <- L[tmp]
    # Make links for jumping between transposed versions
    L <- lapply(names(L), function(nm){
      trstep <- as.integer(gsub("\\.txt", "", strsplit(nm, "trans")[[1]][2]))
      x <- L[[nm]]
      ii <- grep("\\\\subsection\\*\\{", x)
      # Now insert links for transpose
      label <- regmatches(x[ii], regexec("\\\\subsection\\*\\{(.*?)\\}", x[ii], perl = TRUE))[[1]][2]
      label <- pst(gsub(" ","",label), "tr")
      x[ii] <- pst(x[ii],"\\hypertarget{",label,trstep,"}{}")
      # Then insert the refs
      down <- (trstep-1) %% 12
      up <- (trstep+1) %% 12
      # fontsize: (first number = font size, second = line spacing)
      links <- c("\\begin{textblock*}{3cm}(\\dimexpr\\paperwidth-3cm\\relax,0.8cm)",
                 "{\\fontsize{12}{10}\\selectfont",
                 pst("\\hyperlink{",label,down,"}{DOWN}-",sprintf("%02d",trstep),"-\\hyperlink{",label,up,"}{UPUP}"),
                 "}",
                 "\\end{textblock*}")
      x <- c(x[1:ii], links, x[(ii+1):length(x)])
      # Finally remove the toc lines for the transposed versions
      if(length(grep("trans0\\.", x[1])) == 0){
        x <- x[-grep("addcontentsline\\{toc\\}", x)]
      }
      return(x)
    })
  }

  # Insert link to the first page
  L <- lapply(L, function(x){
    ii <- grep("\\\\subsection\\*\\{", x)
    # fontsize: (first number = font size, second = line spacing)
    links <- c("\\begin{textblock*}{3cm}(\\dimexpr\\paperwidth-3cm\\relax,0.2cm)",
               "{\\fontsize{12}{10}\\selectfont",
               "\\hyperlink{firstpage}{TOC}",
               "}",
               "\\end{textblock*}")
    x <- c(x[1:ii], links, x[(ii+1):length(x)])
  })

  ################################
  x <- "\\documentclass{article}"
  ##
  x <- c(x, "\\usepackage[hypertexnames=false, hidelinks]{hyperref}")
  x <- c(x, "\\usepackage[absolute,overlay]{textpos}")
  ## Geometry
  x <- c(x,pst("\\usepackage[",
               "paperwidth=",width,"cm,",
               "paperheight=",height,"cm,",
               "left=",left,"cm,",
               "right=",right,"cm,",
               "top=",top,"cm,",
               "bottom=",bottom,"cm","]{geometry}"))
  ## Packages used later
  x <- c(x,"\\usepackage{pdflscape}","\\usepackage{multicol}","\\usepackage{setspace}")
  ## Set indent
  x <- c(x,"\\setlength\\parindent{0pt}")
  ## Set font
  tmp <- list(courier=c("\\usepackage{courier}","\\renewcommand{\\familydefault}{\\ttdefault}"),
              helvet=c("\\usepackage{helvet}","\\renewcommand{\\familydefault}{\\sfdefault}"),
              lmodern=c("\\usepackage{lmodern}","\\renewcommand{\\familydefault}{\\ttdefault}"),
              courierpcr=c("\\usepackage{courier}","\\renewcommand{\\ttdefault}{pcr}"),
              avant=c("\\usepackage{avant}","\\renewcommand{\\familydefault}{\\sfdefault}"),
              lmtt=c("\\usepackage{lmodern}","\\renewcommand{\\familydefault}{lmtt}"))
  x <- c(x, tmp[[font[1]]])
  ## Colors
  x <- c(x,"\\usepackage{xcolor}","\\definecolor{Amber}{rgb}{0.8, 0.29, 0.0}")
  #
  if(!pagenumbers){
    x <- c(x, "\\pagenumbering{gobble}")
  }
  ## Begin
  x <- c(x,"\\begin{document}")
  # Link to first page
  x <- c(x, "\\hypertarget{firstpage}{}")
  ## Environments
  if(toc){
    x <- c(x,pst("\\begin{multicols*}{",toccolumns,"}"),"\\raggedcolumns","\\tableofcontents","\\end{multicols*}","\\newpage")
  }
  ################################
  ## # Remove tags
  ## L <- lapply(L, function(x){
  ##   x <- gsub("chordline", "", x)
  ##   x <- trimws(x, which="right")
  ##   return(x)
  ## })
  # Remove the song names
  L <- lapply(L, function(x){ return(x[-1]) })
  ## Columns
  # Insert columns globally
  if(columns > 1){
    begincols <- c(pst("\\begin{multicols*}{",columns,"}"),"\\raggedcolumns")
    x <- c(x, begincols)
    # Find songs with columns specified
    L <- lapply(L, function(y){
      if(length(grep("\\\\begin\\{multicols\\*\\}", y)) > 0){
        y <- c("\\end{multicols*}",y,begincols)
      }
      return(y)
    })
  }
  # Pop together the songs  
  x <- c(x, unlist(L))
  ################################
  if(columns > 1){
    # Songs with inserted single columns
    iseq <- grep("XXbeginsinglecolumnXX", x)
    if(length(iseq) > 0){
      for(i in iseq){
        x[i] <- "\\end{multicols*}"
      }
    }
    # Songs with inserted single columns
    iseq <- grep("XXendsinglecolumnXX", x)
    if(length(iseq) > 0){
      for(i in iseq){
        if(x[i+1] == "\\newpage"){
          # Flip the newpage line
          x[i:(i+1)] <- x[(i+1):i]
          i <- i+1
        }
        x <- c(x[1:(i-1)], pst("\\begin{multicols*}{",columns,"}\\raggedcolumns") ,x[(i+1):length(x)])
      }
    }
  }else{
    # Songs with inserted single columns
    irm <- grep("XXbeginsinglecolumnXX|XXendsinglecolumnXX", x)
    if(length(irm)){ x <- x[-irm] }
  }
  ################################
  if(columns > 1){
    x <- c(x,"\\end{multicols*}")
  }
  ################################
  x <- c(x,"\\end{document}")
  ################################
  write(x,"tmp.txt")
  knit("tmp.txt")
  system("pdflatex tmp.tex")
  system("pdflatex tmp.tex")

  dir.create("output/songspdf", showWarnings = FALSE)
  if(!is.na(pdfname) & pdfcopy){
    system(pst("cp tmp.pdf output/songspdf/",pdfname))
  }

  if(pdfopen){
    system(pst("evince output/songspdf/",pdfname," &"))
  }    

  
  ################################
  # Clean
  if(clean){
    filerm <- dir(pattern=c(pst("\\.tex$|\\.aux$|\\.log$|tmp\\.txt$|tmp\\.toc|\\.out$|tmp\\.out$")))
    file.remove(filerm)
  }
}
