# mutter-independent-workspaces

Independent workspaces for every monitor in GNOME. Switch workspaces on one
monitor and the others stay where they are.

```
   Monitor 1                         Monitor 2
 ┌─────────────────────────┐       ┌─────────────────────────┐
 │                         │       │                         │
 │   workspace 2 of 3      │       │   workspace 1 of 2      │
 │                         │       │                         │
 └─────────────────────────┘       └─────────────────────────┘
   [ 1 ] [■2■] [ 3 ]                 [■1■] [ 2 ]
      Super+PgDn here  ──────────►   only monitor 1 moves
```

It builds the upstream work in progress for this feature,
[mutter!5194](https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/5194) and
[gnome-shell!4299](https://gitlab.gnome.org/GNOME/gnome-shell/-/merge_requests/4299),
with fixes on top, for the GNOME release your distribution ships. It installs
as a separate login session next to the system GNOME and leaves the system
packages alone.

## Features

- Every monitor has its own workspaces and switches them on its own, from the
  keyboard shortcuts and from the overview.
- Dynamic workspaces per monitor: each monitor keeps one empty workspace at its
  end. A fixed number from Settings applies to every monitor instead.
- New windows open on the current workspace of the monitor they appear on.
- When a window closes, the focus goes back to the window you used last, on
  whichever monitor it is.
- A monitor that is switched off or unplugged gets its workspaces and windows
  back when it returns, also for identical twin monitors.

## Requirements

- Arch Linux with GNOME **51.1** (`gnome-shell` and `mutter` from the repos).
- About 500 MB of disk space for the sources and the build.

## Install

```sh
git clone https://github.com/paranoica/mutter-independent-workspaces
cd mutter-independent-workspaces
./miw install
```

`./miw install` checks the GNOME version, installs the missing build
dependencies (with `pacman -Syu`, so the system is updated first), downloads
mutter and gnome-shell, applies the patches, builds them into
`/opt/mutter-independent-workspaces` and adds the session. Run it as your user;
it asks for sudo when it needs it.

Log out and pick **GNOME (Independent Workspaces)** on the login screen. Pick
the normal **GNOME** session to go back.

## How it works

```
 pacman                           ./miw install
 ──────                           ─────────────
 mutter 51.1        untouched     mutter 51.1      + patches/mutter
 gnome-shell 51.1   untouched     gnome-shell 51.1 + patches/gnome-shell
   │                                │
   ▼                                ▼
 "GNOME" session                  "GNOME (Independent Workspaces)" session
                                  built into /opt/mutter-independent-workspaces
```

The new session starts its own `gnome-shell` from the private prefix with
per-monitor workspaces turned on. Your settings, extensions and apps are
shared with the normal session.

The build only works with the exact GNOME version it was made for. If GNOME is
updated, the session refuses to start and the login screen comes back, where
the normal GNOME session still works.

## Updating

A pacman hook watches `mutter` and `gnome-shell`. After a GNOME update it
prints a warning, and a notification shows up at the next login:

```
warning: GNOME was updated (gnome-shell 51.2, mutter 51.2), but the
         Independent Workspaces session is built for gnome-shell 51.1,
         mutter 51.1 and will not start until you rebuild it:
         cd ~/mutter-independent-workspaces && git pull && ./miw update
```

`./miw update` rebuilds for the new release once this repository supports it.
Until then it says so and changes nothing.

## Extensions

Extensions keep working in the new session, but some of them assume that all
monitors switch workspaces together. Patches for these are included and applied
by `./miw install` to the copies in `~/.local/share/gnome-shell/extensions`:

| Extension | Fix |
| --- | --- |
| [Blur my Shell](https://extensions.gnome.org/extension/3193/blur-my-shell/) | Blurs only the monitor that switches workspaces. |
| [Dash to Dock](https://extensions.gnome.org/extension/307/dash-to-dock/) | Hides and minimizes by the workspace of its own monitor. |

An extension update removes the patch. Run `./miw update` again and log out
and back in.

## Commands

| Command | |
| --- | --- |
| `./miw install` | Build and install everything. |
| `./miw update` | The same, after a GNOME update or a `git pull`. |
| `./miw status` | Versions, installed parts and extension patches. |
| `./miw uninstall` | Remove the session, the system files and the extension patches. |
| `./miw uninstall --purge` | Also remove the build and the downloaded sources. |

## Limitations

- Per-monitor mode cannot be turned on or off while the session runs.
- The overview and Alt+Tab follow the upstream merge requests, whose design is
  not final yet.
- A monitor that comes back on a different connector gets new workspaces, and
  the old ones stay hidden until you log out.
- The build belongs to the user who installed it. On a shared computer every
  account that picks the session runs that user's build.

## Development

```sh
MIW_TESTS=1 ./miw update
meson test -C work/build/mutter --suite mutter/stacking
uv run --no-project --with pytest pytest tests
scripts/run-devkit.sh
```

The mutter stacking tests cover the per-monitor cases. The pytest suite starts
the installed gnome-shell headless with two virtual monitors, and checks the
pacman hook script. `scripts/run-devkit.sh` runs a nested shell with two
virtual monitors in windows.

To build with your own mutter patches on top, put them in a directory and add
`MIW_EXTRA_MUTTER_PATCHES=/path/to/them` to `local.conf` in the repository.

The pinned versions and the patch series are described in
[patches/BASELINE.md](patches/BASELINE.md).

## Credits

The per-monitor workspaces in mutter and gnome-shell are the work of Victor C.
(vicajilau), based on earlier work by Chris Willingham. See [NOTICE](NOTICE).

## License

GPL-2.0-or-later, the same as mutter and gnome-shell. See [COPYING](COPYING).
