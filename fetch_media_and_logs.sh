#!/bin/bash

##TODO
# Extension should be an array

TARGET=(./daedalus --fullscreen) # Boot Target

EXTENSION="*.z64" # Needs to be an array to target multiple types
SLEEP_TIME=10 # Amount of time to wait before capturing primarily to avoid black screens and boot logos

mkdir -p Output/Video Output/Log Output/Image

# Start OBS once, no need to kill (You need a scene called Capture)
if [[ $(uname -s) == "Linux" ]]; then
    flatpack run com.obsproject.Studio --minimize-to-tray --disable-shutdown-check --startrecording --profile Capture &
fi

for rom in Roms/$EXTENSION; do
    # Generate the debug text document, get the process ID and sleep for 10 seconds
    romname=$(shasum "$rom" | cut -f1 -d " ")
    touch "Output/Log/$romname.txt" 
    "${TARGET[@]}" "$rom" > "Output/Log/$romname.txt" &
    pid=$!
    sleep $SLEEP_TIME

case $(uname -s) in
Darwin)
    screencapture -D 1 "Output/Image/$romname.png" 
    screencapture -D 1 -v -V 30 -g "Test/$romname.mp4" 
;;
Linux)
    # Run OBS and capture video -- OBS should only be run once
    sleep 5
    sleep 27 # makes the video 30 seconds
    file=$(ls -1re $HOME/*.mkv)
    ffmpeg -y -i "$file" "Output/Video/$romname.webm"
    rm -f "$file"
;;
default)
echo "Screen Capture software is needed"
;;
esac
kill -9 "$pid" # Terminate emulator process  

done
