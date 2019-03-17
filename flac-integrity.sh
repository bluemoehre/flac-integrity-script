#!/bin/bash

# FLAC integrity script
# Copyright 2019 BlueMöhre <bluemoehre@gmx.de>
# https://www.github.com/bluemoehre
# Licensed under GPLv3


shopt -s nullglob # globs will expand to nothing if they don't match
shopt -s globstar # ** will match all files and zero or more directories and subdirectories


# ----- variables -----

CURRENT_DIR=$(pwd)
CURRENT_SCRIPT=$(basename "$0")
DEFAULT_LOG=.flac_integrity

OPTION_FORCE_ALL=false
OPTION_FORCE_ERRONEOUS=false
OPTION_INTERVAL=90
OPTION_LIMIT=0
OPTION_LOGFILE=""
OPTION_RECURSIVE=false
OPTION_VERBOSE=false
WORKING_DIRECTORY=.

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
  echo "  -f    force check of erroneous files"
  echo "  -F    force check of all files"
  echo "  -i    interval for re-checking files in days (default: ${OPTION_INTERVAL})"
  echo "  -l    limit amount of files per run"
  echo "  -o    log file output"
  echo "  -r    recursive mode"
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

while getopts ":hfFi:l:o:rv" OPTION; do
  case $OPTION in
    f)
      OPTION_FORCE_ERRONEOUS=true
      ;;
    F)
      OPTION_FORCE_ALL=true
      ;;
    i)
      OPTION_INTERVAL=$OPTARG
      ;;
    l)
      OPTION_LIMIT=$OPTARG
      ;;
    o)
      OPTION_LOGFILE=$OPTARG
      ;;
    r)
      OPTION_RECURSIVE=true
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


# ----- setup logging -----

if [ -n "$OPTION_LOGFILE" ]; then
  logfile=$(readlink -m "$OPTION_LOGFILE")
  logfile_tmp="$OPTION_LOGFILE"'.tmp'
else
  logfile=$(readlink -m "$WORKING_DIRECTORY/$DEFAULT_LOG")
  logfile_tmp="$WORKING_DIRECTORY/$DEFAULT_LOG"'.tmp'
fi
log "Using logfile \"$logfile\""

if [ -z "$logfile" ]; then
  echo "No valid logfile specified"
  exit 1
fi

if [ ! -f "$logfile" ]; then
  [ "$OPTION_VERBOSE" = true ] && echo "Logfile wasn't present and therefore created"
  touch "$logfile" || exit 1
fi


# ----- retrieve file list -----

# use provided directory
if [ -n "$1" ]; then
  WORKING_DIRECTORY=$(readlink -m "$1")
fi

log "Checking access to \"$WORKING_DIRECTORY\""
if [ ! -d "$WORKING_DIRECTORY" ]; then
  echo "Directory \"$WORKING_DIRECTORY\" does not exist."
  exit 1
fi

log "Retrieving file list"
if [ "$OPTION_RECURSIVE" = true ]; then
  files=("$WORKING_DIRECTORY"/**/*.flac)
else
  files=("$WORKING_DIRECTORY"/*.flac)
fi


# ----- loop all found files -----

for file in "${files[@]}"; do
  if (( $OPTION_LIMIT > 0 && $check_count >= $OPTION_LIMIT )); then
    break;
  fi

  log ""
  log "\e[1m$file\e[0m"

  file_count=$((file_count + 1))
  do_check=true
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
      if [ "$OPTION_FORCE_ALL" = true ] || ([ "$OPTION_FORCE_ERRONEOUS" = true ] && [ "$status" = "ERROR" ]); then
        log "Forced check"
      else
        do_check=false
      fi
    else
      grep -v "$logline" "$logfile" > "$logfile_tmp" && mv "$logfile_tmp" "$logfile"
    fi
  fi

  if [ "$do_check" = true ]; then
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