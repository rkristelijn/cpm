#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
FILE="$ROOT/cpm.toml"

if [[ ! -f "$FILE" ]]; then
  echo "skip: no cpm.toml"
  exit 0
fi

bash "$ROOT/scripts/sort/sortkit.sh" fix --mode cpm-toml --file "$FILE" "${@:2}"
