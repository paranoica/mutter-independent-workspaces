# Baseline

| Component | Base | Patches |
| --- | --- | --- |
| mutter | tag `51.1` | `mutter/0000-upstream-mr5194.patch`, then `mutter/0001`–`0012` |
| gnome-shell | tag `51.1` | `gnome-shell/0000-upstream-mr4299.patch`, then `gnome-shell/0001`–`0003` |

The 0000 files are the upstream merge requests. The numbered patches after
them are this project's fixes and the dynamic workspace support, exported
with `git format-patch` and applied in order with `git am`.

## Upstream merge requests

Both files are the `.patch` export of the merge request, taken on 2026-11-23.

| MR | Source branch | Head commit | Last update |
| --- | --- | --- | --- |
| [GNOME/mutter!5194](https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/5194) | `vicajilau/mutter:per-monitor-workspaces-v2-rebased` | `959c1a76c06c3a263df68bcdecb2b7ad26b2a891` | 2026-11-17 |
| [GNOME/gnome-shell!4299](https://gitlab.gnome.org/GNOME/gnome-shell/-/merge_requests/4299) | `vicajilau/gnome-shell:per-monitor-workspaces-2-rebased` | `500a1deb952122c3e319bf765d270417887aa097` | 2026-10-09 |

The merge requests target `main`; both series apply to `51.1` with `git am --3way` without conflicts.

To move to a newer revision, download `https://gitlab.gnome.org/GNOME/<project>/-/merge_requests/<id>.patch`, replace the file and update the table.

## Subprojects

Fetched from the GitHub mirrors at the revision pinned in the tag's wrap files:
`gvdb` for mutter, `gvc` and `libshew` for gnome-shell.
