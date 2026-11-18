// BxRig screensaver placement (KWin script, loaded by `bxrig screensaver start` on Plasma).
// Each new window of the class bxrig-screensaver goes to a screen that has none yet, full screen, above everything, without a
// border, and out of the taskbar and the window switcher.
function isSaver(w) {
	return w && w.resourceClass == "bxrig-screensaver";
}

function place(w) {
	if (!isSaver(w)) return;
	var screens = workspace.screens;
	var used = [];
	var others = workspace.stackingOrder;
	for (var i = 0; i < others.length; i++) {
		if (others[i] !== w && isSaver(others[i])) used.push(others[i].output);
	}
	var target = screens[0];
	for (var j = 0; j < screens.length; j++) {
		if (used.indexOf(screens[j]) < 0) { target = screens[j]; break; }
	}
	workspace.sendClientToScreen(w, target);
	w.noBorder = true;
	w.skipTaskbar = true;
	w.skipSwitcher = true;
	w.skipPager = true;
	w.onAllDesktops = true;
	w.keepAbove = true;
	w.fullScreen = true;
	workspace.activeWindow = w;
}

workspace.windowAdded.connect(place);
