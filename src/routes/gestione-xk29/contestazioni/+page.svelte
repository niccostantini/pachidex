<script lang="ts">
	import { onMount } from 'svelte';
	import { annullaContestazione, forzaEsito, tutteLeContestazioni } from '$lib/db/admin';
	import { tempoRelativo, tempoRimanente } from '$lib/game/rules';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';
	import type { Contest, User, Vote } from '$lib/types';

	type Riga = Contest & {
		contestante: User;
		votes: Vote[];
		cattura: { id: string; foto_url: string; nota: string | null; item: { nome: string }; autore: User } | null;
	};

	let righe = $state<Riga[]>([]);
	let caricando = $state(true);
	let errore = $state<string | null>(null);
	let inAzione = $state<string | null>(null);

	const aperte = $derived(righe.filter((r) => r.stato === 'aperta'));
	const chiuse = $derived(righe.filter((r) => r.stato !== 'aperta'));

	async function rileggi() {
		caricando = true;
		try {
			righe = (await tutteLeContestazioni()) as unknown as Riga[];
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	onMount(rileggi);

	async function agisci(r: Riga, azione: 'valido' | 'non_valido' | 'annulla') {
		const domanda =
			azione === 'annulla'
				? 'Annullo del tutto questa contestazione? La cattura torna valida e nessuno paga la penalita.'
				: azione === 'valido'
					? 'Chiudo a favore del contestato? La cattura resta valida e il contestante paga la penalita.'
					: 'Chiudo contro il contestato? La cattura viene invalidata e lui paga la penalita.';
		if (!confirm(domanda)) return;

		inAzione = r.id;
		try {
			if (azione === 'annulla') await annullaContestazione(r);
			else await forzaEsito(r, azione === 'valido' ? 'chiusa_valido' : 'chiusa_non_valido');
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			inAzione = null;
		}
	}

	const etichetta = (s: string) =>
		({
			aperta: 'aperta',
			chiusa_valido: 'cattura confermata',
			chiusa_non_valido: 'cattura invalidata',
			scaduta: 'scaduta'
		})[s] ?? s;
</script>

<div class="stack">
	<Finestra titolo="Contestazioni aperte" variante="navy">
		{#if caricando}
			<p class="t-label t-muted">Carico…</p>
		{:else if !aperte.length}
			<p class="t-small t-muted">Nessuna contestazione aperta. Tutto tranquillo.</p>
		{:else}
			<ul class="lista">
				{#each aperte as r (r.id)}
					<li class="voce voce--aperta">
						<div class="voce__testa">
							{#if r.cattura}
								<img class="mini" src={r.cattura.foto_url} alt="" />
							{/if}
							<div class="grow">
								<p>
									<strong>{r.contestante.nome}</strong> contro
									<strong>{r.cattura?.autore.nome ?? '—'}</strong>
								</p>
								<p class="t-small t-muted">
									{r.cattura?.item.nome ?? 'cattura sparita'} · aperta {tempoRelativo(r.created_at)}
								</p>
							</div>
							<span class="scad t-num">{tempoRimanente(r.scadenza)}</span>
						</div>

						{#if r.motivo}
							<p class="motivo t-small">“{r.motivo}”</p>
						{/if}

						<p class="t-small">
							Voti: <strong>{r.votes.filter((v) => v.voto === 'non_valido').length}</strong> non
							valida · <strong>{r.votes.filter((v) => v.voto === 'valido').length}</strong> valida
						</p>

						<div class="azioni">
							<button
								class="btn btn--ok btn--lg grow"
								disabled={inAzione === r.id}
								onclick={() => agisci(r, 'valido')}
							>
								Risolvi a favore
							</button>
							<button
								class="btn btn--danger btn--lg grow"
								disabled={inAzione === r.id}
								onclick={() => agisci(r, 'non_valido')}
							>
								Risolvi contro
							</button>
						</div>
						<button
							class="btn btn--block"
							disabled={inAzione === r.id}
							onclick={() => agisci(r, 'annulla')}
						>
							Annulla contestazione
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</Finestra>

	<Finestra titolo="Archivio" variante="blue">
		{#if !chiuse.length}
			<p class="t-small t-muted">Ancora niente in archivio.</p>
		{:else}
			<ul class="lista">
				{#each chiuse as r (r.id)}
					<li class="voce">
						<div class="voce__testa">
							<div class="grow">
								<p class="t-small">
									<strong>{r.contestante.nome}</strong> contro
									<strong>{r.cattura?.autore.nome ?? '—'}</strong>
									su {r.cattura?.item.nome ?? '—'}
								</p>
								<p class="t-small t-muted">{tempoRelativo(r.created_at)}</p>
							</div>
							<span class="esito esito--{r.stato}">{etichetta(r.stato)}</span>
						</div>
						<button class="btn btn--sm" onclick={() => agisci(r, 'annulla')}>
							Cancella dalla cronaca
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</Finestra>

	{#if errore}<p class="errore t-small">{errore}</p>{/if}
</div>

<style>
	.lista {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.voce {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.voce--aperta {
		border-width: var(--border);
		box-shadow: 0 0 0 3px var(--yellow);
	}

	.voce__testa {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.mini {
		width: 52px;
		height: 52px;
		object-fit: cover;
		border: var(--border-thin) solid var(--navy);
		flex-shrink: 0;
	}

	.scad {
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		padding: 1px 5px;
		font-size: 0.75rem;
		font-weight: 700;
	}

	.motivo {
		border-left: var(--border) solid var(--navy);
		padding-left: var(--space-2);
	}

	.azioni {
		display: flex;
		gap: var(--space-2);
	}

	.esito {
		font-size: 0.6875rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		padding: 2px 6px;
		border: var(--border-thin) solid var(--navy);
		background: var(--paper);
		white-space: nowrap;
	}

	.esito--chiusa_non_valido {
		background: var(--red);
		color: var(--paper);
	}

	.esito--chiusa_valido {
		background: var(--green);
		color: var(--paper);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
