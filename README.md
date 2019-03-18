FLAC integrity script
========

This bash script scans your FLAC music archives for corruption.
It supports periodical, partial checks of the files via cron,
similar to scrubbing of software raids.
It provides a detailed report about the condition of your music library.

In the background it uses a log file to track which files have already been checked.
When a file hasn't been checked for the given amount of days it will get re-checked.

Usage
-----
```bash
flac-integrity.sh [<options>] <directory>
```

Options
-----
- **`-f`** &#8195; force re-check of erroneous files
- **`-F`** &#8195; force re-check of all files
- **`-i`** &#8195; interval for re-checking files in days *(default: 90)*
- **`-l`** &#8195; limit amount of files per run
- **`-o`** &#8195; log file output *(default: `<path>/.flac-integrity`)*
- **`-r`** &#8195; recursive mode
- **`-v`** &#8195; verbose mode
- **`-h`** &#8195; help

Examples
--------

Analyze 100 FLAC files within `/media/audio/flac` and show all details.
```bash
flac-integrity.sh -rv -l 100 /media/audio/flac
```
