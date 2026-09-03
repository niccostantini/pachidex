<script lang="ts">
	import { onMount } from 'svelte';
	import {
		annullaFinale,
		avviaFinale,
		eliminaPremio,
		salvaPremio,
		statoFinale,
		tuttiIPremi,
		type Premio,
		type StatoFinale
	} from '$lib/db/finale';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let premi = $state<Premio[]>([]);
	let stato = $state<StatoFinale | null>(null);
	let caricando = $state(true);
	let errore = $state<string | null>(null);

	const avviata = $derived(stato !== null);

	async function rileggi() {
		caricando = true;
		errore = null;
		try {
			[premi, stato] = await Promise.all([tuttiIPremi(), statoFinale()]);
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	async function agisci(fn: () => Promise<unknown>) {
		errore = null;
		try {
			await fn();
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		}
	}

	onMount(rileggi);
</script>

<div class="stack">
	<Finestra titolo="La premiazione" variante="navy">
		<div class="stack">
			<p class="t-small">
				Podio di partenza, poi i premi votati dal vivo, poi il podio aggiornato. Ogni
				premio resta aperto {stato?.secondi_voto ?? 60} secondi: quando hanno votato tutti
				si chiude prima, e se qualcuno non vota si assegna lo stesso con i voti arrivati.
			</p>
			<p class="t-small">
				A parità di voti vince chi ha meno Croquembouche. Si può votare sé stessi.
			</p>

			{#if avviata}
				<p class="acceso t-label">
					Premiazione in corso — fase: {stato?.fase}
					{#if stato?.premio_numero}· premio {stato.premio_numero}{/if}
				</p>
				<p class="t-small">
					Il gioco è congelato: nessuno può catturare, scambiare o contestare. Tutti i
					telefoni sono stati portati sulla pagina della premiazione.
				</p>
				<button
					class="btn btn--danger"
					onclick={() => {
						if (confirm('Annullo la premiazione? Voti e premi assegnati vengono cancellati e il gioco riapre.'))
							void agisci(annullaFinale);
					}}
				>
					Annulla la premiazione
				</button>
			{:else}
				<p class="t-small t-muted">
					Da quando la avvii non si cattura, non si scambia e non si contesta più. Le
					contestazioni ancora aperte vengono risolte subito con i voti che hanno.
				</p>
				<button
					class="btn btn--primary btn--lg btn--block"
					disabled={!premi.filter((p) => p.attivo).length}
					onclick={() => {
						if (confirm('Chiudo il gioco e comincio la premiazione. Sicuro?'))
							void agisci(avviaFinale);
					}}
				>
					Avvia la premiazione
				</button>
				{#if !premi.filter((p) => p.attivo).length}
					<p class="t-small">Prima serve almeno un premio attivo.</p>
				{/if}
			{/if}
		</div>
	</Finestra>

	{#if errore}
		<Finestra titolo="Errore" variante="navy"><p class="t-small">{errore}</p></Finestra>
	{/if}

	<Finestra titolo="I premi" variante="blue">
		<div class="stack">
			{#if caricando}
				<p class="t-label t-muted">Carico…</p>
			{:else}
				{#each premi as p (p.id)}
					<div class="riga">
						<input class="field num" type="number" bind:value={p.numero} disabled={avviata} />
						<input class="field grow" bind:value={p.domanda} disabled={avviata} />
						<input class="field num" type="number" min="0" bind:value={p.croquembouche} disabled={avviata} />
						<label class="acceso-box t-small">
							<input type="checkbox" bind:checked={p.attivo} disabled={avviata} />
							attivo
						</label>
						<button class="btn btn--sm btn--ok" disabled={avviata} onclick={() => agisci(() => salvaPremio(p))}>
							Salva
						</button>
						<button class="btn btn--sm btn--danger" disabled={avviata} onclick={() => agisci(() => eliminaPremio(p.id))}>
							×
						</button>
					</div>
				{/each}

				<button
					class="btn btn--sm"
					disabled={avviata}
					onclick={() =>
						agisci(() =>
							salvaPremio({
								numero: Math.max(0, ...premi.map((x) => x.numero)) + 1,
								domanda: 'CHI…?',
								croquembouche: 40
							})
						)}
				>
					Aggiungi un premio
				</button>
			{/if}
		</div>
	</Finestra>
</div>

<style>
	.riga {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-wrap: wrap;
	}

	.num {
		max-width: 72px;
	}

	.acceso-box {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.acceso {
		background: var(--orange);
		color: var(--paper);
		padding: 4px 8px;
		align-self: flex-start;
	}
</style>
