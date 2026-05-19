read_from_google_drive <- function(nm, folder="cache/downloads"){
  fileid <- switch(nm, SangeMedAkkorder="1xXF6eBrnFyamT_i4dqeVzawb6V4bqfR6LrOOVXtn2yA",
                   SkammensVogn="1zvm6_Gbm3v5NEKd8PusnAdDjfTFwr8Qq9DiNp7njYu0")

  # Download
  system(pst("gdown https://drive.google.com/uc?id=",fileid))
  # Convert
  system(pst("docx2txt ",nm,".docx ",nm,".txt"))
  #system("docx2txt SangeMedAkkorder.docx SangeMedAkkorder.txt")
  #system("pandoc SangeMedAkkorder.docx -t plain -o SangeMedAkkorder.txt")
  #system(pst("libreoffice --convert-to txt ",nm,".docx"))
  x <- scan(pst(nm,".txt"), what="character", sep="\n", blank.lines.skip=FALSE)

  # Remove repeated empty lines
  x <- gsub("^[ ]*$", "", x)
  tmp <- which(x == "")
  x <- x[-(tmp[diff(tmp) == 1] + 1)]

  # Remove dash lines
  x <- x[-grep("^--------------------------------------------------------------------------------$", x)]

  # Find lines that are the 1. headers, start with "@"
  i1 <- grep("^@", x)
  h1 <- gsub("@", "", x[i1])
  i2 <- grep("^_", x)
  h2 <- gsub("_", "", x[i2])
  unlink(pst(folder,"/",nm), recursive=TRUE)
  dir.create(pst(folder,"/",nm), recursive=TRUE)

  grp <- cut(i2, c(i1,Inf), labels=FALSE)
  for(i in 1:(length(i2)-1)){
    # Get the song name and the song text
    songnm <- gsub(" ","_",pst(nm,"/",h1[grp[i]],"-:-",h2[i],".txt"))
    song <- x[(i2[i]+1):(i2[i+1]-1)]
    # Remove first line if same as title
    if(tolower(h2[i]) == tolower(song[1])){ song <- song[-1] }
    # Remove if artist is there in the end
    iend <- grep("@", song)
    if(length(iend) > 0){
      song <- song[-(iend[1]:length(song))]
    }
    # Remove empty lines in start and end
    if(song[1] == ""){ song <- song[-1] }
    if(song[length(song)] == ""){ song <- song[-length(song)] }
    # Write it
    write(song, pst(folder,"/",songnm))
  }

  # Clean
  file.remove(pst(nm,".txt"), pst(nm,".docx"))
}
