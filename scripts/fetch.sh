#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/config.sh
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

SRC=$MIW_WORK/src

git_local() {
  git -c user.name=mutter-independent-workspaces -c user.email=miw@localhost "$@"
}

wrap_value() {
  sed -nE "s/^$2[[:space:]]*=[[:space:]]*//p" "$1" | head -n1 | tr -d '[:space:]'
}

clone_tag() {
  local repo=$1 tag=$2 commit=$3 dest=$4
  note "cloning $repo at $tag"
  git clone -q --depth 1 --branch "$tag" -c advice.detachedHead=false "$repo" "$dest"
  [[ $(git -C "$dest" rev-parse HEAD) == "$commit" ]] || die "$repo: tag $tag does not point at $commit"
}

fetch_subproject() {
  local src=$1 name=$2
  local wrap=$src/subprojects/$name.wrap
  [[ -f $wrap ]] || die "no wrap file $wrap"

  local url rev dir
  url=$(wrap_value "$wrap" url)
  rev=$(wrap_value "$wrap" revision)
  dir=$(wrap_value "$wrap" directory)
  dir=${dir:-$name}
  url=${url/#https:\/\/gitlab.gnome.org\/GNOME\//https://github.com/GNOME/}
  [[ $rev =~ ^[0-9a-f]{40}$ ]] || die "$wrap: revision '$rev' is not a commit id"

  note "subproject $dir at ${rev:0:12}"
  git init -q "$src/subprojects/$dir"
  git -C "$src/subprojects/$dir" fetch -q --depth 1 "$url" "$rev"
  git -C "$src/subprojects/$dir" checkout -q FETCH_HEAD
}

apply_series() {
  local src=$1 dir=$2
  local patches=("$dir"/*.patch)
  [[ -e ${patches[0]} ]] || return 0
  for p in "${patches[@]}"; do
    note "applying $(basename "$p")"
    git_local -C "$src" am --3way --quiet "$p"
  done
}

apply_extra() {
  local src=$1
  local patches=("$MIW_EXTRA_MUTTER_PATCHES"/*.patch)
  [[ -e ${patches[0]} ]] || die "no patches in MIW_EXTRA_MUTTER_PATCHES=$MIW_EXTRA_MUTTER_PATCHES"
  for p in "${patches[@]}"; do
    note "applying extra $(basename "$p")"
    git_local -C "$src" apply --3way --quiet "$p"
    git_local -C "$src" commit -q -a -m "extra: $(basename "$p" .patch)"
  done
}

if [[ -e $SRC ]]; then
  [[ -f $SRC/.miw-src ]] || die "$SRC exists but was not created by fetch.sh, remove it by hand"
  rm -rf -- "$SRC"
fi
mkdir -p "$SRC"
touch "$SRC/.miw-src"

clone_tag "$MUTTER_REPO" "$MUTTER_TAG" "$MUTTER_COMMIT" "$SRC/mutter"
for s in "${MUTTER_SUBPROJECTS[@]}"; do fetch_subproject "$SRC/mutter" "$s"; done
if [[ -n $MIW_EXTRA_MUTTER_PATCHES ]]; then
  apply_extra "$SRC/mutter"
fi
apply_series "$SRC/mutter" "$MIW_ROOT/patches/mutter"

clone_tag "$SHELL_REPO" "$SHELL_TAG" "$SHELL_COMMIT" "$SRC/gnome-shell"
for s in "${SHELL_SUBPROJECTS[@]}"; do fetch_subproject "$SRC/gnome-shell" "$s"; done
apply_series "$SRC/gnome-shell" "$MIW_ROOT/patches/gnome-shell"

note "sources ready in $SRC"
