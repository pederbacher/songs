postfix <- function(setups){
    gsub("\\.R","",unlist(lapply(strsplit(setups,"_"), function(x){x[2]})))
}
