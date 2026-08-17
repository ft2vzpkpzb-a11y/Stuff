#!/usr/bin/env bash
#
# Traegt deine eigene Bundle-ID, App-Group und Team-ID ins Projekt ein.
# Muss einmal vor dem ersten `xcodegen generate` laufen.
#
#   ./configure.sh --bundle dev.deinname.pausenwaechter --team ABCDE12345
#
# Die App-Group wird aus der Bundle-ID abgeleitet ("group." davor), kann
# aber mit --group ueberschrieben werden. Die Team-ID findest du unter
# https://developer.apple.com/account -> Membership.

set -euo pipefail

cd "$(dirname "$0")"

OLD_BUNDLE="dev.pausenwaechter.app"
OLD_PREFIX="dev.pausenwaechter"
OLD_GROUP="group.dev.pausenwaechter"

NEW_BUNDLE=""
NEW_GROUP=""
NEW_TEAM=""

usage() {
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle) NEW_BUNDLE="${2:-}"; shift 2 ;;
        --group)  NEW_GROUP="${2:-}";  shift 2 ;;
        --team)   NEW_TEAM="${2:-}";   shift 2 ;;
        -h|--help) usage 0 ;;
        *) echo "Unbekannte Option: $1" >&2; usage 1 ;;
    esac
done

if [[ -z "$NEW_BUNDLE" ]]; then
    echo "Fehler: --bundle fehlt." >&2
    usage 1
fi

# Bundle-IDs duerfen nur Buchstaben, Ziffern, Punkte und Bindestriche haben.
if ! [[ "$NEW_BUNDLE" =~ ^[A-Za-z0-9.-]+$ ]]; then
    echo "Fehler: '$NEW_BUNDLE' ist keine gueltige Bundle-ID." >&2
    exit 1
fi

if [[ -z "$NEW_GROUP" ]]; then
    NEW_GROUP="group.${NEW_BUNDLE}"
fi
if [[ "$NEW_GROUP" != group.* ]]; then
    echo "Fehler: Eine App-Group muss mit 'group.' beginnen." >&2
    exit 1
fi

# Praefix = Bundle-ID ohne das letzte Segment, sonst die Bundle-ID selbst.
NEW_PREFIX="${NEW_BUNDLE%.*}"
[[ "$NEW_PREFIX" == "$NEW_BUNDLE" ]] && NEW_PREFIX="$NEW_BUNDLE"

FILES=(
    project.yml
    Sources/Shared/AppGroup.swift
    Sources/App/Pausenwaechter.entitlements
    Sources/Monitor/Monitor.entitlements
    Sources/ShieldConfig/ShieldConfig.entitlements
    Sources/ShieldAction/ShieldAction.entitlements
)

for file in "${FILES[@]}"; do
    [[ -f "$file" ]] || { echo "Fehlt: $file" >&2; exit 1; }
done

# Reihenfolge ist wichtig: die App-Group enthaelt das alte Praefix als
# Teilzeichenkette und muss deshalb zuerst ersetzt werden.
replace_in_files() {
    local from="$1" to="$2"
    [[ "$from" == "$to" ]] && return 0
    for file in "${FILES[@]}"; do
        # -i '' ist BSD-sed (macOS). Portabel ueber eine temporaere Datei.
        local tmp
        tmp="$(mktemp)"
        sed "s|${from}|${to}|g" "$file" > "$tmp"
        mv "$tmp" "$file"
    done
}

replace_in_files "$OLD_GROUP" "$NEW_GROUP"
replace_in_files "$OLD_BUNDLE" "$NEW_BUNDLE"
replace_in_files "bundleIdPrefix: ${OLD_PREFIX}" "bundleIdPrefix: ${NEW_PREFIX}"

if [[ -n "$NEW_TEAM" ]]; then
    tmp="$(mktemp)"
    sed "s|DEVELOPMENT_TEAM: \"\"|DEVELOPMENT_TEAM: \"${NEW_TEAM}\"|" project.yml > "$tmp"
    mv "$tmp" project.yml
fi

echo "Eingetragen:"
echo "  Bundle-ID   $NEW_BUNDLE"
echo "  Extensions  ${NEW_BUNDLE}.Monitor, ${NEW_BUNDLE}.Shield, ${NEW_BUNDLE}.ShieldAction"
echo "  App-Group   $NEW_GROUP"
echo "  Team-ID     ${NEW_TEAM:-<nicht gesetzt, in Xcode auswaehlen>}"
echo
echo "Naechster Schritt:  xcodegen generate && open Pausenwaechter.xcodeproj"

# Kontrolle: ist irgendwo ein alter Wert stehengeblieben?
if grep -rn --include='*.yml' --include='*.swift' --include='*.entitlements' \
        -e "$OLD_GROUP" -e "$OLD_BUNDLE" . >/dev/null 2>&1; then
    echo
    echo "Achtung: es sind noch alte Bezeichner uebrig:" >&2
    grep -rn --include='*.yml' --include='*.swift' --include='*.entitlements' \
        -e "$OLD_GROUP" -e "$OLD_BUNDLE" . >&2
fi
