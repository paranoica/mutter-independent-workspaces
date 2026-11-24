import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Scripting from 'resource:///org/gnome/shell/ui/scripting.js';

const dynamic = GLib.getenv('MIW_TEST_DYNAMIC') === '1';
const workspaceManager = global.workspace_manager;

let pointer;

function expectEqual(actual, expected, what) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a !== e)
        throw new Error(`${what}: got ${a}, expected ${e}`);
}

function workspacesOf(monitor) {
    return workspaceManager.get_workspaces_for_monitor(monitor);
}

function counts() {
    return [0, 1].map(m => workspacesOf(m).length);
}

function placeOf(window) {
    const monitor = window.get_monitor();
    return [monitor, workspacesOf(monitor).indexOf(window.get_workspace())];
}

async function settle() {
    await Scripting.waitLeisure();
    await Scripting.sleep(300);
    await Scripting.waitLeisure();
}

async function pointAt(monitor) {
    const geometry = global.display.get_monitor_geometry(monitor);
    pointer.notify_absolute_motion(GLib.get_monotonic_time(),
        geometry.x + geometry.width / 2, geometry.y + geometry.height / 2);
    await settle();
}

async function activate(monitor, index) {
    workspacesOf(monitor)[index].activate(global.get_current_time());
    await settle();
}

async function openWindow() {
    const before = new Set(global.display.list_all_windows());
    await Scripting.createTestWindow({width: 300, height: 200});
    await Scripting.waitTestWindows();
    await settle();
    const added = global.display.list_all_windows().filter(w => !before.has(w));
    expectEqual(added.length, 1, 'new windows');
    return added[0];
}

export async function run() {
    const seat = global.stage.context.get_backend().get_default_seat();
    pointer = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);

    Main.overview.hide();
    await settle();

    expectEqual(workspaceManager.per_monitor_workspaces, true, 'per-monitor mode');
    expectEqual(Meta.prefs_get_dynamic_workspaces(), dynamic, 'dynamic workspaces');
    expectEqual(global.display.get_n_monitors(), 2, 'monitors');
    expectEqual(counts(), dynamic ? [2, 2] : [4, 4], 'workspaces at start');

    await pointAt(0);
    const a = await openWindow();
    expectEqual(placeOf(a), [0, 0], 'window a');

    await activate(0, 1);
    const b = await openWindow();
    expectEqual(placeOf(b), [0, 1], 'window b');
    expectEqual(counts(), dynamic ? [3, 2] : [4, 4], 'workspaces after b');

    await pointAt(1);
    const c = await openWindow();
    expectEqual(placeOf(c), [1, 0], 'window c');

    await activate(1, 1);
    const d = await openWindow();
    expectEqual(placeOf(d), [1, 1], 'window d');
    expectEqual(counts(), dynamic ? [3, 3] : [4, 4], 'workspaces after d');

    b.activate(global.get_current_time());
    await settle();
    Main.wm._showWorkspaceSwitcher(global.display, b, null,
        {get_name: () => 'move-to-workspace-left'});
    await settle();
    expectEqual(placeOf(b), [0, 0], 'window b moved left with the pointer elsewhere');
    expectEqual(placeOf(d), [1, 1], 'window d after moving b');

    Main.overview.show();
    await Scripting.sleep(1000);
    Main.overview.hide();
    await Scripting.sleep(1000);

    await Scripting.destroyTestWindows();
    await Scripting.sleep(1000);
    await settle();
    expectEqual(counts(), dynamic ? [2, 2] : [4, 4], 'workspaces after closing all windows');
}
