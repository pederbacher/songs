################################
rm(list=ls())
pst <- paste0
sapply(dir("functions/", full.names=TRUE), source)
unlink("cache", recursive=TRUE)
dir.create("cache")
# Go
songs <- process_songs()
makeit_html(songs)
################################


################################################################
# Write the index
html_make_index()    
html_make_index("songs/collection-primabacher_2026.txt")
html_make_index("songs/collection-roskilde_2026.txt")
html_make_index("songs/collection-bluebird.txt")
html_make_index("songs/collection-dynsys.txt")
################################################################


################################################################
# Copy asset files
file.copy("templates/html/styles.css",   "output_html/styles.css",   overwrite=TRUE)
file.copy("templates/html/script.js",    "output_html/script.js",    overwrite=TRUE)
file.copy("templates/html/toc-script.js","output_html/toc-script.js",overwrite=TRUE)
################################################################



################################################################
# Kill any existing server on port 8000, then start a fresh one
# (skipped when triggered via the browser rebuild button)
if(Sys.getenv("SANGE_NO_SERVER_RESTART") != "1"){
    system("fuser -k 8000/tcp 2>/dev/null; true")
    system("python3 server.py 8000 &")
    Sys.sleep(0.5)  # brief pause so server is ready before Firefox opens
    #    system("firefox http://localhost:8000/index.html &")
    system("firefox http://localhost:8000/dynsys.html &")
}
#system(pst("firefox http://localhost:8000/primabacher_2026.html &"))
#system(pst("firefox http://localhost:8000/roskilde_2026.html &"))
# The server stays running in the background after the script finishes, so you can keep testing without
# restarting it. If you ever want to stop it manually: fuser -k 8000/tcp.
################################################################


################################################################
if(FALSE){

    # Commit changes
    system("git pull")
    system("git add .")
    system("git commit -m 'more'")
    system("git push")
    
    # Put online
    unlink("output_git", recursive=TRUE)
    system("git clone git@github.com:pederbacher/songs.git output_git")
    system("cp output_html/* output_git/")
    system("git -C output_git status")
    system("git -C output_git add .")
    system("git -C output_git commit -m 'more'")
    system("git -C output_git push")

}
################################################################
