#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 audit.py
command -v nasm >/dev/null 2>&1 || { echo 'ERROR: NASM is required.' >&2; exit 1; }
nasm -f bin -Wall -Werror intro256.asm -o UBER256.COM
nasm -f bin -Wall -Werror showcase.asm -o UBERSHOW.COM
size=$(wc -c < UBER256.COM | tr -d ' ')
printf 'UBER256.COM: %s bytes\n' "$size"
[ "$size" -le 256 ] || { echo 'ERROR: UBER256.COM exceeded 256 bytes' >&2; exit 2; }
printf 'UBERSHOW.COM: %s bytes\n' "$(wc -c < UBERSHOW.COM | tr -d ' ')"
python3 audit.py
if command -v sha256sum >/dev/null 2>&1; then sha256sum UBER256.COM UBERSHOW.COM > SHA256SUMS; else shasum -a 256 UBER256.COM UBERSHOW.COM > SHA256SUMS; fi
cat SHA256SUMS
