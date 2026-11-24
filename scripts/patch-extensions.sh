#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

EXT_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions

mode=apply
case ${1:-} in
  '') ;;
  --check) mode=check ;;
  --revert) mode=revert ;;
  *) die "usage: $0 [--check|--revert]" ;;
esac

applies() {
  patch -d "$1" -p1 "${@:3}" --dry-run --silent < "$2" > /dev/null 2>&1
}

for patch_file in "$MIW_ROOT"/patches/extensions/*.patch; do
  uuid=$(basename "$patch_file" .patch)
  dir=$EXT_DIR/$uuid
  if [[ ! -d $dir ]]; then
    echo "  $uuid: not installed"
    continue
  fi
  if applies "$dir" "$patch_file" -R; then
    patched=1
  elif applies "$dir" "$patch_file" --forward; then
    patched=0
  else
    echo "  $uuid: the patch does not apply to this version"
    continue
  fi
  case $mode in
    check)
      if ((patched)); then echo "  $uuid: patched"; else echo "  $uuid: not patched, run scripts/patch-extensions.sh"; fi
      ;;
    apply)
      if ((patched)); then
        echo "  $uuid: already patched"
      else
        patch -d "$dir" -p1 --forward --silent --no-backup-if-mismatch < "$patch_file"
        echo "  $uuid: patched, log out and back in to load it"
      fi
      ;;
    revert)
      if ((patched)); then
        patch -d "$dir" -p1 -R --silent --no-backup-if-mismatch < "$patch_file"
        echo "  $uuid: patch removed, log out and back in to load it"
      else
        echo "  $uuid: not patched"
      fi
      ;;
  esac
done
