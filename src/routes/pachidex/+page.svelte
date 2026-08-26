<script lang="ts">
	import { onMount } from 'svelte';
	import { caricaDex, mieCatture, type MiaVoce } from '$lib/db/dex';
	import { caricaSet, type SetConStato } from '$lib/db/set';
	import { CATEGORIE, RARITA, etichettaRarita } from '$lib/game/rules';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import CardDex from '$lib/components/CardDex.svelte';
	import SchedaElemento from '$lib/components/SchedaElemento.svelte';
	import Foglio from '$lib/components/Foglio.svelte';
	import type { Categoria, Rarita, VoceDex } from '$lib/types';

	let voci = $state<VoceDex[]>([]);
	let sets = $state<SetConStato[]>([]);
	let mie = $state<Map<string, MiaVoce>>(new Map());
	let scheda = $state<VoceDex | null>(null);
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);

	/* --- filtri ------------------------------------------------------------ */
	/** null = tutte le categorie. */
	let categoria = $state<Categoria | null>(null);
	let cerca = $state('');
	let rarita = $state<Rarita[]>([]);
	let possesso = $state<'tutti' | 'presi' | 'mancanti'>('tutti');
	let soloRipetibili = $state(false);
	let soloGps = $state(false);
	let foglioFiltri = $state(false);

	/** Accenti via: cercare "attivita" deve trovare "attività". */
	const piatto = (t: string) =>
		t
			.toLowerCase()
			.normalize('NFD')
			.replace(/[\u0300-\u036f]/g, '');

	const preso = (v: VoceDex) => mie.has(v.item_id);

	/** Quanti filtri sono accesi, categoria e ricerca esclusi: sono gia' visibili. */
	const quantiFiltri = $derived(
		rarita.length + (possesso !== 'tutti' ? 1 : 0) + (soloRipetibili ? 1 : 0) + (soloGps ? 1 : 0)
	);

	const visibili = $derived.by(() => {
		const q = piatto(cerca.trim());
		return voci.filter((v) => {
			if (categoria && v.categoria !== categoria) return false;
			if (q && !piatto(v.nome).includes(q)) return false;
			if (rarita.length && !rarita.includes(v.rarita)) return false;
			if (possesso === 'presi' && !preso(v)) return false;
			if (possesso === 'mancanti' && preso(v)) return false;
			if (soloRipetibili && !v.ripetibile) return false;
			if (soloGps && v.validazione !== 'foto_gps') return false;
			return true;
		});
	});

	const totali = $derived(voci.length);
	const sbloccati = $derived(voci.filter(preso).length);
	const sbloccatiVisibili = $derived(visibili.filter(preso).length);

	// I contatori sulle linguette restano assoluti: se cambiassero con gli altri
	// filtri non sarebbero piu' un riferimento su quanto manca davvero.
	function contaCategoria(c: Categoria) {
		const tutti = voci.filter((v) => v.categoria === c);
		return { presi: tutti.filter(preso).length, totali: tutti.length };
	}

	function alternaRarita(r: Rarita) {
		rarita = rarita.includes(r) ? rarita.filter((x) => x !== r) : [...rarita, r];
	}

	function azzeraFiltri() {
		rarita = [];
		possesso = 'tutti';
		soloRipetibili = false;
		soloGps = false;
	}

	function azzeraTutto() {
		categoria = null;
		cerca = '';
		azzeraFiltri();
	}

	async function carica() {
		try {
			voci = await caricaDex();
			if (profilo.io) mie = await mieCatture(profilo.io.id);
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
			return;
		}

		// I set stanno nella loro pagina: qui basta il contatore che ci porta.
		// Se non arrivano si tace, non e' un motivo per rovinare il PachiDex.
		try {
			sets = await caricaSet(profilo.io?.id ?? null);
		} catch {
			sets = [];
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

	<!-- Le categorie non sono piu' navigazione esclusiva ma un filtro:
	     ritoccarne una accesa la spegne, e il pulsante sotto le azzera. -->
	<nav class="tabs" aria-label="Categorie">
		{#each CATEGORIE as c (c.valore)}
			{@const n = contaCategoria(c.valore)}
			<button
				class="tab"
				class:tab--attiva={categoria === c.valore}
				style:--tinta="var(--cat-{c.valore})"
				aria-pressed={categoria === c.valore}
				onclick={() => (categoria = categoria === c.valore ? null : c.valore)}
			>
				<span aria-hidden="true">{c.icona}</span>
				<span class="tab__nome">{c.plurale}</span>
				<span class="tab__conta t-num">{n.presi}/{n.totali}</span>
			</button>
		{/each}
	</nav>

	<button
		class="btn btn--sm tutte"
		class:tutte--attiva={categoria === null}
		onclick={() => (categoria = null)}
	>
		Tutte le sfiziosità
	</button>

	{#if sets.length}
		<a class="ai-set" href="/set">
			<span class="grow">
				<span class="ai-set__nome t-label">I set</span>
				<span class="ai-set__spiega t-small">Gruppi che valgono un premio doppio</span>
			</span>
			<span class="ai-set__conta t-num">
				{sets.filter((s) => s.completo).length}/{sets.length}
			</span>
			<span class="ai-set__freccia" aria-hidden="true">▸</span>
		</a>
	{/if}

	<div class="cerca">
		<input
			class="field grow"
			type="search"
			enterkeyhint="search"
			autocapitalize="none"
			bind:value={cerca}
			placeholder="Cerca per nome…"
			aria-label="Cerca fra le sfiziosità"
		/>
		<button class="btn btn--sm filtri" onclick={() => (foglioFiltri = true)}>
			Filtri
			{#if quantiFiltri}<span class="pallino t-num">{quantiFiltri}</span>{/if}
		</button>
	</div>

	{#if quantiFiltri}
		<!-- Cio' che e' acceso resta in vista: un filtro dimenticato dentro il
		     foglio fa sembrare il Dex vuoto senza spiegare perche'. -->
		<div class="attivi">
			{#each rarita as r (r)}
				<button class="chip" onclick={() => alternaRarita(r)}>
					{etichettaRarita(r)} <span aria-hidden="true">×</span>
				</button>
			{/each}
			{#if possesso !== 'tutti'}
				<button class="chip" onclick={() => (possesso = 'tutti')}>
					{possesso === 'presi' ? 'Solo presi' : 'Solo mancanti'} <span aria-hidden="true">×</span>
				</button>
			{/if}
			{#if soloRipetibili}
				<button class="chip" onclick={() => (soloRipetibili = false)}>
					Ripetibili <span aria-hidden="true">×</span>
				</button>
			{/if}
			{#if soloGps}
				<button class="chip" onclick={() => (soloGps = false)}>
					Checkpoint GPS <span aria-hidden="true">×</span>
				</button>
			{/if}
		</div>
	{/if}

	{#if stato === 'carico'}
		<div class="griglia">
			{#each [1, 2, 3, 4, 5, 6] as n (n)}
				<div class="finta skeleton"></div>
			{/each}
		</div>
	{:else if stato === 'errore'}
		<p class="empty t-small">{errore}</p>
	{:else if !voci.length}
		<div class="empty">
			<p><strong>Il PachiDex è vuoto.</strong></p>
			<p class="t-small">Gli elementi li carica l'admin dal pannello.</p>
		</div>
	{:else if !visibili.length}
		<div class="empty">
			<p><strong>Niente con questi filtri.</strong></p>
			<p class="t-small">Prova ad allargare la ricerca.</p>
			<button class="btn btn--sm azzera" onclick={azzeraTutto}>Azzera tutto</button>
		</div>
	{:else}
		<p class="progresso t-small t-muted">
			{sbloccatiVisibili} su {visibili.length}
			{visibili.length === totali ? 'in tutto il PachiDex' : 'fra questi'}
		</p>
		<div class="griglia">
			{#each visibili as v (v.item_id)}
				<CardDex voce={v} mia={mie.get(v.item_id)} onApri={(x) => (scheda = x)} />
			{/each}
		</div>
	{/if}
</div>

<Foglio
	aperto={foglioFiltri}
	titolo="Filtri"
	variante="navy"
	onChiudi={() => (foglioFiltri = false)}
>
	<div class="stack">
		<div>
			<p class="field-label">Rarità</p>
			<div class="scelte">
				{#each RARITA as r (r.valore)}
					<button
						class="scelta"
						class:scelta--on={rarita.includes(r.valore)}
						style:--tinta="var(--rarity-{r.valore})"
						onclick={() => alternaRarita(r.valore)}
					>
						{r.label}
					</button>
				{/each}
			</div>
		</div>

		<div>
			<p class="field-label">Cosa mostro</p>
			<div class="scelte">
				{#each [['tutti', 'Tutti'], ['mancanti', 'Solo mancanti'], ['presi', 'Solo presi']] as [v, l] (v)}
					<button
						class="scelta"
						class:scelta--on={possesso === v}
						onclick={() => (possesso = v as typeof possesso)}
					>
						{l}
					</button>
				{/each}
			</div>
		</div>

		<label class="check">
			<input type="checkbox" bind:checked={soloRipetibili} />
			<span>Solo ripetibili — quelli che si rifanno all'infinito</span>
		</label>

		<label class="check">
			<input type="checkbox" bind:checked={soloGps} />
			<span>Solo checkpoint GPS — dove bisogna esserci davvero</span>
		</label>

		<p class="t-small t-muted">
			{visibili.length}
			{visibili.length === 1 ? 'sfiziosità' : 'sfiziosità'} con questi filtri.
		</p>

		<div class="due">
			<button class="btn" onclick={azzeraFiltri} disabled={!quantiFiltri}>Azzera</button>
			<button class="btn btn--primary" onclick={() => (foglioFiltri = false)}>Vedi</button>
		</div>
	</div>
</Foglio>

<SchedaElemento voce={scheda} onChiudi={() => (scheda = null)} />

<style>
	/* Il richiamo ai set: sta nel PachiDex perche' e' li' che uno guarda cosa
	   gli manca, ma la bacheca vera ha una pagina sua — nove schede in cima
	   alla griglia l'avrebbero spinta fuori schermo. */
	.ai-set {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--navy);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
		color: var(--paper);
		text-decoration: none;
	}

	.ai-set:active {
		transform: translate(3px, 3px);
		box-shadow: none;
	}

	.ai-set__nome {
		display: block;
		color: var(--yellow);
	}

	.ai-set__spiega {
		display: block;
		color: rgba(247, 243, 232, 0.72);
	}

	.ai-set__conta {
		font-weight: 700;
		font-size: 1.0625rem;
		color: var(--yellow);
	}

	.ai-set__freccia {
		color: var(--orange);
	}

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

	/* Il pulsante che annulla il filtro di categoria: a tutta larghezza
	   perche' e' l'uscita di sicurezza da qualunque selezione. */
	.tutte {
		width: 100%;
		margin-bottom: var(--space-2);
	}

	.tutte--attiva {
		background: var(--navy);
		color: var(--paper);
		box-shadow: none;
		transform: translate(2px, 2px);
	}

	.cerca {
		display: flex;
		gap: var(--space-2);
		margin-bottom: var(--space-2);
	}

	.filtri {
		flex-shrink: 0;
		display: inline-flex;
		align-items: center;
		gap: 5px;
	}

	.pallino {
		display: grid;
		place-items: center;
		min-width: 17px;
		height: 17px;
		padding: 0 3px;
		background: var(--orange);
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.625rem;
	}

	.attivi {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
		margin-bottom: var(--space-2);
	}

	.chip {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 2px 6px;
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.6875rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		cursor: pointer;
	}

	.scelte {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.scelta {
		padding: 7px var(--space-3);
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.8125rem;
		font-weight: 700;
		cursor: pointer;
	}

	.scelta--on {
		background: var(--tinta, var(--orange));
		color: var(--paper);
		border-width: var(--border);
		box-shadow: inset 2px 2px 0 rgba(22, 27, 61, 0.3);
	}

	.check {
		display: flex;
		gap: var(--space-2);
		align-items: flex-start;
		font-size: 0.875rem;
	}

	.check input {
		width: 20px;
		height: 20px;
		accent-color: var(--orange);
		flex-shrink: 0;
	}

	.due {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2);
	}

	.azzera {
		margin-top: var(--space-3);
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
