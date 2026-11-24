import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "packaging" / "mutter-independent-workspaces-check.in"
REPO = "/home/user/mutter-independent-workspaces"


def write_tool(bin_dir: Path, name: str, body: str) -> None:
    tool = bin_dir / name
    tool.write_text(f"#!/bin/sh\n{body}\n")
    tool.chmod(tool.stat().st_mode | stat.S_IEXEC)


@pytest.fixture
def setup(tmp_path: Path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (bin_dir / "awk").symlink_to(shutil.which("awk"))
    info = tmp_path / "build-info"
    script = tmp_path / "check"
    script.write_text(
        TEMPLATE.read_text()
        .replace("@BUILD_INFO@", str(info))
        .replace("@MUTTER@", str(bin_dir / "mutter"))
        .replace("@GNOME_SHELL@", str(bin_dir / "gnome-shell"))
    )
    script.chmod(0o755)
    calls = tmp_path / "notify-calls"

    def run(
        built: tuple[str, str] | None,
        system: tuple[str | None, str | None],
        *args: str,
        notify_send: bool = True,
    ) -> tuple[str, str]:
        if built:
            info.write_text(
                f"MUTTER_VERSION={built[0]}\nSHELL_VERSION={built[1]}\nREPO={REPO}\n"
            )
        mutter, shell = system
        for name in ("mutter", "gnome-shell", "notify-send"):
            (bin_dir / name).unlink(missing_ok=True)
        if mutter:
            write_tool(bin_dir, "mutter", f"echo 'mutter {mutter}'")
        if shell:
            write_tool(bin_dir, "gnome-shell", f"echo 'GNOME Shell {shell}'")
        if notify_send:
            write_tool(bin_dir, "notify-send", f'printf "%s\\n" "$@" >> "{calls}"')
        env = {**os.environ, "PATH": str(bin_dir)}
        result = subprocess.run(
            [str(script), *args], env=env, capture_output=True, text=True, check=False
        )
        assert result.returncode == 0, result.stderr
        notified = calls.read_text() if calls.exists() else ""
        return result.stdout, notified

    return run


def test_matching_versions_are_silent(setup) -> None:
    assert setup(("51.1", "51.1"), ("51.1", "51.1")) == ("", "")
    assert setup(("51.1", "51.1"), ("51.1", "51.1"), "--notify") == ("", "")


def test_newer_gnome_warns_with_the_rebuild_command(setup) -> None:
    out, notified = setup(("51.1", "51.1"), ("51.2", "51.2"))
    assert out == (
        "warning: GNOME was updated (gnome-shell 51.2, mutter 51.2), but the\n"
        "         Independent Workspaces session is built for gnome-shell 51.1,\n"
        "         mutter 51.1 and will not start until you rebuild it:\n"
        f"         cd {REPO} && git pull && ./miw update\n"
    )
    assert notified == ""


def test_only_mutter_changed_still_warns(setup) -> None:
    out, _ = setup(("51.1", "51.1"), ("51.2", "51.1"))
    assert out.startswith("warning: GNOME was updated (gnome-shell 51.1, mutter 51.2)")


def test_notify_sends_a_desktop_notification(setup) -> None:
    out, notified = setup(("51.1", "51.1"), ("52.0", "52.0"), "--notify")
    assert out == ""
    assert notified.splitlines() == [
        "-a",
        "Independent Workspaces",
        "-i",
        "dialog-warning",
        "Independent Workspaces needs a rebuild",
        (
            "GNOME was updated to 52.0, the session is built for 51.1. "
            f"Run: cd {REPO} && git pull && ./miw update"
        ),
    ]


def test_notify_without_notify_send_is_silent(setup) -> None:
    assert setup(("51.1", "51.1"), ("52.0", "52.0"), "--notify", notify_send=False) == (
        "",
        "",
    )


def test_no_build_is_silent(setup) -> None:
    assert setup(None, ("52.0", "52.0")) == ("", "")


def test_missing_system_gnome_is_silent(setup) -> None:
    assert setup(("51.1", "51.1"), (None, None)) == ("", "")
