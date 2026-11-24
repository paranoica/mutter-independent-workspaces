#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

DEVKIT=$MIW_WORK/devkit
SIZE=${MIW_DEVKIT_SIZE:-1280x720}
LOG=$DEVKIT/shell.log

[[ -x $MIW_PREFIX/bin/gnome-shell ]] || die "no gnome-shell in $MIW_PREFIX, run scripts/build.sh first"
[[ $SIZE =~ ^[0-9]+x[0-9]+$ ]] || die "MIW_DEVKIT_SIZE must look like 1280x720"

mkdir -p "$DEVKIT"
cat > "$DEVKIT/keybindings.override" <<'EOF'
[org.gnome.desktop.wm.keybindings]
switch-to-workspace-1=['F1']
switch-to-workspace-2=['F2']
switch-to-workspace-3=['F3']
switch-to-workspace-4=['F4']
EOF
"$MIW_ROOT/scripts/make-schemas.sh" "$DEVKIT/schemas" "$DEVKIT/keybindings.override"

note "starting nested gnome-shell, log in $LOG"
dbus-run-session -- env \
  GSETTINGS_BACKEND=memory \
  GSETTINGS_SCHEMA_DIR="$DEVKIT/schemas" \
  "$MIW_PREFIX/bin/gnome-shell" --wayland --devkit \
  --devkit-args="-s $SIZE -s $SIZE -M" 2>&1 | tee "$LOG"
