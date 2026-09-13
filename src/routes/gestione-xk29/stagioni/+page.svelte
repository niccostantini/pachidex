<script lang="ts">
	import { onMount } from 'svelte';
	import { salvaConfig } from '$lib/db/admin';
	import { caricaConfig } from '$lib/db/dex';
	import {
		apriStagione,
		catalogoDiStagione,
		chiudiStagione,
		daSvuotare,
		stagioni,
		svuotaStagione,
		type DaSvuotare,
		type Stagione
	} from '$lib/db/stagioni';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let elenco = $state<Stagione[]>([]);
	let svuotabili = $state<DaSvuotare[]>([]);
	let inGioco = $state(0);
	let svuotamentoAcceso = $state(false);
	let giorni = $state(14);
	let caricando = $state(true);
	let lavorando = $state(false);
	let errore = $state<string | null>(null);
	let esito = $state<string | null>(null);

	const aperta = $derived(elenco.find((s) => !s.chiusa_at) ?? null);

	/**
	 * Quanti giorni mancano, contati fra date e non fra istanti.
	 *
	 * Con i timestamp veniva fuori un giorno in piu': "fine" e' una data secca
	 * che il browser legge a mezzanotte UTC, e sottrarci l'ora attuale fa
	 * spuntare frazioni che l'arrotondamento per eccesso trasforma in un
	 * giorno intero. La finestra e' [inizio, fine), quindi i giorni che
	 * restano sono esattamente fine meno oggi.
	 */
	const giorniAllaFine = $derived.by(() => {
		if (!aperta) return 0;
		const oggi = new Date();
		const a = Date.UTC(oggi.getFullYear(), oggi.getMonth(), oggi.getDate());
		const [y, m, g] = aperta.fine.split('-').map(Number);
		return Math.round((Date.UTC(y, m - 1, g) - a) / 86_400_000);
	});

	const data = (s: string) =>
		new Date(s).toLocaleDateString('it-IT', { day: 'numeric', month: 'short' });

	async function rileggi() {
		errore = null;
		try {
			const [config, tutte, da] = await Promise.all([caricaConfig(), stagioni(), daSvuotare()]);
			svuotamentoAcceso = (config.svuotamento_attivo ?? 0) === 1;
			elenco = tutte;
			svuotabili = da;
			const apertaOra = tutte.find((s) => !s.chiusa_at);
			inGioco = apertaOra ? await catalogoDiStagione(apertaOra.numero) : 0;
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	async function agisci(fn: () => Promise<unknown>, detto: string) {
		lavorando = true;
		errore = null;
		esito = null;
		try {
			await fn();
			esito = detto;
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			lavorando = false;
		}
	}

	function chiudi() {
		if (
			!confirm(
				'Chiudere la stagione? Si congela il conto, si assegnano le coccarde, esce «Queste siete» e ne comincia una nuova. Non si torna indietro.'
			)
		) {
			return;
		}
		void agisci(() => chiudiStagione(giorni), 'Stagione chiusa, ne è cominciata una nuova.');
	}

	function svuota(n: number, catture: number) {
		if (
			!confirm(
				`Cancellare ${catture} fra catture e scambi della stagione ${n}, foto comprese? Delle foto restano solo quelle di «Queste siete». Se non hai ancora archiviato, fallo prima: non si torna indietro.`
			)
		) {
			return;
		}
		void agisci(() => svuotaStagione(n), 'Stagione svuotata.');
	}

	onMount(rileggi);
</script>

<div class="stack">
	<Finestra titolo="La stagione in corso" variante="navy">
		<div class="stack">
			{#if caricando}
				<p class="t-label t-muted">Guardo a che punto siamo…</p>
			{:else if aperta}
				<div class="stato">
					<span class="pastiglia pastiglia--ok">stagione {aperta.numero}</span>
					<span class="pastiglia">{data(aperta.inizio)} → {data(aperta.fine)}</span>
					<span class="pastiglia" class:pastiglia--ok={giorniAllaFine > 1}>
						{giorniAllaFine > 0 ? `${giorniAllaFine} giorni alla fine` : 'scaduta'}
					</span>
					<span class="pastiglia">{inGioco} sfiziosità in gioco</span>
				</div>

				<p class="t-small t-muted">
					Chiudendo si congela il conto — i Croquembouche restano nei portacroque, a
					ripartire è solo la classifica — si assegnano le coccarde, si mette da parte una
					foto a testa ed esce «Queste siete». Subito dopo ne comincia un'altra.
				</p>

				<div class="riga">
					<label class="t-label" for="giorni">La prossima dura</label>
					<input id="giorni" class="field breve" type="number" min="1" bind:value={giorni} />
					<span class="t-label">giorni</span>
				</div>

				<button class="btn btn--danger" disabled={lavorando} onclick={chiudi}>
					{lavorando ? 'Un attimo…' : 'Chiudi la stagione'}
				</button>
			{:else}
				<p class="t-small">
					Nessuna stagione aperta: il gioco si comporta come ha sempre fatto — catalogo
					intero, classifica di tutta la storia. Aprendo la prima, quello che è successo
					finora diventa la stagione zero e resta nei portacroque.
				</p>
				<div class="riga">
					<label class="t-label" for="giorni2">Dura</label>
					<input id="giorni2" class="field breve" type="number" min="1" bind:value={giorni} />
					<span class="t-label">giorni</span>
				</div>
				<button
					class="btn btn--primary"
					disabled={lavorando}
					onclick={() => agisci(() => apriStagione(giorni), 'Stagione aperta.')}
				>
					{lavorando ? 'Apro…' : 'Apri una stagione'}
				</button>
			{/if}

			{#if errore}<p class="riga-errore t-small">{errore}</p>{/if}
			{#if esito}<p class="riga-ok t-small">{esito}</p>{/if}
		</div>
	</Finestra>

	<Finestra titolo="Foto da cancellare" variante="orange">
		<div class="stack">
			<p class="t-small">
				A stagione chiusa le foto se ne vanno, ma solo dopo che tutti hanno visto «Queste
				siete» — o dopo 24 ore, altrimenti basta una persona in vacanza per bloccare tutto.
				Quelle del Wrapped non si toccano mai.
			</p>

			<p class="t-small t-muted">
				<strong>Prima di svuotare, archivia:</strong>
				<code>node scripts/scarica-foto.mjs</code> le scarica tutte con un indice. Dopo non
				c'è modo di recuperarle.
			</p>

			<div class="stato">
				<span class="pastiglia" class:pastiglia--ok={svuotamentoAcceso}>
					{svuotamentoAcceso ? 'acceso' : 'spento'}
				</span>
			</div>

			<button
				class="btn"
				class:btn--danger={svuotamentoAcceso}
				class:btn--ok={!svuotamentoAcceso}
				disabled={lavorando}
				onclick={() =>
					agisci(
						() => salvaConfig({ svuotamento_attivo: svuotamentoAcceso ? 0 : 1 }),
						svuotamentoAcceso ? 'Svuotamento spento.' : 'Svuotamento acceso.'
					)}
			>
				{svuotamentoAcceso ? 'Spegni lo svuotamento' : 'Accendi lo svuotamento'}
			</button>

			{#if svuotabili.length}
				<ul class="da-fare t-small">
					{#each svuotabili as s (s.stagione)}
						<li>
							<strong>Stagione {s.stagione}</strong> — {s.catture} fra catture e scambi · visto da
							{s.visto_da}/{s.giocatori}
							{#if s.pronta}
								<button
									class="btn btn--sm btn--danger"
									disabled={lavorando || !svuotamentoAcceso}
									onclick={() => svuota(s.stagione, s.catture)}
								>
									Svuota
								</button>
							{:else}
								<span class="t-muted">— si può dal {new Date(s.scade).toLocaleString('it-IT')}</span>
							{/if}
						</li>
					{/each}
				</ul>
			{:else if !caricando}
				<p class="t-small t-muted">Niente da svuotare.</p>
			{/if}
		</div>
	</Finestra>

	{#if elenco.filter((s) => s.chiusa_at).length}
		<Finestra titolo="Quelle passate" variante="blue">
			<table class="tabella t-small">
				<thead>
					<tr><th>N.</th><th>Quando</th><th>Foto</th></tr>
				</thead>
				<tbody>
					{#each elenco.filter((s) => s.chiusa_at) as s (s.numero)}
						<tr>
							<td>{s.numero === 0 ? 'prima' : s.numero}</td>
							<td>{s.numero === 0 ? 'tutto il passato' : `${data(s.inizio)} → ${data(s.fine)}`}</td>
							<td>{s.foto_cancellate_at ? 'cancellate' : 'ci sono'}</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</Finestra>
	{/if}
</div>

<style>
	.stato {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.pastiglia {
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		padding: 3px 8px;
		background: var(--cream);
		color: var(--navy);
		border: var(--border-thin) solid var(--navy);
	}

	.pastiglia--ok {
		background: var(--green);
		color: var(--paper);
	}

	.riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.breve {
		width: 4.5rem;
		text-align: right;
	}

	.da-fare {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.tabella {
		width: 100%;
		border-collapse: collapse;
	}

	.tabella th,
	.tabella td {
		text-align: left;
		padding: 4px 6px;
		border-bottom: var(--border-thin) solid var(--navy);
	}

	.riga-errore {
		background: var(--red);
		color: var(--paper);
		padding: var(--space-2);
	}

	.riga-ok {
		background: var(--green);
		color: var(--paper);
		padding: var(--space-2);
	}
</style>
