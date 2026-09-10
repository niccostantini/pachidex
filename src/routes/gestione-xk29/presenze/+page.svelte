<script lang="ts">
	import { onMount } from 'svelte';
	import { salvaConfig } from '$lib/db/admin';
	import { caricaConfig } from '$lib/db/dex';
	import {
		presenzeDiTutti,
		salvaScala,
		scalaPresenze,
		type Gradino,
		type RigaPresenza
	} from '$lib/db/presenze';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let attive = $state(false);
	let scala = $state<Gradino[]>([]);
	let righe = $state<RigaPresenza[]>([]);
	let caricando = $state(true);
	let salvando = $state(false);
	let errore = $state<string | null>(null);
	let esito = $state<string | null>(null);

	const ultimo = $derived(scala.length ? scala[scala.length - 1].croquembouche : 0);
	const primo = $derived(scala.length ? scala[0].croquembouche : 0);

	async function rileggi() {
		errore = null;
		try {
			const [config, gradini, elenco] = await Promise.all([
				caricaConfig(),
				scalaPresenze(),
				presenzeDiTutti()
			]);
			attive = (config.presenze_attive ?? 0) === 1;
			scala = gradini;
			righe = elenco;
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	async function agisci(fn: () => Promise<unknown>, detto: string) {
		salvando = true;
		errore = null;
		esito = null;
		try {
			await fn();
			esito = detto;
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			salvando = false;
		}
	}

	function aggiungi() {
		scala = [...scala, { passo: scala.length + 1, croquembouche: ultimo }];
	}

	function togli(i: number) {
		scala = scala.filter((_, n) => n !== i).map((g, n) => ({ ...g, passo: n + 1 }));
	}

	onMount(rileggi);
</script>

<div class="stack">
	<Finestra titolo="Premi presenza" variante="navy">
		<div class="stack">
			<p class="t-small">
				Chi apre l'app in giorni consecutivi prende Croquembouche crescenti. Basta
				saltare un giorno e si riparte dal primo gradino.
			</p>

			{#if caricando}
				<p class="t-label t-muted">Guardo come sta messa…</p>
			{:else}
				<div class="stato">
					<span class="pastiglia" class:pastiglia--ok={attive}>
						{attive ? 'accesi' : 'spenti'}
					</span>
					<span class="pastiglia" class:pastiglia--ok={scala.length > 0}>
						{scala.length}
						{scala.length === 1 ? 'gradino' : 'gradini'}
					</span>
					<span class="pastiglia" class:pastiglia--ok={righe.some((r) => r.striscia > 0)}>
						{righe.filter((r) => r.striscia > 0).length} in striscia
					</span>
				</div>

				<button
					class="btn"
					class:btn--danger={attive}
					class:btn--ok={!attive}
					disabled={salvando}
					onclick={() =>
						agisci(
							() => salvaConfig({ presenze_attive: attive ? 0 : 1 }),
							attive ? 'Premi spenti.' : 'Premi accesi.'
						)}
				>
					{attive ? 'Spegni' : 'Accendi'}
				</button>

				<p class="t-small t-muted">
					Spegnendoli le strisce restano dove sono: riaccendendo si riprende da lì, non
					da capo. Admin e Spione non prendono niente in nessun caso — stanno fuori
					dalla partita.
				</p>
			{/if}

			{#if errore}<p class="riga-errore t-small">{errore}</p>{/if}
			{#if esito}<p class="riga-ok t-small">{esito}</p>{/if}
		</div>
	</Finestra>

	<Finestra titolo="La scala" variante="blue">
		<div class="stack">
			<p class="t-small">
				Quanto vale ogni giorno di fila. Dopo l'ultimo gradino la scala
				<strong>riparte da capo</strong>: chi arriva al giorno {scala.length || '—'}
				prende {ultimo} ✦, e il giorno dopo si ricomincia da {primo} ✦. La striscia
				invece continua a contare.
			</p>

			<ul class="scala">
				{#each scala as g, i (i)}
					<li class="gradino">
						<span class="t-label giorno">Giorno {i + 1}</span>
						<input
							class="field valore"
							type="number"
							inputmode="numeric"
							min="0"
							bind:value={scala[i].croquembouche}
						/>
						<span class="t-label">✦</span>
						<button
							class="btn btn--sm"
							onclick={() => togli(i)}
							aria-label="Togli il giorno {i + 1}"
						>
							togli
						</button>
					</li>
				{/each}
			</ul>

			<div class="azioni">
				<button class="btn btn--sm" onclick={aggiungi}>Aggiungi un giorno</button>
				<button
					class="btn btn--primary"
					disabled={salvando}
					onclick={() => agisci(() => salvaScala(scala), 'Scala salvata.')}
				>
					{salvando ? 'Salvo…' : 'Salva la scala'}
				</button>
			</div>

			<p class="t-small t-muted">
				I premi già dati non cambiano: ogni presenza si porta dietro quanto valeva quel
				giorno. Alzare il terzo gradino non regala nulla a chi c'era ieri.
			</p>
		</div>
	</Finestra>

	<Finestra titolo="Chi torna" variante="orange">
		{#if !righe.length}
			<p class="t-small t-muted">Ancora nessuno.</p>
		{:else}
			<table class="tabella t-small">
				<thead>
					<tr>
						<th>Chi</th>
						<th class="num">Di fila</th>
						<th class="num">Giorni</th>
						<th class="num">Presi</th>
						<th>Ultima volta</th>
					</tr>
				</thead>
				<tbody>
					{#each righe as r (r.user_id)}
						<tr>
							<td>{r.nome}</td>
							<td class="num"><strong>{r.striscia}</strong></td>
							<td class="num">{r.giorni}</td>
							<td class="num">{r.croquembouche} ✦</td>
							<td>{r.ultimo_giorno ?? '—'}</td>
						</tr>
					{/each}
				</tbody>
			</table>

			<p class="t-small t-muted">
				"Di fila" torna a zero appena si salta un giorno, anche se la colonna dei giorni
				totali resta.
			</p>
		{/if}
	</Finestra>
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

	.scala {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.gradino {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.giorno {
		min-width: 5.5rem;
	}

	.valore {
		width: 5rem;
		text-align: right;
	}

	.azioni {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
		align-items: center;
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

	.tabella .num {
		text-align: right;
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
