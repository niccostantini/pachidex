<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { caricaFeed, chiudiScadute, sottoscriviFeed } from '$lib/db/feed';
	import { caricaConfig } from '$lib/db/dex';
	import { apriContestazione } from '$lib/db/azioni';
	import { profilo } from '$lib/state/profilo.svelte';
	import { coda } from '$lib/state/coda.svelte';
	import { visto } from '$lib/state/visto.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import CardCattura from '$lib/components/CardCattura.svelte';
	import CardScambio from '$lib/components/CardScambio.svelte';
	import CardContestazione from '$lib/components/CardContestazione.svelte';
	import CardOversharing from '$lib/components/CardOversharing.svelte';
	import CardBlocco from '$lib/components/CardBlocco.svelte';
	import Compositore from '$lib/components/Compositore.svelte';
	import Foglio from '$lib/components/Foglio.svelte';
	import GiroGuidato, { TAPPE } from '$lib/components/GiroGuidato.svelte';
	import { wrapped, type Wrapped } from '$lib/db/stagioni';
	import { browser } from '$app/environment';
	import { selfieDaFare } from '$lib/db/dex';
	import type { PostCattura, PostContestazione, PostFeed } from '$lib/types';

	let fissati = $state<PostContestazione[]>([]);
	let timeline = $state<PostFeed[]>([]);
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);
	let config = $state<Record<string, number>>({});

	/**
	 * Dove eri arrivata l'ultima volta.
	 *
	 * Si fotografa al primo caricamento e poi non si muove piu': il feed si
	 * ricarica da solo a ogni cosa che succede, e se la soglia lo seguisse la
	 * riga scivolerebbe sotto i piedi mentre stai leggendo.
	 *
	 * Subito dopo il segnaposto si sposta a adesso — hai aperto il feed, l'hai
	 * visto — cosi' il pallino si spegne e la prossima volta la riga sta al
	 * punto giusto.
	 */
	let soglia = $state<string | null>(null);

	/**
	 * Giro guidato al primo avvio. Parte solo quando i dati ci sono: la barra
	 * il feed e' la prima tappa e non si puo' illuminare un elemento
	 * che non e' ancora stato disegnato.
	 */
	const CHIAVE_GIRO = 'pachidex:giro-fatto';
	let giroAperto = $state(false);

	async function chiudiGiro() {
		giroAperto = false;
		if (browser) localStorage.setItem(CHIAVE_GIRO, '1');

		// Il giro finisce mandando a fare la prima cosa, se non e' gia' fatta:
		// un invito concreto vale piu' di un "buon divertimento". Ma solo a chi
		// puo' farla: chi guarda da fuori finirebbe sulla schermata di cattura
		// con un pulsante che il database gli rifiuta.
		if (!profilo.io || profilo.soloSguardo) return;
		const selfie = await selfieDaFare(profilo.io.id);
		if (selfie) void goto('/cattura?benvenuto=1');
	}

	$effect(() => {
		if (!browser || stato !== 'ok' || !profilo.io) return;
		if (localStorage.getItem(CHIAVE_GIRO)) return;
		giroAperto = true;
	});

	/** Il Wrapped di una stagione appena chiusa, se non l'ho ancora guardato. */
	let daGuardare = $state<Wrapped | null>(null);

	$effect(() => {
		if (!profilo.io) return;
		void (async () => {
			try {
				const w = await wrapped();
				daGuardare = w && !w.visto_da_me ? w : null;
			} catch {
				/* senza linea se ne riparla al prossimo giro */
			}
		})();
	});

	/**
	 * L'ultima tappa illumina il pulsante della cattura, che chi guarda da
	 * fuori non ha: il riflettore non troverebbe il bersaglio e resterebbe un
	 * velo scuro con sotto un invito a fare una cosa che non puo' fare.
	 */
	const tappeDelGiro = $derived(
		profilo.soloSguardo ? TAPPE.filter((t) => t.bersaglio !== 'cattura') : TAPPE
	);

	// Contestazione in preparazione
	let daContestare = $state<PostCattura | null>(null);
	let motivo = $state('');
	let inInvio = $state(false);
	let erroreContesta = $state<string | null>(null);

	/**
	 * Quante cose stanno sopra la riga.
	 *
	 * Il feed va dal piu' recente al piu' vecchio, quindi il nuovo sta in
	 * cima: la riga cade DOPO l'ultima cosa che non avevi visto, e dice che
	 * da li' in giu' ci sei gia' passata. Se e' zero non si disegna — non
	 * c'e' niente di nuovo — e se e' tutta la lista nemmeno, perche' una riga
	 * in fondo al feed non divide niente.
	 */
	const quantiNuovi = $derived.by(() => {
		const da = soglia;
		if (da === null) return 0;
		return timeline.filter((p) => p.at > da).length;
	});

	const costoContestazione = $derived(config.costo_apertura_contestazione ?? 1);
	const penalita = $derived(config.penalita_extra_contestazione ?? 15);

	async function carica() {
		try {
			const res = await caricaFeed(profilo.io?.id ?? null);
			fissati = res.fissati;
			timeline = res.timeline;
			stato = 'ok';
			if (soglia === null) {
				soglia = visto.marcatore;
				visto.segna();
			}
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
	<!-- L'avviso e non un dirottamento: portare qualcuno di peso su un'altra
	     pagina appena apre l'app e' il modo piu' rapido per farsi chiudere in
	     faccia. Chi non lo guarda entro il giorno vale come se l'avesse
	     visto, quindi non blocca nessuno. -->
	{#if daGuardare}
		<a class="wrapped" href="/queste-siete">
			<span class="t-label">È uscito «Queste siete»</span>
			<span class="t-small">La stagione {daGuardare.stagione} si è chiusa — guarda com'è andata</span>
		</a>
	{/if}

	<!-- Il compositore sta in cima e non dietro a un pulsante: una frase la si
	     attacca mentre si aspetta il caffe', e se per scriverla bisogna aprire
	     qualcosa non la si attacca piu'. -->
	<Compositore onFatto={carica} />

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
		{#each timeline as post, i (post.tipo + post.id)}
			{#if i === quantiNuovi && quantiNuovi > 0}
				<p class="segnaposto t-label">Da qui in giù l'avevi già visto</p>
			{/if}
			{#if post.tipo === 'cattura'}
				<CardCattura {post} onContesta={(p) => ((daContestare = p), (motivo = ''))} />
			{:else if post.tipo === 'scambio'}
				<CardScambio {post} />
			{:else if post.tipo === 'oversharing'}
				<CardOversharing {post} onCambio={carica} />
			{:else if post.tipo === 'blocco'}
				<CardBlocco {post} />
			{:else}
				<CardContestazione {post} onCambio={carica} />
			{/if}
		{/each}
	{/if}
</div>

{#if giroAperto}
	<GiroGuidato tappe={tappeDelGiro} onFine={chiudiGiro} />
{/if}

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
					Aprire costa <strong>✦ {costoContestazione}</strong>, subito.
				</p>
				<p class="t-small">
					Se il gruppo ti da' ragione te ne tornano <strong>✦ {costoContestazione * 2}</strong>:
					la posta e altrettanto, perche' ci hai messo la faccia.
				</p>
				<p class="t-small">
					Se ti da' torto, ne perdi altri <strong>✦ {penalita}</strong>.
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
					enterkeyhint="done"
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

	.wrapped {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: var(--space-2);
		background: var(--yellow);
		color: var(--navy);
		border: var(--border) solid var(--navy);
		text-decoration: none;
	}

	/*
	 * Una riga e basta, non una finestra: e' un segno sul margine, non un
	 * annuncio. Il tratteggio la distingue dai bordi pieni di tutto il resto,
	 * che qui vogliono dire "questo e' un oggetto".
	 */
	.segnaposto {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		color: var(--navy-soft);
		white-space: nowrap;
	}

	.segnaposto::before,
	.segnaposto::after {
		content: '';
		flex: 1;
		border-top: var(--border-thin) dashed var(--navy-soft);
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
