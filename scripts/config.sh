# shellcheck shell=bash disable=SC2034

MIW_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MIW_WORK=${MIW_WORK:-$MIW_ROOT/work}
MIW_PREFIX=${MIW_PREFIX:-/opt/mutter-independent-workspaces/usr}

MUTTER_REPO=https://github.com/GNOME/mutter.git
MUTTER_TAG=51.1
MUTTER_COMMIT=9134e3a5869ce232bf95b77519005865747ba603
MUTTER_SUBPROJECTS=(gvdb)

SHELL_REPO=https://github.com/GNOME/gnome-shell.git
SHELL_TAG=51.1
SHELL_COMMIT=33da06854e229c256afd5872fedd83c28cbfa176
SHELL_SUBPROJECTS=(gvc libshew)

SESSION_FILES=(
  "gnome-iw.desktop:/usr/share/wayland-sessions/gnome-iw.desktop"
  "gnome-iw.session:/usr/share/gnome-session/sessions/gnome-iw.session"
  "systemd/gnome-session@gnome-iw.target.d/mutter-independent-workspaces.conf:/etc/systemd/user/gnome-session@gnome-iw.target.d/mutter-independent-workspaces.conf"
  "systemd/org.gnome.Shell@iw.service.d/mutter-independent-workspaces.conf:/etc/systemd/user/org.gnome.Shell@iw.service.d/mutter-independent-workspaces.conf"
)

MIW_EXTRA_MUTTER_PATCHES=${MIW_EXTRA_MUTTER_PATCHES:-}

read -ra SUDO_CMD <<< "${SUDO:-sudo}"

die() {
  echo "error: $*" >&2
  exit 1
}

note() {
  echo "==> $*"
}
