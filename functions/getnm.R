getnm <- function(x){
    val <- strsplit(basename(x), "\\.")[[1]]
    pst(val[-length(val)], collapse=".")
}
