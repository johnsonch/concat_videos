#!/bin/bash

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <arena_name> <team_name>"
    exit 1
fi

# Assign arguments to variables
ARENA_NAME=$1
TEAM_NAME=$2

# Get the current working directory
CURRENT_DIR=$(pwd)

# Find matching files in the current directory and generate file_list.txt
ls "${CURRENT_DIR}/${ARENA_NAME}"_*.mp4 2>/dev/null | awk '{print "file '\''" $0 "'\''"}' > "${CURRENT_DIR}/file_list.txt"

# Check if file_list.txt is empty
if [ ! -s "${CURRENT_DIR}/file_list.txt" ]; then
    echo "No matching files found for arena name '${ARENA_NAME}' in ${CURRENT_DIR}."
    rm -f "${CURRENT_DIR}/file_list.txt"
    exit 1
fi

# Extract the date stamp from the first matching file
DATE_STAMP=$(ls "${CURRENT_DIR}/${ARENA_NAME}"_*.mp4 | head -n 1 | sed -E 's/.*_([0-9]{4}-[0-9]{2}-[0-9]{2})T.*/\1/')

# Generate the output file name
OUTPUT_FILE="${CURRENT_DIR}/${DATE_STAMP}_${TEAM_NAME}.mp4"

# Run FFmpeg to concatenate the videos
ffmpeg -f concat -safe 0 -i "${CURRENT_DIR}/file_list.txt" -c copy "${OUTPUT_FILE}"

# Cleanup
rm "${CURRENT_DIR}/file_list.txt"

echo "Videos concatenated into: ${OUTPUT_FILE}"

