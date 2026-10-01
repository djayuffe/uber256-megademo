#!/bin/sh
set -eu
command -v dosbox >/dev/null 2>&1 || { echo 'ERROR: DOSBox is required.' >&2; exit 1; }
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dosbox -c "mount c $DIR" -c "c:" -c "UBER256.COM"
