################################
add <- function(nm, newlinesbefore=NULL, insertbefore=NULL, landscape=FALSE, left=NULL, right=NULL, top=NULL, bottom=NULL, columns=NULL, ...){
  # Stop if the song is not included
  # Check dots and set elements as local variables
  dots <- list(...)
  if(length(dots) > 0){
    # Set the variables given in dots
    for(i in 1:length(dots)){
      eval(parse(text=pst(names(dots)[i]," <- ",dots[[i]])))
    }
  }
  ################################
  # Read the file
  print(nm)
  x <- scan(nm, what="character", sep="\n", blank.lines.skip=FALSE)
  # Identify chord lines
  i <- grep("chordline", x)
  x[i] <- gsub("chordline", "", x[i])
  x[i] <- trimws(x[i], which="right")
  #
  if(length(i) > 0){
    # Process chord lines
    if(chords){
      # The vspace comes before the text on the line no matter what
      x[i-1] <- pst("\\vspace{",vspace,"ex}",x[i-1])
      #    x[i] <- pst("{\\fontsize{",fontsizechords,"pt}{",fontsizechords,"pt}\\selectfont","\\vspace{-",vspace,"ex}\\textcolor{",color,"}{",x[i],"}}")
      x[i] <- pst("\\vspace{-",vspace,"ex}\\textcolor{",color,"}{",x[i],"}")
      x <- gsub("\\#", "\\\\#", x)
    }else{
      x <- x[-i]   
    }
  }  
  ################################
  # Insert something before patterns
  if(length(insertbefore) > 0){
    for(i in 1:length(insertbefore)){
      ilines <- grep(names(insertbefore)[i], x)
      x[ilines-1] <- pst(x[ilines-1],insertbefore[i])
    }
  }
  ################################
  # Insert extra newlines before patterns
  if(length(newlinesbefore) > 0){
    for(i in 1:length(newlinesbefore)){
      ilines <- grep(names(newlinesbefore)[i], x)
      if(length(ilines) > 1){
        tmp <- cumsum(rep(newlinesbefore[i], length(ilines)))
        ilines[-1] <- ilines[-1] + tmp[-length(tmp)]
      }
      for(ii in ilines){
        x <- c(x[1:(ii-1)], rep("\\newline",newlinesbefore[i]), x[ii:length(x)])
      }
    }
  }
  ################################
  # Find the strums and remove if specified
  istrum <- grep("\\|-.*-\\|", x)
  istart <- grep("strum[s]?\\]$", x, ignore.case=TRUE)
  if(length(istart) > 0){
    iend <- rep(NA,length(istart))
    for(i in 1:length(istart)){
      tmp <- grep("\\]$", x[(istart[i]+1):length(x)])
      if(length(tmp) > 0){
        iend[i] <- tmp[1]
      }else{
        iend[i] <- length(x)
      }
      istrum <- c(istrum, (istart[i]+1):iend[i])
    }
    istrum <- sort(unique(istrum))
  }
  # Process it
  if(!strums){
    # [strum] and remove to next []
    if(length(istrum) > 0){ x <- x[-istrum] }
  }else{
    # Find strums and mark
    x[istrum] <- pst("{\\fontsize{",fontsizestrum,"pt}{",fontsizestrum,"pt}\\selectfont","\\textcolor{",color,"}{",x[istrum],"}}")
  }
  ################################
  # Find the headers and remove if specified
  if(!headers){
    irm <- grep("\\]$", x)
    # Any to remove?
    if(length(irm) > 0){
      # Move the vspace to the previous line
      x[irm-1] <- pst("\\vspace{",vspace,"ex}",x[irm-1])
      # Remove the lines
      x <- x[-irm]
    }
  }
  ################################
  # Insert "\ " before blank spaces
  x <- gsub(" ", "\\\\ ", x)
  ################################
  # Insert newlines at each line
  iseq <- 1:(length(x)-1)
  # Not at commands
  irm <- grep("multicols\\}|landscape\\}|section\\}|alltt\\}|\\\\newpage|\\\\newline", x[iseq])
  if(length(irm)>0){ iseq <- iseq[-irm] }
  x[iseq] <- pst(x[iseq],"\\newline")
  ################################
  # Title from filename and as section
  # Remove empty lines right after section (no line to end in latex)
  xxmod <- gsub("\\\\vspace\\{.*ex\\}|\\\\newline$", "", x)
  irm <- seq_len(match(TRUE, nzchar(xxmod)) - 1)
  if(length(irm) > 0){
    x <- x[-irm]
  }
  #
  title <- trimws(gsub("trans\\d+","",gsub("_"," ",gsub("-:-"," - ",getnm(nm)))))
  x <- c(pst("\\subsection*{",title,"}"),
         pst("\\addcontentsline{toc}{section}{",title,"}"),
         x)
  ################################
  # Set font size and line space
  x <- c(pst("{\\fontsize{",fontsize,"pt}{",fontsize,"pt}\\selectfont"),x,"}")
  x <- c(pst("\\begin{spacing}{",linespace,"}"),x,"\\end{spacing}")
  ################################
  if(!is.null(c(left,right,top,bottom))){
    tmp <- "\\newgeometry{"
    if(landscape){
      if(!is.null(left)){ tmp <- pst(tmp,"left=",top,"cm,") }
      if(!is.null(right)){ tmp <- pst(tmp,"rigth=",bottom,"cm,") }
      if(!is.null(top)){ tmp <- pst(tmp,"top=",right,"cm,") }
      if(!is.null(bottom)){ tmp <- pst(tmp,"bottom=",left,"cm,") }
    }else{
      if(!is.null(left)){ tmp <- pst(tmp,"left=",left,"cm,") }
      if(!is.null(right)){ tmp <- pst(tmp,"rigth=",right,"cm,") }
      if(!is.null(top)){ tmp <- pst(tmp,"top=",top,"cm,") }
      if(!is.null(bottom)){ tmp <- pst(tmp,"bottom=",bottom,"cm,") }
    }
    tmp <- substr(tmp, 1, nchar(tmp)-1)
    tmp <- c(pst(tmp,"}"))
    x <- c(tmp, x, "\\restoregeometry")
  }
  ################################
  # Wrap in landscape
  if(landscape){
    x <- c("\\begin{landscape}",x,"\\end{landscape}")
  }
  ################################
  # Wrap in multicols
  if(!is.null(columns)){
    if(columns == 1){
      if(newpage){
        x <- c("XXbeginsinglecolumnXX","\\newpage",x,"XXendsinglecolumnXX")
      }else{
        x <- c("XXbeginsinglecolumnXX",x,"XXendsinglecolumnXX")
      }
    }else{
      x <- c(pst("\\begin{multicols*}{",columns,"}"),"\\raggedcolumns",x,"\\end{multicols*}")
      if(newpage){
        x <- c("\\newpage",x)
      }
    }
  }else{
    if(newpage){
      x <- c("\\newpage",x)
    }
  }
  ################################
  x <- gsub("–","-",x)
  ################################
  return(c(nm,x))
}
