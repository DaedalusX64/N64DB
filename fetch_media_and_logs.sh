#!/bin/bash

##TODO
# Extension should be an array

TARGET=(./daedalus --fullscreen) # Boot Target

EXTENSION="*.z64" # Needs to be an array to target multiple types
SLEEP_TIME=10 # Amount of time to wait before capturing primarily to avoid black screens and boot logos

mkdir -p Output/Video Output/Log Output/Image Output/Temp

# if temp directory exists, purge contents
if [ -d "Output/Temp" ]; then
    rm -r Output/Temp/*
fi


# Copy OBS Profile, if you have a profile named Jabberwocky then that's your problem :P
cp -R Jabberwocky $HOME/.var/app/com.obsproject.Studio/config/obs-studio/basic/profiles/ 

PROFILE_NAME="Jabberwocky"
NEW_PATH="$PWD/Output/Temp"

if [[ "$(uname)" == "Darwin" ]]; then
    PROFILE_BASE="$HOME/Library/Application Support/obs-studio/basic/profiles"
    PROFILE_INI="$PROFILE_BASE/$PROFILE_NAME/basic.ini"
else
    PROFILE_BASE="$HOME/.var/app/com.obsproject.Studio/config/obs-studio/basic/profiles"
    PROFILE_INI="$PROFILE_BASE/$PROFILE_NAME/basic.ini"
fi

# Create profile only if it doesn't already exist
# if [ ! -f "$PROFILE_INI" ]; then
    echo "Creating OBS profile at $PROFILE_INI"
    cp -R "Jabberwocky" "$PROFILE_BASE"

    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|=CHANGEME$|=$NEW_PATH|" "$PROFILE_INI"
    else
        sed -i "s|=CHANGEME$|=$NEW_PATH|" "$PROFILE_INI"
    fi
# fi


# Start OBS once, no need to kill (You need a scene called Jabberwocky)
if [[ $(uname -s) == "Linux" ]]; then
    OUTPUT_DIR="$PWD/Output/Temp/"
    flatpak run com.obsproject.Studio --minimize-to-tray --disable-shutdown-check --startrecording --profile Jabberwocky &
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
    screencapture -D 1 -v -V 30 -g "Output/Video/$romname.mp4" 
;;
Linux)
    # Run OBS and capture video -- OBS should only be run once
    sleep 30 # makes the video 30 seconds
    file=$(ls -1r $OUTPUT_DIR/*.mkv)
    ffmpeg -y -i "$file" "Output/Video/$romname.webm"
    rm -f "$file"
;;
default)
echo "Screen Capture software is needed"
;;
esac
kill -9 "$pid" # Terminate emulator process  

done
