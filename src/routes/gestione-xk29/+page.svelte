<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase, messaggioErrore } from '$lib/supabase';
	import { caricaConfig } from '$lib/db/dex';
	import { azzeraGioco, type RigaAzzerata } from '$lib/db/admin';
	import Finestra from '$lib/components/Finestra.svelte';
	import Foglio from '$lib/components/Foglio.svelte';

	let numeri = $state({ item: 0, attivi: 0, catture: 0, aperte: 0, scambi: 0 });
	let config = $state<Record<string, number>>({});
	let pronto = $state(false);

	// --- azzeramento -------------------------------------------------------
	const PAROLA = 'RICOMINCIA';
	let chiedeReset = $state(false);
	let parolaScritta = $state('');
	let inAzzeramento = $state(false);
	let esitoReset = $state<RigaAzzerata[] | null>(null);
	let erroreReset = $state<string | null>(null);

	const parolaGiusta = $derived(parolaScritta.trim().toUpperCase() === PAROLA);
	const daButtare = $derived(numeri.item + numeri.catture + numeri.scambi);

	async function conta(tabella: string, filtro?: [string, string]) {
		let q = supabase.from(tabella).select('*', { count: 'exact', head: true });
		if (filtro) q = q.eq(filtro[0], filtro[1]);
		const { count } = await q;
		return count ?? 0;
	}

	async function rileggi() {
		const [item, attivi, catture, aperte, scambi, cfg] = await Promise.all([
			conta('items'),
			conta('items', ['attivo', 'true']),
			conta('captures'),
			conta('contests', ['stato', 'aperta']),
			conta('transfers'),
			caricaConfig()
		]);
		numeri = { item, attivi, catture, aperte, scambi };
		config = cfg;
		pronto = true;
	}

	onMount(rileggi);

	function apriReset() {
		parolaScritta = '';
		esitoReset = null;
		erroreReset = null;
		chiedeReset = true;
	}

	async function confermaReset() {
		if (!parolaGiusta || inAzzeramento) return;
		inAzzeramento = true;
		erroreReset = null;
		try {
			esitoReset = await azzeraGioco();
			await rileggi();
		} catch (e) {
			erroreReset = messaggioErrore(e);
		} finally {
			inAzzeramento = false;
		}
	}
</script>

<div class="stack">
	<Finestra titolo="Come va la vacanza" variante="navy">
		{#if !pronto}
			<p class="t-label t-muted">Conto…</p>
		{:else}
			<div class="numeri">
				<div class="n">
					<span class="n__v t-num">{numeri.attivi}</span>
					<span class="t-label">sfiziosita attive</span>
					{#if numeri.item !== numeri.attivi}
						<span class="t-small t-muted">{numeri.item - numeri.attivi} disattivate</span>
					{/if}
				</div>
				<div class="n">
					<span class="n__v t-num">{numeri.catture}</span>
					<span class="t-label">catture</span>
				</div>
				<div class="n" class:n--allarme={numeri.aperte > 0}>
					<span class="n__v t-num">{numeri.aperte}</span>
					<span class="t-label">contestazioni aperte</span>
				</div>
				<div class="n">
					<span class="n__v t-num">{numeri.scambi}</span>
					<span class="t-label">scambi</span>
				</div>
			</div>
		{/if}
	</Finestra>

	{#if pronto && !numeri.item}
		<Finestra titolo="Si comincia da qui" variante="orange">
			<p>Il PachiDex e' vuoto. Carica le sfiziosita' e la vacanza puo' partire.</p>
			<p class="t-small t-muted">
				Puoi importare un CSV in blocco oppure aggiungere gli elementi a mano, uno per uno.
			</p>
			<div class="cta">
				<a class="btn btn--primary" href="/gestione-xk29/import">Importa un CSV</a>
				<a class="btn" href="/gestione-xk29/item">Aggiungi a mano</a>
			</div>
		</Finestra>
	{/if}

	<Finestra titolo="Regole in vigore" variante="blue">
		{#if pronto}
			<ul class="regole t-small">
				<li>Aprire una contestazione costa <strong>✦ {config.costo_apertura_contestazione}</strong></li>
				<li>Chi perde la contestazione lascia altri <strong>✦ {config.penalita_extra_contestazione}</strong></li>
				<li>
					Valori di default: comune ✦ {config.croq_comune}, raro ✦ {config.croq_raro},
					leggendario ✦ {config.croq_leggendario}
				</li>
				<li>Checkpoint GPS validi entro <strong>{config.raggio_gps_metri} m</strong></li>
				<li>Una contestazione scade dopo <strong>{config.durata_contestazione_ore} ore</strong></li>
			</ul>
			<a class="btn btn--sm" href="/gestione-xk29/config">Cambia le regole</a>
		{/if}
	</Finestra>

	<Finestra titolo="⚠ Zona pericolosa" variante="navy" bottoni={false}>
		<div class="pericolo">
			<p>
				<strong>Ricomincia il gioco da capo.</strong>
			</p>
			<p class="t-small">
				Cancella catture, contestazioni, voti, reazioni, scambi <em>e anche tutte le
				sfiziosita' del PachiDex</em>. Restano solo i sei giocatori e le regole.
			</p>
			<p class="t-small t-muted">
				Non si torna indietro: non c'e' cestino ne' annulla. Serve a ripartire pulito,
				non a correggere un errore.
			</p>
			<button class="btn btn--danger" onclick={apriReset} disabled={!pronto}>
				Ricomincia da capo
			</button>
		</div>
	</Finestra>
</div>

<Foglio
	aperto={chiedeReset}
	titolo={esitoReset ? 'Fatto' : 'Sei sicuro?'}
	variante="navy"
	onChiudi={() => (chiedeReset = false)}
>
	{#if esitoReset}
		<div class="stack">
			<p><strong>Il gioco e' stato azzerato.</strong></p>
			<ul class="bilancio t-small">
				{#each esitoReset as r (r.tabella)}
					<li>
						<span class="grow">{r.tabella}</span>
						<span class="t-num">{r.cancellate}</span>
					</li>
				{/each}
			</ul>
			<p class="t-small t-muted">
				Le foto gia' caricate restano su R2 come file orfani: non le vede piu' nessuno,
				e se danno fastidio si svuota la cartella dal pannello Cloudflare.
			</p>
			<a class="btn btn--primary btn--block" href="/gestione-xk29/import">
				Carica il nuovo PachiDex
			</a>
		</div>
	{:else}
		<div class="stack">
			<div class="conto">
				<p class="t-label">Stai per cancellare</p>
				<ul class="t-small">
					<li><strong>{numeri.item}</strong> sfiziosita del PachiDex</li>
					<li><strong>{numeri.catture}</strong> catture, con le loro contestazioni e reazioni</li>
					<li><strong>{numeri.scambi}</strong> scambi di Croquembouche</li>
				</ul>
				<p class="t-small t-muted">
					I saldi tornano tutti a zero, perche' si calcolano da quello che stai buttando.
				</p>
			</div>

			<!-- Seconda conferma: scrivere la parola per esteso. Un secondo tasto
			     "sei sicuro?" si preme per riflesso, questo no. -->
			<div class="field-row">
				<label class="field-label" for="parola">
					Scrivi {PAROLA} per confermare
				</label>
				<input
					id="parola"
					class="field"
					bind:value={parolaScritta}
					autocomplete="off"
					autocapitalize="characters"
					spellcheck="false"
					placeholder={PAROLA}
				/>
			</div>

			{#if erroreReset}<p class="t-small errore">{erroreReset}</p>{/if}

			<div class="due">
				<button class="btn" onclick={() => (chiedeReset = false)}>Lascia stare</button>
				<button
					class="btn btn--danger"
					disabled={!parolaGiusta || inAzzeramento}
					onclick={confermaReset}
				>
					{inAzzeramento ? 'Azzero…' : `Cancella ${daButtare} righe`}
				</button>
			</div>
		</div>
	{/if}
</Foglio>

<style>
	.numeri {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
		gap: var(--space-2);
	}

	.n {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: var(--space-3);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.n--allarme {
		background: var(--yellow);
	}

	.n__v {
		font-size: 2rem;
		font-weight: 700;
		line-height: 1;
	}

	.cta {
		display: flex;
		gap: var(--space-2);
		margin-top: var(--space-3);
		flex-wrap: wrap;
	}

	.regole {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-bottom: var(--space-3);
	}

	.regole li {
		padding-left: 14px;
		position: relative;
	}

	.regole li::before {
		content: '▪';
		position: absolute;
		left: 0;
		color: var(--orange);
	}

	.pericolo {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		align-items: flex-start;
		border-left: var(--border) solid var(--red);
		padding-left: var(--space-3);
	}

	.conto {
		background: rgba(217, 59, 50, 0.12);
		border: var(--border-thin) solid var(--red);
		padding: var(--space-3);
	}

	.conto ul {
		display: flex;
		flex-direction: column;
		gap: 3px;
		margin: var(--space-2) 0;
	}

	.bilancio li {
		display: flex;
		justify-content: space-between;
		padding: 4px 0;
		border-bottom: 1px solid rgba(22, 27, 61, 0.15);
	}

	.due {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
