<script lang="ts">
	// Ctrl+H, ⌘/ on macOS: what the keyboard can do. Nothing in the chrome points at the shortcuts, so this is
	// where they are discoverable. The rows come from `apphotkeys.ts`, the same list Settings > Hotkeys
	// shows read-only.
	import * as Dialog from '$lib/components/ui/dialog';
	import { APP_HOTKEY_GROUPS } from '$lib/apphotkeys';
	import { HELP_COMBO } from '$lib/shortcuts';
	import { ui } from '$lib/player.svelte';
	import { t } from '$lib/i18n.svelte';

	// The same list Settings > Hotkeys shows read-only; `apphotkeys.ts` is the one source.
	// $derived, not a plain const: it is rebuilt when the language changes under it.
	const GROUPS: { title: string; rows: [string, string][] }[] = $derived(
		APP_HOTKEY_GROUPS.map((g) => ({
			title: t(g.titleKey),
			rows: g.rows.map((r) => [t(r.labelKey), r.keys] as [string, string])
		}))
	);
</script>

<Dialog.Root bind:open={ui.shortcutsOpen}>
	<Dialog.Content class="sm:max-w-2xl">
		<Dialog.Header>
			<Dialog.Title>{t('dialogs.shortcuts.title')}</Dialog.Title>
			<Dialog.Description>{t('dialogs.shortcuts.reopen_hint', { key: HELP_COMBO })}</Dialog.Description>
		</Dialog.Header>
		<!-- Two columns that flow, so adding a row never means rebalancing the layout by hand. -->
		<div class="gap-x-10 sm:columns-2">
			{#each GROUPS as group (group.title)}
				<section class="mb-6 break-inside-avoid">
					<h3 class="mb-2 text-base font-semibold">{group.title}</h3>
					<dl>
						{#each group.rows as [what, keys] (what)}
							<div class="grid grid-cols-2 items-center gap-4 border-b py-2 last:border-0">
								<dt class="text-sm text-muted-foreground">{what}</dt>
								<dd class="font-mono text-xs font-medium">{keys}</dd>
							</div>
						{/each}
					</dl>
				</section>
			{/each}
		</div>
	</Dialog.Content>
</Dialog.Root>
