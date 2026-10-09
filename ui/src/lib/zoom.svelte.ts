import { getCurrentWebview } from '@tauri-apps/api/webview';

// Tauri's `zoomHotkeysEnabled` polyfill caps zoom-in at 1000%, which shreds the layout long before
// it gets there (fixed chrome overlaps, the player bar eats the page), so the level list below is
// this app's own ceiling. Zoom is set from Settings > Themes; persisted to localStorage (a pure UI
// preference, no backend round-trip) and reapplied on launch, because a 4K screen needs the same
// bump every start (issue #243).

/**
 * The only zoom levels there are, the browser set minus the unusable ends. The Settings dropdown
 * walks this list, so it always has a row to show for the current level.
 */
export const LEVELS = [0.5, 0.67, 0.75, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75];

const KEY = 'zoom';

/** An object, not a bare `let`: reassigned module state cannot be exported from a rune module. */
export const zoom = $state({ level: 1 });

/** `level` must come from `LEVELS`. */
export function setZoom(level: number) {
	zoom.level = level;
	localStorage.setItem(KEY, String(level));
	getCurrentWebview()
		.setZoom(level)
		.catch(() => {});
}

export function initZoom() {
	const stored = Number(localStorage.getItem(KEY));
	setZoom(LEVELS.includes(stored) ? stored : 1);
	// No keyboard zoom at all any more (in, out and reset were all removed): the Settings > Themes
	// dropdown is the only way to change it, so there is nothing to listen for here beyond the
	// ctrl+wheel suppression below.
	// Ctrl+wheel is disabled outright, so it never zooms. The non-passive wheel listener is only
	// bound while a gesture is in flight: `preventDefault` is what stops the webview doing its own
	// ctrl+wheel zoom, but a non-passive `wheel` listener on the window tells Chromium (so WebView2,
	// so Windows) that *any* wheel event might be cancelled, which takes every scroll in the app
	// off the compositor thread. Binding it only while Ctrl is held keeps that cost scoped.
	let bound = false;
	const bindWheel = (on: boolean) => {
		if (on === bound) return;
		bound = on;
		if (on) window.addEventListener('wheel', onWheel, { passive: false });
		else window.removeEventListener('wheel', onWheel);
	};
	const onWheel = (e: WheelEvent) => {
		// Ctrl came up mid-gesture: unbind here rather than waiting for the keyup, so an ordinary
		// scroll continued from the same gesture is back on the compositor immediately.
		if (!e.ctrlKey) return bindWheel(false);
		e.preventDefault();
	};
	// `e.ctrlKey`, not `e.key === 'Control'`: Ctrl can already be held when the window takes focus,
	// and then the first key event we see is some other key.
	const track = (e: KeyboardEvent) => bindWheel(e.ctrlKey);
	const release = () => bindWheel(false);
	// A macOS trackpad pinch arrives as ctrl+wheel with no key event at all, so arm off the wheel as
	// well. Passive, so this one costs the compositor nothing.
	const arm = (e: WheelEvent) => {
		if (e.ctrlKey) bindWheel(true);
	};
	window.addEventListener('keydown', track);
	window.addEventListener('keyup', track);
	window.addEventListener('blur', release);
	window.addEventListener('wheel', arm, { passive: true });
	return () => {
		window.removeEventListener('keydown', track);
		window.removeEventListener('keyup', track);
		window.removeEventListener('blur', release);
		window.removeEventListener('wheel', arm);
		bindWheel(false);
	};
}
