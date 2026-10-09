<script lang="ts">
	// Ctrl+I: what the current track actually is. A stream's fields are what YouTube declared in its
	// `/player` response (cached with the URL, so a cache hit still has them); a local file is read
	// from disk when the window opens, so it has a sample rate and bit depth where a stream has
	// YouTube's quality label. The source row carries the action its path implies: open the YouTube
	// page in the browser, or reveal the file in Explorer.
	import * as Dialog from '$lib/components/ui/dialog';
	import { HugeiconsIcon } from '@hugeicons/svelte';
	import { ExternalLinkIcon, FolderOpenIcon } from '@hugeicons/core-free-icons';
	import * as api from '$lib/api';
	import { playback, ui } from '$lib/player.svelte';
	import { t } from '$lib/i18n.svelte';

	let info = $state<api.TrackInfo | null>(null);

	// Reload when the window opens, and again if the track changes under it. `videoId` is the only
	// dependency that matters: the payload is keyed on it.
	$effect(() => {
		if (!ui.trackInfoOpen) return;
		const id = playback.now?.videoId;
		if (!id) return;
		let cancelled = false;
		api
			.trackInfo(id)
			.then((r) => {
				if (!cancelled) info = r;
			})
			.catch(() => {
				if (!cancelled) info = null;
			});
		return () => {
			cancelled = true;
		};
	});

	/** The page for the current track. A local file's id is `LOCAL:<path>`, so it has none. */
	const youtubeUrl = $derived(
		playback.now && !api.isLocalId(playback.now.videoId)
			? `https://music.youtube.com/watch?v=${playback.now.videoId}`
			: null
	);

	/** The path to show in the source row: the file on disk, or the page the link button opens. */
	const source = $derived(info?.path ?? youtubeUrl);

	const mmss = (s: number | null | undefined) => {
		if (!s || !Number.isFinite(s) || s <= 0) return null;
		return `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
	};

	/** YouTube's raw `AUDIO_QUALITY_*` as a label; anything unrecognised is shown as it came. */
	const quality = (raw: string | null) => {
		if (!raw) return null;
		const k = raw.toLowerCase();
		if (k.includes('high')) return t('dialogs.track_info.quality_high');
		if (k.includes('medium')) return t('dialogs.track_info.quality_medium');
		if (k.includes('low')) return t('dialogs.track_info.quality_low');
		return raw;
	};

	/** 44100 -> "44.1 kHz"; a whole-kHz rate keeps no decimal. */
	const khz = (hz: number | null) =>
		hz ? `${(hz / 1000).toFixed(hz % 1000 === 0 ? 0 : 1)} kHz` : null;

	const rows = $derived.by(() => {
		const now = playback.now;
		if (!now) return [] as [string, string | null | undefined][];
		const out: [string, string | null | undefined][] = [
			[t('dialogs.track_info.field_title'), now.title],
			[t('dialogs.track_info.field_artists'), now.artists],
			[t('dialogs.track_info.field_album'), now.album],
			[
				t('dialogs.track_info.field_duration'),
				mmss(playback.duration) ?? now.duration ?? null
			],
			[
				t('dialogs.track_info.field_bitrate'),
				info?.bitrateKbps ? `${info.bitrateKbps} kbps` : null
			],
			[t('dialogs.track_info.field_codec'), info?.codec ?? null]
		];
		// The one row the two sources disagree on: a stream has YouTube's own quality label, a local
		// file has the numbers that actually describe it.
		if (info?.local) {
			out.push([t('dialogs.track_info.field_sample_rate'), khz(info.sampleRate)]);
			out.push([
				t('dialogs.track_info.field_bit_depth'),
				info.bitDepth ? `${info.bitDepth}-bit` : null
			]);
		} else {
			out.push([t('dialogs.track_info.field_quality'), quality(info?.audioQuality ?? null)]);
		}
		out.push([t('dialogs.track_info.field_channels'), info?.channels ? `${info.channels}` : null]);
		return out;
	});
</script>

<Dialog.Root bind:open={ui.trackInfoOpen}>
	<Dialog.Content class="sm:max-w-lg">
		<Dialog.Header>
			<Dialog.Title>{t('dialogs.track_info.title')}</Dialog.Title>
			<Dialog.Description>{t('dialogs.track_info.desc')}</Dialog.Description>
		</Dialog.Header>

		<dl>
			{#each rows as [label, value] (label)}
				<div class="grid grid-cols-[9rem_1fr] items-start gap-4 border-b py-2">
					<dt class="text-sm text-muted-foreground">{label}</dt>
					<!-- An unknown field reads as a dash rather than a missing row: the list keeps its
					     shape, which is the point of a details panel. -->
					<dd class="min-w-0 break-words text-sm {value ? '' : 'text-muted-foreground'}">
						{value ?? '—'}
					</dd>
				</div>
			{/each}

			<div class="grid grid-cols-[9rem_1fr] items-start gap-4 py-2">
				<dt class="text-sm text-muted-foreground">{t('dialogs.track_info.field_source')}</dt>
				<dd class="flex min-w-0 items-center gap-2">
					<span class="min-w-0 break-all font-mono text-xs">{source ?? '—'}</span>
					{#if info?.local && info.path}
						<button
							type="button"
							class="shrink-0 rounded-md p-1 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
							title={t('dialogs.track_info.open_folder')}
							aria-label={t('dialogs.track_info.open_folder')}
							onclick={() => info?.path && api.revealInFolder(info.path)}
						>
							<HugeiconsIcon icon={FolderOpenIcon} size={15} />
						</button>
					{:else if youtubeUrl}
						<button
							type="button"
							class="shrink-0 rounded-md p-1 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
							title={t('dialogs.track_info.open_link')}
							aria-label={t('dialogs.track_info.open_link')}
							onclick={() => api.openExternal(youtubeUrl)}
						>
							<HugeiconsIcon icon={ExternalLinkIcon} size={15} />
						</button>
					{/if}
				</dd>
			</div>
		</dl>
	</Dialog.Content>
</Dialog.Root>
