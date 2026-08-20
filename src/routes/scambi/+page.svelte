<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { inviaCroquembouche } from '$lib/db/azioni';
	import { caricaScambi } from '$lib/db/feed';
	import { profilo } from '$lib/state/profilo.svelte';
	import { tempoRelativo } from '$lib/game/rules';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import type { PostScambio, User } from '$lib/types';

	let destinatario = $state<User | null>(null);
	let importo = $state(10);
	let causale = $state('');
	let inInvio = $state(false);
	let errore = $state<string | null>(null);
	let fatto = $state<string | null>(null);
	let storico = $state<PostScambio[]>([]);

	const disponibile = $derived(profilo.saldo);
	const valido = $derived(
		!!destinatario && importo > 0 && importo <= disponibile && !!profilo.io
	);

	async function rileggi() {
		storico = await caricaScambi(20);
		await profilo.aggiornaSaldi();
	}

	onMount(rileggi);

	async function invia() {
		if (!valido || !profilo.io || !destinatario) return;
		inInvio = true;
		errore = null;
		try {
			await inviaCroquembouche(
				profilo.io.id,
				destinatario.id,
				importo,
				causale.trim() || undefined
			);
			fatto = `✦ ${importo} a ${destinatario.nome}`;
			destinatario = null;
			causale = '';
			importo = 10;
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			inInvio = false;
		}
	}
</script>

<svelte:head><title>Scambi — Pachino Express</title></svelte:head>

<div class="sc stack">
	<Finestra titolo="Passa Croquembouche" onChiudi={() => goto('/classifica')}>
		<div class="stack">
			<div class="saldo">
				<span class="t-label">Hai</span>
				<span class="saldo__n t-num">✦ {disponibile}</span>
			</div>

			<div>
				<p class="field-label">A chi</p>
				<div class="gente">
					{#each profilo.altri as u (u.id)}
						<button
							class="tizio"
							class:tizio--on={destinatario?.id === u.id}
							onclick={() => (destinatario = destinatario?.id === u.id ? null : u)}
						>
							<Avatar utente={u} dimensione="lg" />
							<span class="t-small">{u.nome}</span>
						</button>
					{/each}
				</div>
			</div>

			<div class="field-row">
				<label class="field-label" for="importo">Quanti</label>
				<div class="importo">
					<button class="btn btn--sm" onclick={() => (importo = Math.max(1, importo - 5))}>
						−5
					</button>
					<input
						id="importo"
						class="field t-num"
						type="number"
						min="1"
						max={disponibile}
						bind:value={importo}
					/>
					<button
						class="btn btn--sm"
						onclick={() => (importo = Math.min(disponibile, importo + 5))}
					>
						+5
					</button>
				</div>
				{#if importo > disponibile}
					<p class="t-small errore">Non ne hai cosi' tanti.</p>
				{/if}
			</div>

			<div class="field-row">
				<label class="field-label" for="causale">Per cosa</label>
				<input
					id="causale"
					class="field"
					bind:value={causale}
					maxlength="120"
					placeholder="Per la granita di ieri"
				/>
			</div>

			{#if errore}<p class="t-small errore">{errore}</p>{/if}
			{#if fatto}<p class="t-small ok">Mandati {fatto}.</p>{/if}

			<button class="btn btn--primary btn--lg btn--block" disabled={!valido || inInvio} onclick={invia}>
				{inInvio ? 'Mando…' : 'Manda'}
			</button>

			<p class="t-small t-muted">
				Gli scambi valgono nella classifica Croquembouche, non in quella degli elementi unici.
				Se sbagli, l'admin puo' annullare.
			</p>
		</div>
	</Finestra>

	<Finestra titolo="Ultimi scambi" variante="blue">
		{#if !storico.length}
			<p class="t-small t-muted">Ancora nessuno scambio.</p>
		{:else}
			<ul class="storia">
				{#each storico as s (s.id)}
					<li class="riga t-small">
						<strong>{s.mittente.nome}</strong>
						<span aria-hidden="true">→</span>
						<strong>{s.destinatario.nome}</strong>
						<span class="imp t-num">✦ {s.importo}</span>
						<span class="grow t-muted">{s.causale ?? ''}</span>
						<span class="t-muted">{tempoRelativo(s.created_at)}</span>
					</li>
				{/each}
			</ul>
		{/if}
	</Finestra>
</div>

<style>
	.sc {
		padding: var(--space-3);
	}

	.saldo {
		display: flex;
		align-items: center;
		justify-content: space-between;
		background: var(--navy);
		color: var(--yellow);
		border: var(--border) solid var(--navy);
		padding: var(--space-2) var(--space-3);
	}

	.saldo__n {
		font-size: 1.5rem;
		font-weight: 700;
	}

	.gente {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(72px, 1fr));
		gap: var(--space-2);
	}

	.tizio {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 3px;
		padding: var(--space-2) 3px;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		cursor: pointer;
	}

	.tizio--on {
		background: var(--orange);
		color: var(--paper);
		border-width: var(--border);
		box-shadow: inset 3px 3px 0 rgba(22, 27, 61, 0.3);
	}

	.importo {
		display: flex;
		gap: var(--space-2);
		align-items: stretch;
	}

	.importo .field {
		text-align: center;
		font-size: 1.25rem;
		font-weight: 700;
	}

	.storia {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.riga {
		display: flex;
		align-items: center;
		gap: 5px;
		flex-wrap: wrap;
		padding-bottom: 5px;
	}

	.riga + .riga {
		border-top: 1px solid rgba(22, 27, 61, 0.15);
		padding-top: 5px;
	}

	.imp {
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		padding: 0 4px;
		font-weight: 700;
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}

	.ok {
		color: var(--green);
		font-weight: 700;
	}
</style>
