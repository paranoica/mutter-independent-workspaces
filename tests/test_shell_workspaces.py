import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PREFIX = Path(os.environ.get("MIW_PREFIX", "/opt/mutter-independent-workspaces/usr"))
SHELL = PREFIX / "bin" / "gnome-shell"
SCRIPT = ROOT / "tests" / "shell" / "per-monitor-workspaces.js"
DOCK_SCRIPT = ROOT / "tests" / "shell" / "dash-to-dock.js"
DOCK_UUID = "dash-to-dock@micxgx.gmail.com"
DOCK_SOURCE = (
    Path.home() / ".local" / "share" / "gnome-shell" / "extensions" / DOCK_UUID
)

pytestmark = pytest.mark.skipif(not SHELL.exists(), reason="no build in the prefix")


def run_shell(
    tmp_path: Path, dynamic: bool, script: Path = SCRIPT, extra_keyfile: str = ""
) -> subprocess.CompletedProcess[str]:
    schemas = tmp_path / "schemas"
    subprocess.run([ROOT / "scripts" / "make-schemas.sh", schemas], check=True)

    config = tmp_path / "config"
    keyfile = config / "glib-2.0" / "settings" / "keyfile"
    keyfile.parent.mkdir(parents=True)
    keyfile.write_text(
        "[org/gnome/desktop/interface]\nenable-animations=false\n\n"
        f"[org/gnome/mutter]\ndynamic-workspaces={'true' if dynamic else 'false'}\n\n"
        + extra_keyfile
    )

    runtime = tmp_path / "runtime"
    runtime.mkdir(mode=0o700)

    env = {
        "PATH": os.environ["PATH"],
        "HOME": str(tmp_path),
        "XDG_CONFIG_HOME": str(config),
        "XDG_DATA_HOME": str(tmp_path / "data"),
        "XDG_CACHE_HOME": str(tmp_path / "cache"),
        "XDG_RUNTIME_DIR": str(runtime),
        "XDG_CURRENT_DESKTOP": "GNOME",
        "GSETTINGS_BACKEND": "keyfile",
        "GSETTINGS_SCHEMA_DIR": str(schemas),
        "MIW_TEST_DYNAMIC": "1" if dynamic else "0",
    }
    return subprocess.run(
        [
            "dbus-run-session",
            "--",
            SHELL,
            "--headless",
            "--virtual-monitor",
            "1280x720",
            "--virtual-monitor",
            "1280x720",
            "--wayland-display",
            "miw-test",
            "--automation-script",
            script,
        ],
        env=env,
        check=False,
        capture_output=True,
        text=True,
        timeout=180,
    )


def assert_clean(result: subprocess.CompletedProcess[str]) -> None:
    output = result.stdout + result.stderr
    errors = [
        line
        for line in output.splitlines()
        if "JS ERROR" in line or "Script failed" in line
    ]
    assert result.returncode == 0 and not errors, output[-6000:]


@pytest.mark.parametrize("dynamic", [True, False], ids=["dynamic", "static"])
def test_per_monitor_workspaces(tmp_path: Path, dynamic: bool) -> None:
    assert_clean(run_shell(tmp_path, dynamic))


@pytest.mark.skipif(not DOCK_SOURCE.is_dir(), reason="dash-to-dock is not installed")
def test_dash_to_dock(tmp_path: Path) -> None:
    extensions = tmp_path / "data" / "gnome-shell" / "extensions"
    shutil.copytree(DOCK_SOURCE, extensions / DOCK_UUID)
    patched = subprocess.run(
        [ROOT / "scripts" / "patch-extensions.sh"],
        env={**os.environ, "XDG_DATA_HOME": str(tmp_path / "data")},
        check=True,
        capture_output=True,
        text=True,
    )
    assert re.search(
        rf"{re.escape(DOCK_UUID)}: (patched|already patched)", patched.stdout
    ), (patched.stdout + patched.stderr)
    result = run_shell(
        tmp_path,
        dynamic=True,
        script=DOCK_SCRIPT,
        extra_keyfile=(
            f"[org/gnome/shell]\nenabled-extensions=['{DOCK_UUID}']\n\n"
            "[org/gnome/shell/extensions/dash-to-dock]\n"
            "intellihide=true\ndock-fixed=false\nintellihide-mode='ALL_WINDOWS'\n"
        ),
    )
    assert_clean(result)
