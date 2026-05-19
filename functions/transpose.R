transpose <- function(L, trstep, outfolder){

  rotate_vec <- function(x, k) {
    n <- length(x)
    if (n == 0) return(x)
    k <- k %% n  # handle large or negative shifts
    c(x[(k + 1):n], x[1:k])
  }
  for(j in 1:length(L)){
    # Go for it
    x <- L[[j]]
    # Transpose
    if(trstep != 0){
      # Set up
      tones  <-  c("C","C#","D","D#","E","F","F#","G","G#","A","A#","B")
      symbol <-  c("I","JJ","K","LL","M","N","§§","P","QQ","R","££","T")
      tonesB  <- c("C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B")
      symbolB <- c("U","VV","X","__","&","¤","<<","ZZ","==","@","~~",";")
      # Transpose
      symbolrotated <- rotate_vec(symbol, trstep)
      symbolBrotated <- rotate_vec(symbolB, trstep)
      # Find the chord lines
      i <- grep("chordline", x)
      x[i] <- gsub("chordline", "", x[i])
      x[i] <- trimws(x[i], which="right") 
      # Now replace
      for(ii in 1:length(tones)){
        # Replace 'letter' only if it is NOT followed by 'b'
        x[i] <- gsub(pst(tones[ii],"(?![b#])"), symbolrotated[ii], x[i], perl = TRUE)
        # Replace 'letter' only if it is NOT followed by '#'
        x[i] <- gsub(pst(tonesB[ii],"(?![b#])"), symbolBrotated[ii], x[i], perl = TRUE)
      }
      # Replace back with the non-rotated
      # To compensate for length differences e.g. "A#" with "A". Then put marks later where space must be added or removed
      # Here put length changed marks AND ROTATE BACK the lens to put the marks in the right place
      lens <- rotate_vec(nchar(symbolrotated) - nchar(symbol), -trstep)
      lensB <- rotate_vec(nchar(symbolBrotated) - nchar(symbolB), -trstep)
      tones[lens > 0] <- pst(tones[lens > 0],"Wrm")
      tones[lens < 0] <- pst(tones[lens < 0],"Wsp")
      tonesB[lensB > 0] <- pst(tonesB[lensB > 0],"Wrm")
      tonesB[lensB < 0] <- pst(tonesB[lensB < 0],"Wsp")
      # Do the replacing back again
      for(ii in 1:length(tones)){
        x[i] <- gsub(symbol[ii], tones[ii], x[i], perl = TRUE)
        x[i] <- gsub(symbolB[ii], tonesB[ii], x[i], perl = TRUE)
      }
#      if(length(grep("F#",x[i]))) browser()
      # Remove space where marked
      x[i] <- unlist(lapply(strsplit(x[i],"Wrm"), function(y){
        if(length(y) > 1){
          # Remove only one whitespace from each run of multiple whitespaces, while leaving single spaces untouched.
          y[-1] <- sub(" ( +)", "\\1", y[-1])
          y <- pst(y, collapse="")
        }
        return(y)
      }))
      # Add space
      x[i] <- unlist(lapply(strsplit(x[i],"Wsp"), function(y){
        if(length(y) > 1){
          pos <- as.integer(regexpr("\\s", y[-1]))
          nspc <- cumsum(pos<0)
          nspc[pos<0] <- 0
          for(ii in 1:length(pos)){
            y[ii+1] <- pst(substr(y[ii+1],1,pos[ii]-1), strrep(" ",nspc[ii]), substr(y[ii+1],pos[ii],nchar(y[ii+1])))
          }
          y <- pst(y, collapse="")
        }
        return(y)
      }))
      x[i] <- pst(x[i]," chordline")
    }
    # Finally, write it
    nm <- gsub("\\.txt", pst("_trans",trstep,".txt"), basename(names(L)[j]))
    write(x, pst(outfolder,"/",nm))
  }
  return()
}
