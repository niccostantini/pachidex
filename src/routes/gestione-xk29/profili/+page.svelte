<script lang="ts">
	import { onMount } from 'svelte';
	import { eliminaUtente, salvaUtente } from '$lib/db/admin';
	import { annullaScambio, tuttiGliScambi } from '$lib/db/admin';
	import { profilo } from '$lib/state/profilo.svelte';
	import { tempoRelativo } from '$lib/game/rules';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import Foglio from '$lib/components/Foglio.svelte';
	import type { Transfer, User } from '$lib/types';

	type ScambioEsteso = Transfer & { mittente: { nome: string }; destinatario: { nome: string } };

	let modifica = $state<Partial<User> | null>(null);
	let salvando = $state(false);
	let erroreForm = $state<string | null>(null);
	let scambi = $state<ScambioEsteso[]>([]);
	let errore = $state<string | null>(null);

	const COLORI = ['#F0552B', '#2B5ED0', '#35B79A', '#8B5CF6', '#D93B32', '#C98A18', '#4A5578'];

	async function rileggi() {
		await profilo.carica();
		try {
			scambi = (await tuttiGliScambi()) as unknown as ScambioEsteso[];
		} catch (e) {
			errore = messaggioErrore(e);
		}
	}

	onMount(rileggi);

	async function salva() {
		if (!modifica?.nome?.trim()) {
			erroreForm = 'Il nome serve.';
			return;
		}
		salvando = true;
		erroreForm = null;
		try {
			await salvaUtente({ ...(modifica as User), nome: modifica.nome.trim() });
			modifica = null;
			await rileggi();
		} catch (e) {
			erroreForm = messaggioErrore(e);
		} finally {
			salvando = false;
		}
	}

	async function elimina(u: User) {
		if (!confirm(`Elimino ${u.nome}? Spariscono anche le sue catture e i suoi scambi.`)) return;
		try {
			await eliminaUtente(u.id);
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		}
	}
</script>

<div class="stack">
	<Finestra titolo="Giocatori" variante="navy">
		<ul class="lista">
			{#each profilo.utenti as u (u.id)}
				<li class="riga">
					<Avatar utente={u} dimensione="lg" />
					<div class="grow">
						<p class="nome">
							{u.nome}
							{#if u.is_admin}<span class="badge">admin</span>{/if}
						</p>
						<p class="t-small t-muted">✦ {profilo.saldoDi(u.id)}</p>
					</div>
					<div class="azioni">
						<button class="btn btn--sm" onclick={() => (modifica = { ...u })}>Modifica</button>
						<button class="btn btn--sm btn--danger" onclick={() => elimina(u)}>×</button>
					</div>
				</li>
			{/each}
		</ul>

		<button
			class="btn btn--primary"
			onclick={() => (modifica = { nome: '', colore: '#4A5578', is_admin: false })}
		>
			+ Aggiungi giocatore
		</button>

		<p class="t-small t-muted nota">
			Gli avatar sono disegnati e cablati nel codice, uno per giocatore: non si caricano
			da qui. Un profilo aggiunto adesso non ne ha uno e mostra le iniziali sul colore
			scelto.
		</p>
	</Finestra>

	<Finestra titolo="Scambi di Croquembouche" variante="blue">
		{#if !scambi.length}
			<p class="t-small t-muted">Nessuno scambio, per ora.</p>
		{:else}
			<ul class="scambi">
				{#each scambi as s (s.id)}
					<li class="scambio" class:scambio--ko={s.annullato}>
						<span class="grow t-small">
							<strong>{s.mittente.nome}</strong> → <strong>{s.destinatario.nome}</strong>
							<span class="imp t-num">✦ {s.importo}</span>
							{#if s.causale}<span class="t-muted"> — {s.causale}</span>{/if}
						</span>
						<span class="t-small t-muted">{tempoRelativo(s.created_at)}</span>
						<button
							class="btn btn--sm"
							onclick={async () => {
								await annullaScambio(s.id, !s.annullato);
								await rileggi();
							}}
						>
							{s.annullato ? 'Ripristina' : 'Annulla'}
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</Finestra>

	{#if errore}<p class="errore t-small">{errore}</p>{/if}
</div>

<Foglio
	aperto={!!modifica}
	titolo={modifica?.id ? 'Modifica giocatore' : 'Nuovo giocatore'}
	onChiudi={() => (modifica = null)}
>
	{#if modifica}
		<div class="stack">
			<div class="field-row">
				<label class="field-label" for="u-nome">Nome</label>
				<input id="u-nome" class="field" bind:value={modifica.nome} />
			</div>

			<div>
				<p class="field-label">Colore (per le iniziali, se non ha un avatar)</p>
				<div class="colori">
					{#each COLORI as c (c)}
						<button
							class="colore"
							class:colore--on={modifica.colore === c}
							style:background={c}
							aria-label={c}
							onclick={() => modifica && (modifica.colore = c)}
						></button>
					{/each}
				</div>
			</div>

			<label class="check">
				<input type="checkbox" bind:checked={modifica.is_admin} />
				<span>Amministratore — vede questo pannello</span>
			</label>

			{#if erroreForm}<p class="errore t-small">{erroreForm}</p>{/if}

			<div class="due">
				<button class="btn" onclick={() => (modifica = null)}>Annulla</button>
				<button class="btn btn--primary" onclick={salva} disabled={salvando}>
					{salvando ? 'Salvo…' : 'Salva'}
				</button>
			</div>
		</div>
	{/if}
</Foglio>

<style>
	.lista {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin-bottom: var(--space-3);
	}

	.riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		flex-wrap: wrap;
	}

	.nome {
		font-weight: 700;
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.azioni {
		display: flex;
		gap: 4px;
	}

	.nota {
		margin-top: var(--space-3);
	}

	.scambi {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.scambio {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: 5px;
		border-bottom: 1px solid rgba(22, 27, 61, 0.15);
		flex-wrap: wrap;
	}

	.scambio--ko {
		opacity: 0.5;
		text-decoration: line-through;
	}

	.imp {
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		padding: 0 4px;
		font-weight: 700;
	}

	.colori {
		display: flex;
		gap: var(--space-2);
		flex-wrap: wrap;
	}

	.colore {
		width: 38px;
		height: 38px;
		border: var(--border) solid var(--navy);
		cursor: pointer;
	}

	.colore--on {
		box-shadow: 0 0 0 3px var(--yellow);
	}

	.check {
		display: flex;
		gap: var(--space-2);
		align-items: center;
		font-size: 0.875rem;
	}

	.check input {
		width: 20px;
		height: 20px;
		accent-color: var(--orange);
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
