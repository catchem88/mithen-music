// The app's own keyboard shortcuts: the ones `shortcuts.ts` answers to while the MithenMusic window
// is focused. They are not configurable, so this is the single list that Settings > Hotkeys shows
// read-only and the Ctrl+H dialog renders in full. Labels are i18n keys, resolved by each consumer
// (the key column is machine-specific text and is already spelled here).
//
// Global hotkeys are a separate list entirely: those are OS-level, configurable, and live in
// `hotkeys.svelte.ts` (`HOTKEY_ACTIONS`).
import type { TranslationKey } from './i18n.svelte';
import { HELP_COMBO, MOD, MUTE_COMBO } from './shortcuts';

export interface AppHotkeyRow {
	labelKey: TranslationKey;
	/** The combo as it should be shown. `MOD` is Ctrl, or ⌘ on macOS. */
	keys: string;
}

export interface AppHotkeyGroup {
	titleKey: TranslationKey;
	rows: AppHotkeyRow[];
}

export const APP_HOTKEY_GROUPS: AppHotkeyGroup[] = [
	{
		titleKey: 'dialogs.shortcuts.group_playback',
		rows: [
			{ labelKey: 'dialogs.shortcuts.play_pause', keys: 'SPACE or ;' },
			{ labelKey: 'dialogs.shortcuts.next_song', keys: `${MOD}F` },
			{ labelKey: 'dialogs.shortcuts.previous_song', keys: `${MOD}D` },
			{ labelKey: 'dialogs.shortcuts.shuffle_queue', keys: `${MOD}S` },
			{ labelKey: 'dialogs.shortcuts.toggle_repeat', keys: `${MOD}R` },
			{ labelKey: 'dialogs.shortcuts.mute_unmute', keys: MUTE_COMBO }
		]
	},
	{
		titleKey: 'dialogs.shortcuts.group_general',
		rows: [
			{ labelKey: 'dialogs.shortcuts.refresh_page', keys: 'F5' },
			{ labelKey: 'dialogs.shortcuts.focus_search', keys: '.' },
			{ labelKey: 'dialogs.shortcuts.search_anywhere', keys: `${MOD}K` },
			{ labelKey: 'dialogs.shortcuts.toggle_now_playing', keys: `${MOD}E` },
			{ labelKey: 'dialogs.shortcuts.track_info', keys: `${MOD}I` },
			{ labelKey: 'dialogs.shortcuts.volume_up', keys: `${MOD}>` },
			{ labelKey: 'dialogs.shortcuts.volume_down', keys: `${MOD}<` },
			{ labelKey: 'dialogs.shortcuts.show_this_list', keys: HELP_COMBO }
		]
	}
];
