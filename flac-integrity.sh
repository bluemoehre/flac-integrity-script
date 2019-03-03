#!/bin/bash

# FLAC integrity script
# Copyright 2019 BlueMöhre <bluemoehre@gmx.de>
# https://www.github.com/bluemoehre
# Licensed under GPLv3


shopt -s nullglob # globs will expand to nothing if they don't match
shopt -s globstar # ** will match all files and zero or more directories and subdirectories


# ----- variables -----

CURRENT_SCRIPT=`basename "$0"`
DEFAULT_LOG=.flac_integrity

OPTION_RECURSIVE=false
OPTION_VERBOSE=false
OPTION_LIMIT=0
OPTION_INTERVAL=90
OPTION_LOGFILE=""
WORKING_DIRECTORY=./

file_count=0
check_count=0
error_count=0


# ----- functions -----

function log {
  [ "$OPTION_VERBOSE" = true ] && echo -e $1
}

function show_help {
  echo "Usage:"
  echo "$CURRENT_SCRIPT [<options>] /some/path"
  echo ""
  echo "options:"
  echo "  -i    interval for re-checking files in days (default: ${OPTION_INTERVAL})"
  echo "  -r    recursive mode"
  echo "  -l    limit amount of files per run"
  echo "  -o    log file output"
  echo "  -v    verbose mode"
  echo "  -h    help (this output)"
}


# ----- environment checks -----

if [ -z `command -v flac` ]
then
  echo "No FLAC command available in current environment."
  echo "Please check if FLAC binaries have been installed and added to ENV correctly!"
  exit 1
fi


# ----- handle options & arguments -----

while getopts ":hi:rl:o:v" OPTION; do
  case $OPTION in
    i)
      OPTION_INTERVAL=$OPTARG
      ;;
    r)
      OPTION_RECURSIVE=true
      ;;
    l)
      OPTION_LIMIT=$OPTARG
      ;;
    o)
      OPTION_LOGFILE=$OPTARG
      ;;
    v)
      OPTION_VERBOSE=true
      ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1)) # remove parsed options and args from $@ list

# use provided directory
if [ -n "$1" ]; then
  WORKING_DIRECTORY=$1
fi

log "Checking access to \"$WORKING_DIRECTORY\""
if [ ! -d "$WORKING_DIRECTORY" ]; then
  echo "Directory \"$WORKING_DIRECTORY\" does not exist."
  exit 1
fi

log "Switching to \"$WORKING_DIRECTORY\""
cd "$WORKING_DIRECTORY"

if [ "$OPTION_RECURSIVE" = true ]; then
  files=(./**/*.flac)
else
  files=(*.flac)
fi


# ----- setup logging -----

if [ -n "$OPTION_LOGFILE" ]; then
  logfile="$OPTION_LOGFILE"
  logfile_tmp="$OPTION_LOGFILE"'.tmp'
else
  logfile="$WORKING_DIRECTORY/$DEFAULT_LOG"
  logfile_tmp="$WORKING_DIRECTORY/$DEFAULT_LOG"'.tmp'
fi
log "Using logfile \"$logfile\""

if [ -z "$logfile" ]; then
  echo "No valid logfile specified"
  exit 1
fi

if [ ! -f "$logfile" ]; then
  [ "$OPTION_VERBOSE" = true ] && echo "Logfile wasn't present and therefore created"
  touch $logfile
fi


# ----- loop all found files -----

for file in "${files[@]}"; do
  if (( $OPTION_LIMIT > 0 && $check_count >= $OPTION_LIMIT )); then
    break;
  fi

  log ""
  log "\e[1m$file\e[0m"

  file_count=$((file_count + 1))
  recheck=true
  logline=$(grep "$file" "$logfile")

  if [ -n "$logline" ]; then
    log "File is present in log"

    # prepare delimiters for autosplitting
    logline=$(echo $logline | sed -e 's/ - /➝/' -e 's/ => /➝/')

    # convert log line to array
    IFS='➝' read -r -a logentry <<< "$logline"

    status="${logentry[2]}"
    age=$(( (`date -d "00:00" +%s` - `date -d ${logentry[0]} +%s`) / (24 * 3600) ))

    if (( age <= $OPTION_INTERVAL )); then
      log "File was already checked $age days ago"
      recheck=false
    else
      grep -v "$logline" "$logfile" > "$logfile_tmp" && mv "$logfile_tmp" "$logfile"
    fi
  fi

  if [ "$recheck" = true ]; then
    log "File is being (re-)checked"
    check_count=$((check_count + 1))
    status=$(flac -wst "$file" 2>/dev/null && echo "OK" || echo "ERROR");
    echo "`date +%Y-%m-%d` - \"$file\" => $status" >> "$logfile"
  fi

  if [ "$status" = "ERROR" ]; then
    log "\e[91mFile contains errors!\e[0m"
    error_count=$((error_count + 1))
  else
    log "\e[92mFile is ok\e[0m"
  fi
done


# ----- display final report -----

echo ""
echo "Statistics:"
echo ""
echo -e "  \e[1m${file_count}\e[0m files checked in total"
echo -e "  \e[1m${check_count}\e[0m files checked this time"
if (( $error_count > 0 )); then
  echo -e "  \e[91m${error_count} files with errors\e[0m"
else
  echo -e "  \e[92m${error_count} files with errors\e[0m"
fi
echo ""

exit $error_counts