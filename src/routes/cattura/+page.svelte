<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { caricaDex, caricaConfig, mieCatture, type MiaVoce } from '$lib/db/dex';
	import { checkpointVicini, formattaDistanza, posizioneAttuale, type Posizione } from '$lib/game/geo';
	import { comprimiFoto, anteprima } from '$lib/game/image';
	import { CATEGORIE, etichettaCategoria } from '$lib/game/rules';
	import { profilo } from '$lib/state/profilo.svelte';
	import { coda } from '$lib/state/coda.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';
	import Rarita from '$lib/components/Rarita.svelte';
	import type { VoceDex } from '$lib/types';

	let voci = $state<VoceDex[]>([]);
	let mie = $state<Map<string, MiaVoce>>(new Map());
	let config = $state<Record<string, number>>({});
	let pos = $state<Posizione | null>(null);
	let erroreGps = $state<string | null>(null);
	let caricamento = $state(true);

	let scelta = $state<VoceDex | null>(null);
	let cerca = $state('');
	let nota = $state('');
	let file = $state<File | null>(null);
	let urlAnteprima = $state<string | null>(null);
	let inInvio = $state(false);
	let errore = $state<string | null>(null);

	const raggio = $derived(config.raggio_gps_metri ?? 100);

	const vicini = $derived(pos ? checkpointVicini(voci, pos, raggio) : []);
	const dentroRaggio = $derived(vicini.filter((v) => v.dentro));

	/** Un item non ripetibile gia' preso non si ripropone. */
	function giaPresa(v: VoceDex) {
		return !v.ripetibile && mie.has(v.item_id);
	}

	const risultati = $derived.by(() => {
		const q = cerca.trim().toLowerCase();
		return voci
			.filter((v) => v.validazione === 'foto')
			.filter((v) => !q || v.nome.toLowerCase().includes(q))
			.sort((a, b) => {
				const ga = giaPresa(a) ? 1 : 0;
				const gb = giaPresa(b) ? 1 : 0;
				return ga - gb || a.nome.localeCompare(b.nome);
			})
			.slice(0, 40);
	});

	onMount(async () => {
		try {
			const [d, c] = await Promise.all([caricaDex(), caricaConfig()]);
			voci = d;
			config = c;
			if (profilo.io) mie = await mieCatture(profilo.io.id);
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricamento = false;
		}

		try {
			pos = await posizioneAttuale();
		} catch (e) {
			erroreGps = e instanceof Error ? e.message : String(e);
		}
	});

	// Un checkpoint a portata si preseleziona da solo: e' il caso piu' comune
	// ed evita di far cercare a mano una cosa che il telefono gia' sa.
	$effect(() => {
		if (!scelta && dentroRaggio.length) scelta = dentroRaggio[0].voce;
	});

	function scegliFoto(e: Event) {
		const input = e.currentTarget as HTMLInputElement;
		const f = input.files?.[0];
		if (!f) return;
		file = f;
		if (urlAnteprima) URL.revokeObjectURL(urlAnteprima);
		urlAnteprima = anteprima(f);
	}

	async function pubblica() {
		if (!scelta || !file || !profilo.io) return;
		inInvio = true;
		errore = null;
		try {
			const pronta = await comprimiFoto(file);
			await coda.accoda({
				userId: profilo.io.id,
				itemId: scelta.item_id,
				nomeItem: scelta.nome,
				blob: pronta.blob,
				estensione: pronta.estensione,
				nota: nota.trim() || null,
				lat: pos?.lat ?? null,
				lng: pos?.lng ?? null
			});
			// Si torna subito al feed: se la rete manca, la coda ci pensa dopo.
			await goto('/');
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			inInvio = false;
		}
	}
</script>

<svelte:head><title>Cattura — Pachino Express</title></svelte:head>

<div class="cattura stack">
	<Finestra titolo="Nuova cattura" onChiudi={() => goto('/')}>
		<div class="stack">
			<!-- 1. La foto -->
			<label class="scatta" class:scatta--piena={!!urlAnteprima}>
				{#if urlAnteprima}
					<img class="photo" src={urlAnteprima} alt="Anteprima" />
					<span class="scatta__cambia btn btn--sm">Rifai</span>
				{:else}
					<span class="scatta__icona" aria-hidden="true">◉</span>
					<span class="t-label">Apri la fotocamera</span>
				{/if}
				<input
					type="file"
					accept="image/*"
					capture="environment"
					onchange={scegliFoto}
					class="visually-hidden"
				/>
			</label>

			<!-- 2. Cosa hai catturato -->
			{#if caricamento}
				<p class="t-label t-muted">Carico gli elementi…</p>
			{:else if scelta}
				<div class="scelta">
					<div class="grow">
						<p class="t-label t-muted">{etichettaCategoria(scelta.categoria)}</p>
						<p class="scelta__nome">{scelta.nome}</p>
						<Rarita rarita={scelta.rarita} croquembouche={scelta.croquembouche} />
					</div>
					<button class="btn btn--sm" onclick={() => ((scelta = null), (cerca = ''))}>
						Cambia
					</button>
				</div>

				{#if scelta.validazione === 'foto_gps'}
					<p class="gps-ok t-small">
						Checkpoint: il GPS conferma che sei qui, ma la foto serve lo stesso — e
						resta contestabile come tutte le altre.
					</p>
				{/if}
			{:else}
				<div class="field-row">
					<label class="field-label" for="cerca">Cosa hai catturato?</label>
					<input
						id="cerca"
						class="field"
						type="search"
						bind:value={cerca}
						placeholder="Cerca fra le sfiziosita'…"
					/>
				</div>

				{#if !voci.length}
					<p class="t-small t-muted">
						Il PachiDex e' ancora vuoto. Deve caricarlo l'admin dal pannello.
					</p>
				{:else}
					<ul class="risultati">
						{#each risultati as v (v.item_id)}
							<li>
								<button
									class="risultato"
									disabled={giaPresa(v)}
									onclick={() => (scelta = v)}
								>
									<span class="cat" style:background="var(--cat-{v.categoria})">
										{CATEGORIE.find((c) => c.valore === v.categoria)?.icona}
									</span>
									<span class="grow">
										{v.nome}
										{#if giaPresa(v)}<span class="t-small t-muted"> — gia' preso</span>{/if}
									</span>
									<Rarita rarita={v.rarita} croquembouche={v.croquembouche} />
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			{/if}

			<!-- 3. Due parole -->
			<div class="field-row">
				<label class="field-label" for="nota">Didascalia (facoltativa)</label>
				<input id="nota" class="field" bind:value={nota} maxlength="180" placeholder="Due parole" />
			</div>

			{#if errore}
				<p class="errore t-small">{errore}</p>
			{/if}

			<button
				class="btn btn--primary btn--lg btn--block"
				disabled={!scelta || !file || inInvio}
				onclick={pubblica}
			>
				{inInvio ? 'Pubblico…' : 'Cattura'}
			</button>

			{#if !coda.online}
				<p class="t-small t-muted">
					Sei offline: la cattura resta in coda e parte da sola appena torna la rete.
				</p>
			{/if}
		</div>
	</Finestra>

	<!-- Checkpoint intorno -->
	<Finestra titolo="Checkpoint intorno a te" variante="blue">
		{#if erroreGps}
			<p class="t-small t-muted">{erroreGps}</p>
			<p class="t-small t-muted">Senza posizione puoi comunque catturare tutto il resto.</p>
		{:else if !pos}
			<p class="t-label t-muted">Cerco il satellite…</p>
		{:else if !vicini.length}
			<p class="t-small t-muted">Nessun checkpoint GPS caricato.</p>
		{:else}
			<ul class="vicini">
				{#each vicini.slice(0, 5) as v (v.voce.item_id)}
					<li class="vicino" class:vicino--dentro={v.dentro}>
						<span class="grow">{v.voce.nome}</span>
						<span class="t-num t-small">{formattaDistanza(v.distanza)}</span>
						{#if v.dentro}
							<button class="btn btn--sm btn--ok" onclick={() => (scelta = v.voce)}>
								Sei qui
							</button>
						{/if}
					</li>
				{/each}
			</ul>
			<p class="t-small t-muted">
				Serve stare entro {raggio} m. Precisione attuale: ±{Math.round(pos.precisione)} m.
			</p>
		{/if}
	</Finestra>
</div>

<style>
	.cattura {
		padding: var(--space-3);
	}

	.scatta {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		min-height: 180px;
		padding: var(--space-4);
		background: var(--cream);
		border: var(--border) dashed var(--navy);
		cursor: pointer;
		position: relative;
	}

	.scatta--piena {
		padding: 0;
		border-style: solid;
	}

	.scatta__icona {
		font-size: 2.5rem;
		line-height: 1;
	}

	.scatta__cambia {
		position: absolute;
		right: var(--space-2);
		bottom: var(--space-2);
	}

	.scelta {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		background: var(--cream);
		border: var(--border) solid var(--navy);
		padding: var(--space-2);
	}

	.scelta__nome {
		font-size: 1.125rem;
		font-weight: 700;
	}

	.gps-ok {
		background: rgba(53, 183, 154, 0.22);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
	}

	.risultati {
		max-height: 42dvh;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 4px;
		border: var(--border-thin) solid rgba(22, 27, 61, 0.25);
		padding: 4px;
	}

	.risultato {
		width: 100%;
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: 6px;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		text-align: left;
		cursor: pointer;
		font-size: 0.9375rem;
	}

	.risultato:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.risultato:active:not(:disabled) {
		background: var(--cream);
	}

	.cat {
		width: 22px;
		height: 22px;
		display: grid;
		place-items: center;
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		flex-shrink: 0;
	}

	.vicini {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-bottom: var(--space-2);
	}

	.vicino {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: 5px var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.9375rem;
	}

	.vicino--dentro {
		background: rgba(53, 183, 154, 0.28);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
