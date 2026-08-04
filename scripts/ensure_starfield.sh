#!/usr/bin/env bash
# One-shot: make sure Widgets/Globe3D/RealStarField.js exists before
# quickshell parses AssemblyGlobeView.qml's static `import "RealStarField.js"`
#
# The generated JS + its ~34MB source CSV are cached under
# $XDG_CACHE_HOME/zesis/starfield/.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$repo_root/Widgets/Globe3D/RealStarField.js"

if [ -e "$target" ]; then
    exit 0
fi

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zesis/starfield"
mkdir -p "$cache_dir"
csv="$cache_dir/hygdata_v41.csv"
js="$cache_dir/RealStarField.js"

if [ ! -e "$js" ]; then
    if [ ! -e "$csv" ]; then
        echo "ensure_starfield: downloading HYG catalog (one-time, ~34MB)..." >&2
        curl -sL "https://raw.githubusercontent.com/astronexus/HYG-Database/main/hyg/CURRENT/hygdata_v41.csv" -o "$csv.tmp"
        mv "$csv.tmp" "$csv"
    fi
    echo "ensure_starfield: generating RealStarField.js..." >&2
    python3 "$repo_root/scripts/build_starfield.py" "$csv" "$js"
fi

ln -sf "$js" "$target"
