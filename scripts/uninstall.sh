#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

note "system files (sudo)"
for entry in "${SESSION_FILES[@]}"; do
  dst=${entry#*:}
  if [[ -e $dst ]]; then
    "${SUDO_CMD[@]}" rm -f -- "$dst"
    echo "  removed $dst"
  fi
  if [[ $dst == /etc/systemd/user/*.d/* && -d ${dst%/*} ]]; then
    "${SUDO_CMD[@]}" rmdir --ignore-fail-on-non-empty -- "${dst%/*}"
  fi
done
systemctl --user daemon-reload || true

note "files in $MIW_PREFIX"
if [[ -e $MIW_PREFIX/bin/gnome-shell-iw ]]; then
  rm -f -- "$MIW_PREFIX/bin/gnome-shell-iw"
  echo "  removed $MIW_PREFIX/bin/gnome-shell-iw"
fi
if [[ -d $MIW_PREFIX/share/mutter-independent-workspaces ]]; then
  rm -rf -- "$MIW_PREFIX/share/mutter-independent-workspaces"
  echo "  removed $MIW_PREFIX/share/mutter-independent-workspaces"
fi
