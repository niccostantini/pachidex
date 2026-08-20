<script lang="ts">
	import { onMount } from 'svelte';
	import { caricaFeed, chiudiScadute, sottoscriviFeed } from '$lib/db/feed';
	import { caricaConfig } from '$lib/db/dex';
	import { apriContestazione } from '$lib/db/azioni';
	import { profilo } from '$lib/state/profilo.svelte';
	import { coda } from '$lib/state/coda.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import CardCattura from '$lib/components/CardCattura.svelte';
	import CardScambio from '$lib/components/CardScambio.svelte';
	import CardContestazione from '$lib/components/CardContestazione.svelte';
	import Foglio from '$lib/components/Foglio.svelte';
	import type { PostCattura, PostContestazione, PostFeed } from '$lib/types';

	let fissati = $state<PostContestazione[]>([]);
	let timeline = $state<PostFeed[]>([]);
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);
	let config = $state<Record<string, number>>({});

	// Contestazione in preparazione
	let daContestare = $state<PostCattura | null>(null);
	let motivo = $state('');
	let inInvio = $state(false);
	let erroreContesta = $state<string | null>(null);

	const costoContestazione = $derived(config.costo_apertura_contestazione ?? 1);
	const penalita = $derived(config.penalita_extra_contestazione ?? 15);

	async function carica() {
		try {
			const res = await caricaFeed(profilo.io?.id ?? null);
			fissati = res.fissati;
			timeline = res.timeline;
			stato = 'ok';
			void profilo.aggiornaSaldi();
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
		}
	}

	// Il realtime puo' arrivare a raffica (un voto tira l'altro): si accorpa.
	let attesa: ReturnType<typeof setTimeout> | undefined;
	function ricaricaMorbida() {
		clearTimeout(attesa);
		attesa = setTimeout(() => void carica(), 350);
	}

	onMount(() => {
		// Le scadenze si chiudono anche se il cron non c'e': basta che
		// qualcuno apra il feed.
		void chiudiScadute();
		void caricaConfig().then((c) => (config = c));
		const stop = sottoscriviFeed(ricaricaMorbida);
		return () => {
			clearTimeout(attesa);
			stop();
		};
	});

	// Una sola lettura all'avvio, e un'altra solo se cambia il profilo: i
	// "miei like" dipendono da chi sta guardando.
	$effect(() => {
		if (!profilo.pronto) return;
		void profilo.io?.id;
		void carica();
	});

	async function confermaContestazione() {
		if (!daContestare || !profilo.io) return;
		inInvio = true;
		erroreContesta = null;
		try {
			await apriContestazione(daContestare.id, profilo.io.id, motivo.trim() || undefined);
			daContestare = null;
			motivo = '';
			await carica();
		} catch (e) {
			erroreContesta = messaggioErrore(e);
		} finally {
			inInvio = false;
		}
	}
</script>

<svelte:head><title>Feed — Pachino Express</title></svelte:head>

<div class="feed stack">
	{#if coda.inAttesa.length}
		<div class="coda">
			<p class="t-label">
				{coda.inAttesa.length} cattur{coda.inAttesa.length === 1 ? 'a' : 'e'} in attesa di rete
			</p>
			<ul class="t-small">
				{#each coda.inAttesa as v (v.id)}
					<li>
						{v.nomeItem}
						{#if v.definitivo}
							<span class="badge badge--ko">rifiutata</span>
							<button class="btn btn--sm" onclick={() => coda.scarta(v.id)}>Butta</button>
						{:else}
							<span class="t-muted">in coda…</span>
						{/if}
						{#if v.ultimoErrore}
							<span class="t-muted"> — {v.ultimoErrore}</span>
						{/if}
					</li>
				{/each}
			</ul>
		</div>
	{/if}

	{#each fissati as c (c.id)}
		<CardContestazione post={c} onCambio={carica} />
	{/each}

	{#if stato === 'carico'}
		{#each [1, 2, 3] as n (n)}
			<div class="finto skeleton"></div>
		{/each}
	{:else if stato === 'errore'}
		<div class="win">
			<header class="win__bar win__bar--navy"><span class="win__title">Errore</span></header>
			<div class="win__body stack">
				<p class="t-small">{errore}</p>
				<button class="btn btn--sm" onclick={carica}>Riprova</button>
			</div>
		</div>
	{:else if !timeline.length}
		<div class="win">
			<header class="win__bar"><span class="win__title">Feed</span></header>
			<div class="win__body empty">
				<p><strong>Ancora niente.</strong></p>
				<p class="t-small">
					La vacanza comincia quando qualcuno fotografa la prima sfiziosita'.
				</p>
			</div>
		</div>
	{:else}
		{#each timeline as post (post.tipo + post.id)}
			{#if post.tipo === 'cattura'}
				<CardCattura {post} onContesta={(p) => ((daContestare = p), (motivo = ''))} />
			{:else if post.tipo === 'scambio'}
				<CardScambio {post} />
			{:else}
				<CardContestazione {post} onCambio={carica} />
			{/if}
		{/each}
	{/if}
</div>

<Foglio
	aperto={!!daContestare}
	titolo="Apri una contestazione"
	variante="navy"
	onChiudi={() => (daContestare = null)}
>
	{#if daContestare}
		<div class="stack">
			<p class="t-small">
				Stai per contestare <strong>{daContestare.item.nome}</strong> di
				<strong>{daContestare.autore.nome}</strong>.
			</p>

			<div class="regole">
				<p class="t-small">
					Aprire costa <strong>✦ {costoContestazione}</strong>, comunque vada.
				</p>
				<p class="t-small">
					Se il gruppo ti da' torto, ne perdi altri <strong>✦ {penalita}</strong>.
				</p>
				<p class="t-small t-muted">
					Il tuo voto "non valida" e' automatico. Hai {config.durata_contestazione_ore ?? 24} ore.
				</p>
			</div>

			<div class="field-row">
				<label class="field-label" for="motivo">Perche'? (facoltativo)</label>
				<textarea
					id="motivo"
					class="field"
					rows="3"
					bind:value={motivo}
					placeholder="Quella non è una granita, è un ghiacciolo sciolto"
				></textarea>
			</div>

			{#if erroreContesta}
				<p class="t-small errore">{erroreContesta}</p>
			{/if}

			<div class="azioni">
				<button class="btn grow" onclick={() => (daContestare = null)}>Lascia stare</button>
				<button class="btn btn--danger grow" onclick={confermaContestazione} disabled={inInvio}>
					{inInvio ? 'Apro…' : 'Contesta'}
				</button>
			</div>
		</div>
	{/if}
</Foglio>

<style>
	.feed {
		padding: var(--space-3);
	}

	.finto {
		height: 240px;
		border: var(--border) solid var(--navy);
	}

	.coda {
		background: var(--yellow);
		border: var(--border) solid var(--navy);
		padding: var(--space-2);
	}

	.coda ul {
		margin-top: 4px;
	}

	.regole {
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
	}

	.azioni {
		display: flex;
		gap: var(--space-2);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
