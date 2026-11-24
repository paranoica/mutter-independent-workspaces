#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

PKG=$MIW_ROOT/packaging
SHARE=$MIW_PREFIX/share/mutter-independent-workspaces

[[ $MIW_PREFIX =~ ^/[A-Za-z0-9._/+-]+$ ]] || die "MIW_PREFIX must be an absolute path of letters, digits and ._/+-"
[[ -x $MIW_PREFIX/bin/gnome-shell ]] || die "no gnome-shell in $MIW_PREFIX, run scripts/build.sh first"

note "files in $MIW_PREFIX"
"$MIW_ROOT/scripts/make-schemas.sh" "$SHARE/schemas"
echo "  $SHARE/schemas"
sed -e "s|@PREFIX@|$MIW_PREFIX|g" \
  -e "s|@MUTTER_VERSION@|$MUTTER_TAG|g" \
  -e "s|@SHELL_VERSION@|$SHELL_TAG|g" \
  "$PKG/gnome-shell-iw.in" > "$MIW_PREFIX/bin/gnome-shell-iw"
chmod 755 "$MIW_PREFIX/bin/gnome-shell-iw"
echo "  $MIW_PREFIX/bin/gnome-shell-iw"
printf 'MUTTER_VERSION=%s\nSHELL_VERSION=%s\nREPO=%s\n' \
  "$MUTTER_TAG" "$SHELL_TAG" "$MIW_ROOT" > "$BUILD_INFO"
echo "  $BUILD_INFO"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

note "system files (sudo)"
for entry in "${SESSION_FILES[@]}"; do
  src=${entry%%:*}
  dst=${entry#*:}
  sed "s|@PREFIX@|$MIW_PREFIX|g" "$PKG/$src" > "$tmp/file"
  "${SUDO_CMD[@]}" install -Dm644 "$tmp/file" "$dst"
  echo "  $dst"
done

sed -e "s|@BUILD_INFO@|$BUILD_INFO|g" \
  -e "s|@MUTTER@|/usr/bin/mutter|g" \
  -e "s|@GNOME_SHELL@|/usr/bin/gnome-shell|g" \
  "$PKG/mutter-independent-workspaces-check.in" > "$tmp/file"
"${SUDO_CMD[@]}" install -Dm755 "$tmp/file" "$CHECK_SCRIPT"
echo "  $CHECK_SCRIPT"

for entry in "${SYSTEM_FILES[@]}"; do
  src=${entry%%:*}
  dst=${entry#*:}
  sed "s|@CHECK_SCRIPT@|$CHECK_SCRIPT|g" "$PKG/$src" > "$tmp/file"
  "${SUDO_CMD[@]}" install -Dm644 "$tmp/file" "$dst"
  echo "  $dst"
done

systemctl --user daemon-reload || true

note "session installed"
