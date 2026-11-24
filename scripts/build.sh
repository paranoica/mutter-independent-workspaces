#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

SRC=$MIW_WORK/src
BUILD=$MIW_WORK/build

[[ -d $SRC/mutter && -d $SRC/gnome-shell ]] || die "no sources, run scripts/fetch.sh first"

prefix_parent=$(dirname "$MIW_PREFIX")
if [[ -e $MIW_PREFIX && ! -w $MIW_PREFIX ]]; then
  die "$MIW_PREFIX is not writable, run: sudo chown -R $USER $MIW_PREFIX"
elif [[ ! -e $MIW_PREFIX && ! -w $prefix_parent ]]; then
  die "$prefix_parent is not writable, run: sudo install -d -o $USER $prefix_parent"
fi

common_opts=(
  --prefix "$MIW_PREFIX"
  --libdir lib
  --libexecdir lib
  --sbindir bin
  --buildtype debugoptimized
  --auto-features enabled
  --wrap-mode nodownload
)

meson_build() {
  local name=$1
  shift
  local builddir=$BUILD/$name
  if [[ -f $builddir/build.ninja ]]; then
    meson setup --reconfigure "$builddir" "$SRC/$name" "${common_opts[@]}" "$@"
  else
    meson setup "$builddir" "$SRC/$name" "${common_opts[@]}" "$@"
  fi
  meson compile -C "$builddir"

  local outside
  outside=$(meson introspect --installed "$builddir" | python3 -I -c '
import json, sys
prefix = sys.argv[1].rstrip("/") + "/"
print("\n".join(p for p in json.load(sys.stdin).values() if not p.startswith(prefix)))
' "$MIW_PREFIX")
  [[ -z $outside ]] || die "$name would install outside $MIW_PREFIX:"$'\n'"$outside"

  meson install -C "$builddir" --quiet
}

tests=disabled
if [[ ${MIW_TESTS:-0} == 1 ]]; then
  tests=enabled
fi

note "building mutter"
meson_build mutter \
  -D docs=false \
  -D installed_tests=false \
  -D tests=$tests \
  -D udev_dir="$MIW_PREFIX/lib/udev"

export PKG_CONFIG_PATH=$MIW_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
export LD_LIBRARY_PATH=$MIW_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

note "building gnome-shell"
meson_build gnome-shell \
  -D gtk_doc=false \
  -D man=false \
  -D tests=false \
  -D extensions-tool:bash_completion=disabled \
  -D c_link_args="-Wl,-rpath,$MIW_PREFIX/lib"

runpath=$(readelf -d "$MIW_PREFIX/bin/gnome-shell" | sed -nE 's/.*\((RUNPATH|RPATH)\).*\[(.*)\]/\2/p' | paste -sd:)
[[ ":$runpath:" == *":$MIW_PREFIX/lib:"* ]] ||
  die "installed gnome-shell has runpath '$runpath' without $MIW_PREFIX/lib, it would load the system libmutter"

note "installed into $MIW_PREFIX"
