import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Scripting from 'resource:///org/gnome/shell/ui/scripting.js';
import {ExtensionState} from 'resource:///org/gnome/shell/misc/extensionUtils.js';

const UUID = 'dash-to-dock@micxgx.gmail.com';
const workspaceManager = global.workspace_manager;

let pointer;

function expectEqual(actual, expected, what) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a !== e)
        throw new Error(`${what}: got ${a}, expected ${e}`);
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
    workspaceManager.get_workspaces_for_monitor(monitor)[index].activate(global.get_current_time());
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

async function hideOverview() {
    for (let i = 0; i < 20 && Main.overview.visible; i++) {
        Main.overview.hide();
        await Scripting.sleep(500);
    }
}

async function waitForExtension() {
    for (let i = 0; i < 50; i++) {
        const extension = Main.extensionManager.lookup(UUID);
        if (extension?.state === ExtensionState.ACTIVE)
            return extension;
        await Scripting.sleep(200);
    }
    const extension = Main.extensionManager.lookup(UUID);
    throw new Error(`${UUID} is not active: state ${extension?.state}, ${extension?.error}`);
}

export async function run() {
    const seat = global.stage.context.get_backend().get_default_seat();
    pointer = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);

    Main.overview.hide();
    await settle();

    const extension = await waitForExtension();
    await hideOverview();
    const Docking = await import(extension.dir.get_child('docking.js').get_uri());
    const AppIcons = await import(extension.dir.get_child('appIcons.js').get_uri());
    const dock = Docking.DockManager.allDocks[0];
    const intellihide = dock._intellihide;
    const dockMonitor = dock.monitorIndex;
    const otherMonitor = 1 - dockMonitor;

    const overlaps = () => intellihide._status === 1;
    const interesting = window =>
        intellihide._intellihideFilterInteresting(window.get_compositor_private());

    await pointAt(dockMonitor);
    await hideOverview();
    const window = await openWindow();
    await hideOverview();
    window.maximize();
    await Scripting.sleep(1000);
    await settle();
    expectEqual(window.get_monitor(), dockMonitor, 'window monitor');

    expectEqual([interesting(window), overlaps()], [true, true], 'dock hides at start');

    await activate(otherMonitor, 1);
    expectEqual([interesting(window), overlaps()], [true, true],
        'dock hides after the other monitor switched workspace');

    await activate(dockMonitor, 1);
    expectEqual([interesting(window), overlaps()], [false, false],
        'dock shows when its own monitor left the workspace of the window');

    await activate(otherMonitor, 0);
    expectEqual([interesting(window), overlaps()], [false, false],
        'dock stays shown after the other monitor switched back');

    await activate(dockMonitor, 0);
    expectEqual([interesting(window), overlaps()], [true, true],
        'dock hides when its own monitor is back on the workspace of the window');

    await activate(otherMonitor, 1);
    const minimize = AppIcons.DockAbstractAppIcon.prototype._minimizeWindow;
    minimize.call({getInterestingWindows: () => [window]}, false);
    await settle();
    expectEqual(window.minimized, true,
        'clicking the dock minimizes the window after the other monitor switched workspace');
    window.unminimize();
    await settle();

    await activate(dockMonitor, 1);
    minimize.call({getInterestingWindows: () => [window]}, false);
    await settle();
    expectEqual(window.minimized, false,
        'clicking the dock leaves a window on a hidden workspace alone');

    await Scripting.destroyTestWindows();
    await settle();
}
