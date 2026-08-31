<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { catturePersona } from '$lib/db/feed';
	import { caricaClassifica } from '$lib/db/dex';
	import { caricaTitoli, TITOLI, type VoceTitolo } from '$lib/db/titoli';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import CardCattura from '$lib/components/CardCattura.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import type { PostCattura, RigaClassifica } from '$lib/types';

	const id = $derived(page.params.id as string);
	const persona = $derived(profilo.utenti.find((u) => u.id === id) ?? null);
	const sonoIo = $derived(id === profilo.io?.id);

	let suoi = $state<PostCattura[]>([]);
	let taggata = $state<PostCattura[]>([]);
	let righe = $state<RigaClassifica[]>([]);
	let titoli = $state<VoceTitolo[]>([]);
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);
	let scheda = $state<'suoi' | 'taggata'>('suoi');

	const riga = $derived(righe.find((r) => r.user_id === id) ?? null);
	const suoiTitoli = $derived(
		titoli
			.filter((t) => t.user_id === id)
			.map((t) => TITOLI.find((x) => x.titolo === t.titolo))
			.filter((x) => x !== undefined)
	);

	const elenco = $derived(scheda === 'suoi' ? suoi : taggata);

	// Il profilo si ricarica cambiando persona: si passa da un nome all'altro
	// senza tornare al feed, e le liste non devono restare quelle di prima.
	$effect(() => {
		void id;
		void carica();
	});

	async function carica() {
		stato = 'carico';
		scheda = 'suoi';
		try {
			const esito = await catturePersona(id, profilo.io?.id ?? null);
			suoi = esito.suoi;
			taggata = esito.taggata;
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
			return;
		}

		// Numeri e titoli sono contorno: se non arrivano, il feed resta.
		try {
			[righe, titoli] = await Promise.all([caricaClassifica(), caricaTitoli()]);
		} catch {
			righe = [];
			titoli = [];
		}
	}

	onMount(() => {});
</script>

<svelte:head><title>{persona?.nome ?? 'Profilo'} — Pachino Express</title></svelte:head>

<div class="pr">
	{#if !persona && profilo.pronto}
		<Finestra titolo="Chi?" variante="navy" onChiudi={() => goto('/')}>
			<p class="t-small">Questa persona non gioca piu'.</p>
		</Finestra>
	{:else if persona}
		<div class="testa">
			<Avatar utente={persona} dimensione="lg" />
			<div class="grow">
				<h1>{persona.nome}</h1>
				<p class="t-small t-muted">@{persona.nome.toLowerCase()}</p>
			</div>
		</div>

		<div class="numeri">
			<div class="numero">
				<span class="t-num grande">{riga?.saldo ?? 0}</span>
				<span class="t-label t-muted">Croquembouche</span>
			</div>
			<div class="numero">
				<span class="t-num grande">{riga?.item_unici ?? 0}</span>
				<span class="t-label t-muted">pezzi</span>
			</div>
		</div>

		{#if suoiTitoli.length}
			<div class="titoli">
				{#each suoiTitoli as t (t.titolo)}
					<span class="targhetta t-label">{t.nome}</span>
				{/each}
			</div>
		{/if}

		<!-- Due schede come su Instagram: quello che ha fatto lei, e quello in
		     cui l'hanno messa gli altri. -->
		<div class="tabs">
			<button class="tabb" class:tabb--on={scheda === 'suoi'} onclick={() => (scheda = 'suoi')}>
				{sonoIo ? 'I miei post' : 'I suoi post'}
				<span class="t-num conta">{suoi.length}</span>
			</button>
			<button
				class="tabb"
				class:tabb--on={scheda === 'taggata'}
				onclick={() => (scheda = 'taggata')}
			>
				Dove compare
				<span class="t-num conta">{taggata.length}</span>
			</button>
		</div>

		{#if stato === 'carico'}
			<p class="t-label t-muted">Carico…</p>
		{:else if stato === 'errore'}
			<p class="t-small">{errore}</p>
		{:else if !elenco.length}
			<p class="vuoto t-small t-muted">
				{#if scheda === 'suoi'}
					Non ha ancora catturato niente.
				{:else}
					Nessuno l'ha ancora taggata in una sua foto.
				{/if}
			</p>
		{:else}
			<div class="lista">
				{#each elenco as post (post.id)}
					<CardCattura {post} />
				{/each}
			</div>
		{/if}
	{/if}
</div>

<style>
	.pr {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-3);
	}

	.testa {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	h1 {
		font-size: 1.375rem;
		line-height: 1.1;
	}

	.numeri {
		display: flex;
		gap: var(--space-4);
		padding: var(--space-2) var(--space-3);
		background: var(--navy);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
	}

	.numero {
		display: flex;
		flex-direction: column;
	}

	.grande {
		font-size: 1.5rem;
		font-weight: 700;
		color: var(--yellow);
		line-height: 1.1;
	}

	.numero .t-muted {
		color: rgba(247, 243, 232, 0.72);
	}

	.titoli {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.targhetta {
		background: var(--yellow);
		color: var(--navy);
		border: var(--border-thin) solid var(--navy);
		padding: 3px 7px;
	}

	.tabs {
		display: flex;
		gap: 0;
	}

	.tabb {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 5px;
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		cursor: pointer;
	}

	.tabb--on {
		background: var(--navy);
		color: var(--paper);
	}

	.conta {
		background: var(--orange);
		color: var(--paper);
		padding: 0 5px;
	}

	.lista {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.vuoto {
		padding: var(--space-4) 0;
		text-align: center;
	}
</style>
