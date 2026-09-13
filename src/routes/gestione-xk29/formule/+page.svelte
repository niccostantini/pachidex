<script lang="ts">
	import { onMount } from 'svelte';
	import {
		aggiungiFormula,
		caricaFormule,
		cambiaFormula,
		conIlNome,
		riordinaFormule,
		togliFormula
	} from '$lib/db/oversharing';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';
	import type { Formula } from '$lib/types';

	/**
	 * Le formule di Fa' Oversharing.
	 *
	 * Non le scrivono i giocatori: se ognuna potesse aggiungersi la sua, in tre
	 * giorni sarebbero duecento e la sorpresa di vedersi assegnare
	 * «bisbiglia al proprio ombelico» finirebbe. Sono la voce del gioco, e la
	 * voce la tiene chi lo gestisce.
	 */
	let formule = $state<Formula[]>([]);
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);
	let nuova = $state('');
	let occupato = $state(false);

	const attive = $derived(formule.filter((f) => f.attiva).length);

	async function rileggi() {
		try {
			// Anche quelle spente: qui si amministra, e una formula in panchina
			// deve potersi rimettere in campo.
			formule = await caricaFormule(false);
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
		}
	}

	onMount(rileggi);

	async function fai(azione: () => Promise<unknown>) {
		occupato = true;
		errore = null;
		try {
			await azione();
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			occupato = false;
		}
	}

	function aggiungi() {
		const testo = nuova.trim();
		if (!testo) return;
		const coda = Math.max(0, ...formule.map((f) => f.ordine)) + 1;
		void fai(async () => {
			await aggiungiFormula(testo, coda);
			nuova = '';
		});
	}

	function sposta(i: number, verso: -1 | 1) {
		const j = i + verso;
		if (j < 0 || j >= formule.length) return;
		const ids = formule.map((f) => f.id);
		[ids[i], ids[j]] = [ids[j], ids[i]];
		void fai(() => riordinaFormule(ids));
	}
</script>

<div class="stack">
	<Finestra titolo="Formule di Fa' Oversharing" variante="navy">
		<p class="t-small">
			Ogni oversharing ne pesca una a caso quando viene pubblicato, e poi se la
			tiene. La <strong>X</strong> è il posto dove va il nome di chi ha scritto: se
			nella formula non c'è, il nome va davanti.
		</p>
		<p class="t-small t-muted">
			Toglierne una non rovina i post che ce l'avevano: ne ricevono un'altra, sempre
			la stessa. Spegnerla invece la lascia lì senza più pescarla.
		</p>

		{#if stato === 'ok'}
			<p class="t-label t-muted conto">{attive} attive su {formule.length}</p>
		{/if}
	</Finestra>

	<Finestra titolo="Aggiungine una" variante="orange">
		<div class="riga-nuova">
			<input
				class="field grow"
				bind:value={nuova}
				placeholder="X pontifica dal balcone:"
				onkeydown={(e) => e.key === 'Enter' && aggiungi()}
			/>
			<button class="btn btn--primary" onclick={aggiungi} disabled={!nuova.trim() || occupato}>
				Aggiungi
			</button>
		</div>
		{#if nuova.trim()}
			<p class="anteprima t-small">{conIlNome(nuova.trim(), 'Nina')} che caldo che fa</p>
		{/if}
	</Finestra>

	{#if errore}
		<p class="t-small errore">{errore}</p>
	{/if}

	<Finestra titolo="Quelle che ci sono" variante="blue">
		{#if stato === 'carico'}
			<p class="t-label t-muted">Carico…</p>
		{:else if !formule.length}
			<p class="t-small">Nessuna formula: gli oversharing usciranno con «X dice:».</p>
		{:else}
			<ol class="elenco">
				{#each formule as f, i (f.id)}
					<li class="f" class:f--spenta={!f.attiva}>
						<span class="pos t-num t-small">{i + 1}</span>
						<span class="testo grow t-small">{f.testo}</span>
						<div class="bottoni">
							<div class="frecce">
							<button
								class="btn btn--sm"
								onclick={() => sposta(i, -1)}
								disabled={i === 0 || occupato}
								aria-label="Su">↑</button
							>
							<button
								class="btn btn--sm"
								onclick={() => sposta(i, 1)}
								disabled={i === formule.length - 1 || occupato}
								aria-label="Giù">↓</button
							>
							</div>
							<button
								class="btn btn--sm"
								onclick={() => fai(() => cambiaFormula(f.id, { attiva: !f.attiva }))}
								disabled={occupato}
							>
								{f.attiva ? 'Spegni' : 'Accendi'}
							</button>
							<button
								class="btn btn--sm btn--danger"
								onclick={() => fai(() => togliFormula(f.id))}
								disabled={occupato}
							>
								Togli
							</button>
						</div>
					</li>
				{/each}
			</ol>
		{/if}
	</Finestra>
</div>

<style>
	.conto {
		margin-top: var(--space-2);
	}

	.riga-nuova {
		display: flex;
		gap: var(--space-2);
	}

	.anteprima {
		margin-top: var(--space-2);
		background: var(--cream);
		border-left: var(--border) solid var(--orange);
		padding: var(--space-2);
	}

	.elenco {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	/*
	 * Le leve vanno a capo appena il testo scende sotto le dodici lettere di
	 * larghezza. Su un telefono, tutto in fila, la formula si spezzava una
	 * lettera per riga — e una formula che non si legge non si puo' nemmeno
	 * riordinare.
	 */
	.f {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.bottoni {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-left: auto;
	}

	.testo {
		min-width: 12rem;
		overflow-wrap: anywhere;
	}

	/* Spenta si vede a colpo d'occhio: resta in elenco ma non pesca piu'. */
	.f--spenta {
		background: var(--paper);
		opacity: 0.55;
	}

	.pos {
		width: 2rem;
		color: var(--navy-soft);
		flex-shrink: 0;
	}

	.frecce {
		display: flex;
		gap: 2px;
	}

	.errore {
		color: var(--orange-dark);
	}
</style>
