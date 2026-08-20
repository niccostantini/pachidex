<script lang="ts">
	import { onMount } from 'svelte';
	import { caricaDex, mieCatture, type MiaVoce } from '$lib/db/dex';
	import { CATEGORIE } from '$lib/game/rules';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import CardDex from '$lib/components/CardDex.svelte';
	import type { Categoria, VoceDex } from '$lib/types';

	let voci = $state<VoceDex[]>([]);
	let mie = $state<Map<string, MiaVoce>>(new Map());
	let tab = $state<Categoria>('posto');
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);

	const dellaCategoria = $derived(voci.filter((v) => v.categoria === tab));
	const sbloccatiQui = $derived(dellaCategoria.filter((v) => mie.has(v.item_id)).length);
	const totali = $derived(voci.length);
	const sbloccati = $derived(voci.filter((v) => mie.has(v.item_id)).length);

	function contaCategoria(c: Categoria) {
		const tutti = voci.filter((v) => v.categoria === c);
		return { presi: tutti.filter((v) => mie.has(v.item_id)).length, totali: tutti.length };
	}

	async function carica() {
		try {
			voci = await caricaDex();
			if (profilo.io) mie = await mieCatture(profilo.io.id);
			// Si apre sulla categoria che ha davvero qualcosa dentro.
			const prima = CATEGORIE.find((c) => voci.some((v) => v.categoria === c.valore));
			if (prima) tab = prima.valore;
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
		}
	}

	onMount(carica);
</script>

<svelte:head><title>PachiDex — Pachino Express</title></svelte:head>

<div class="dex">
	<div class="dex__testa">
		<h1>PachiDex</h1>
		<p class="t-label t-muted">{sbloccati} / {totali} sbloccati</p>
	</div>

	<nav class="tabs" aria-label="Categorie">
		{#each CATEGORIE as c (c.valore)}
			{@const n = contaCategoria(c.valore)}
			<button
				class="tab"
				class:tab--attiva={tab === c.valore}
				style:--tinta="var(--cat-{c.valore})"
				onclick={() => (tab = c.valore)}
			>
				<span aria-hidden="true">{c.icona}</span>
				<span class="tab__nome">{c.plurale}</span>
				<span class="tab__conta t-num">{n.presi}/{n.totali}</span>
			</button>
		{/each}
	</nav>

	{#if stato === 'carico'}
		<div class="griglia">
			{#each [1, 2, 3, 4, 5, 6] as n (n)}
				<div class="finta skeleton"></div>
			{/each}
		</div>
	{:else if stato === 'errore'}
		<p class="empty t-small">{errore}</p>
	{:else if !dellaCategoria.length}
		<div class="empty">
			<p><strong>Niente in questa categoria.</strong></p>
			<p class="t-small">Gli elementi li carica l'admin dal pannello.</p>
		</div>
	{:else}
		<p class="progresso t-small t-muted">
			{sbloccatiQui} su {dellaCategoria.length} in questa categoria
		</p>
		<div class="griglia">
			{#each dellaCategoria as v (v.item_id)}
				<CardDex voce={v} mia={mie.get(v.item_id)} />
			{/each}
		</div>
	{/if}
</div>

<style>
	.dex {
		padding: var(--space-3);
	}

	.dex__testa {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		margin-bottom: var(--space-3);
	}

	.tabs {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 3px;
		margin-bottom: var(--space-3);
	}

	.tab {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1px;
		padding: 5px 2px;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		cursor: pointer;
		font-size: 0.6875rem;
		-webkit-tap-highlight-color: transparent;
	}

	.tab--attiva {
		background: var(--tinta);
		color: var(--paper);
		box-shadow: inset 2px 2px 0 rgba(22, 27, 61, 0.35);
	}

	.tab__nome {
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		font-size: 0.5625rem;
	}

	.tab__conta {
		font-weight: 700;
	}

	.progresso {
		margin-bottom: var(--space-2);
	}

	.griglia {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(104px, 1fr));
		gap: var(--space-2);
	}

	.finta {
		aspect-ratio: 3 / 4;
		border: var(--border) solid var(--navy);
	}
</style>
