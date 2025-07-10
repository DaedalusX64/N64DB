# Nintendo 64 Database


This is a database that converts a list of roms into a scalable sqlite3 database and outputting results into a HTML file.


Files:


generate_romdb.sh - Generates the ROM sqlite database from the "Roms Directory"

fetch_media_and_logs.sh - Grabs 30 seconds of video after 10 seconds using ffmpeg, along with log files and a screenshot. Stored in in a file generated from the shasum of the rom with either the extension .txt, .png or .webm.

This can take a while, can fail and can cause large text dumps.