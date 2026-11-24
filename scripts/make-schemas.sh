#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

dest=${1:?usage: make-schemas.sh DEST [EXTRA_OVERRIDE_FILE]}
extra=${2:-}

rm -f -- "$dest"/*.xml "$dest"/*.override "$dest"/gschemas.compiled
mkdir -p "$dest"
install -m644 -t "$dest" \
  "$MIW_PREFIX"/share/glib-2.0/schemas/*.xml \
  "$MIW_PREFIX"/share/glib-2.0/schemas/*.override
if [[ -n $extra ]]; then
  install -m644 -t "$dest" \
    /usr/share/glib-2.0/schemas/org.gnome.desktop.enums.xml \
    /usr/share/glib-2.0/schemas/org.gnome.desktop.wm.preferences.gschema.xml \
    /usr/share/glib-2.0/schemas/org.gnome.desktop.wm.keybindings.gschema.xml
fi

{
  for group in org.gnome.mutter org.gnome.mutter:GNOME; do
    printf '[%s]\nper-monitor-workspaces=true\nworkspaces-only-on-primary=false\n\n' "$group"
  done
  if [[ -n $extra ]]; then
    cat "$extra"
  fi
} > "$dest/99_mutter-independent-workspaces.gschema.override"

glib-compile-schemas "$dest"
