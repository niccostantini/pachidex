<script lang="ts">
	import { onMount } from 'svelte';
	import { salvaConfig } from '$lib/db/admin';
	import { caricaConfig } from '$lib/db/dex';
	import {
		caricaPoste,
		contaLuoghi,
		luoghiSegnalati,
		rimettiLuogo,
		salvaPoste,
		type LuogoSegnalato,
		type RigaPosta
	} from '$lib/db/blocchi';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	const REGOLE: { chiave: string; label: string; aiuto: string }[] = [
		{
			chiave: 'blocchi_percento_celle',
			label: 'Celle con un blocco (%)',
			aiuto: 'Su 100 riquadri da 250 m con almeno un luogo, quanti hanno un blocco in ogni fascia.'
		},
		{
			chiave: 'blocchi_trappole_percento',
			label: 'Trappole (%)',
			aiuto: 'Su 100 blocchi, quanti tolgono invece di dare.'
		},
		{
			chiave: 'blocchi_durata_minuti',
			label: 'Durata di una fascia (minuti)',
			aiuto: 'Allo scadere i blocchi cambiano posto. 1440 = un giorno, da mezzanotte a mezzanotte. Minimo 5.'
		},
		{
			chiave: 'luoghi_segnalazioni_soglia',
			label: 'Segnalazioni per togliere un luogo',
			aiuto: 'Quante persone diverse devono dire che un posto non va.'
		}
	];

	let attivi = $state(false);
	let regole = $state<Record<string, number>>({});
	let poste = $state<RigaPosta[]>([]);
	let segnalati = $state<LuogoSegnalato[]>([]);
	let luoghi = $state({ totali: 0, attivi: 0 });
	let caricando = $state(true);
	let salvando = $state(false);
	let errore = $state<string | null>(null);
	let esito = $state<string | null>(null);

	const pesoTotale = $derived(poste.reduce((s, p) => s + Math.max(0, p.peso), 0));
	const quota = (p: RigaPosta) => (pesoTotale ? Math.round((p.peso / pesoTotale) * 100) : 0);
	/** Su un d20 la CD 10 si batte con 10..20: undici facce su venti. */
	const probabilita = (cd: number) => Math.round(((21 - Math.min(20, Math.max(1, cd))) / 20) * 100);

	async function rileggi() {
		errore = null;
		try {
			const [config, righe, elenco, conta] = await Promise.all([
				caricaConfig(),
				caricaPoste(),
				luoghiSegnalati(),
				contaLuoghi()
			]);
			attivi = (config.blocchi_attivi ?? 0) === 1;
			regole = Object.fromEntries(REGOLE.map((r) => [r.chiave, config[r.chiave] ?? 0]));
			poste = righe;
			segnalati = elenco;
			luoghi = conta;
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

	onMount(rileggi);
</script>

<div class="stack">
	<Finestra titolo="Blocchi ?" variante="navy">
		<div class="stack">
			<p class="t-small">
				Blocchi che compaiono su piazze, parchi e monumenti. Il primo che arriva lo apre e tira
				un d20: il colore dice la posta, non se è un premio o una trappola.
			</p>

			{#if caricando}
				<p class="t-label t-muted">Guardo come sta messa…</p>
			{:else}
				<div class="stato">
					<span class="pastiglia" class:pastiglia--ok={attivi}>{attivi ? 'accesi' : 'spenti'}</span>
					<span class="pastiglia" class:pastiglia--ok={luoghi.attivi > 0}>
						{luoghi.attivi} luoghi su {luoghi.totali}
					</span>
					<span class="pastiglia" class:pastiglia--ok={!segnalati.length}>
						{segnalati.length} segnalati
					</span>
				</div>

				<button
					class="btn"
					class:btn--danger={attivi}
					class:btn--ok={!attivi}
					disabled={salvando}
					onclick={() =>
						agisci(
							() => salvaConfig({ blocchi_attivi: attivi ? 0 : 1 }),
							attivi ? 'Blocchi spenti.' : 'Blocchi accesi.'
						)}
				>
					{attivi ? 'Spegni' : 'Accendi'}
				</button>

				{#if !luoghi.totali}
					<p class="t-small">
						Non c'è ancora nessun luogo. Si caricano da OpenStreetMap con
						<code>node scripts/importa-luoghi.mjs --prod</code>.
					</p>
				{/if}
			{/if}

			{#if errore}<p class="riga-errore t-small">{errore}</p>{/if}
			{#if esito}<p class="riga-ok t-small">{esito}</p>{/if}
		</div>
	</Finestra>

	<Finestra titolo="Le regole" variante="blue">
		<div class="stack">
			{#each REGOLE as r (r.chiave)}
				<label class="regola">
					<span class="t-label">{r.label}</span>
					<input class="field valore" type="number" inputmode="numeric" min="0" bind:value={regole[r.chiave]} />
					<span class="t-small t-muted">{r.aiuto}</span>
				</label>
			{/each}
			<button
				class="btn btn--primary"
				disabled={salvando}
				onclick={() => agisci(() => salvaConfig($state.snapshot(regole)), 'Regole salvate.')}
			>
				{salvando ? 'Salvo…' : 'Salva le regole'}
			</button>
		</div>
	</Finestra>

	<Finestra titolo="Le poste" variante="orange">
		<div class="stack">
			<table class="tabella t-small">
				<thead>
					<tr>
						<th>Posta</th>
						<th class="num">✦</th>
						<th class="num">CD</th>
						<th class="num">Peso</th>
						<th class="num">Esce</th>
						<th class="num">Riesce</th>
					</tr>
				</thead>
				<tbody>
					{#each poste as p, i (p.posta)}
						<tr>
							<td><i class="posta" style:background="var(--posta-{p.posta})"></i> {p.posta}</td>
							<td class="num"><input class="field corto" type="number" min="1" bind:value={poste[i].croquembouche} /></td>
							<td class="num"><input class="field corto" type="number" min="1" max="20" bind:value={poste[i].cd} /></td>
							<td class="num"><input class="field corto" type="number" min="0" bind:value={poste[i].peso} /></td>
							<td class="num">{quota(p)}%</td>
							<td class="num">{probabilita(p.cd)}%</td>
						</tr>
					{/each}
				</tbody>
			</table>
			<p class="t-small t-muted">
				"Riesce" è la probabilità di battere la CD: per un premio è quanto spesso si incassa, per
				una trappola quanto spesso la si schiva. I blocchi già aperti non cambiano: ognuno si porta
				dietro la CD e la posta che aveva.
			</p>
			<button
				class="btn btn--primary"
				disabled={salvando}
				onclick={() => agisci(() => salvaPoste(poste), 'Poste salvate.')}
			>
				{salvando ? 'Salvo…' : 'Salva le poste'}
			</button>
		</div>
	</Finestra>

	<Finestra titolo="Luoghi segnalati" variante="navy">
		{#if !segnalati.length}
			<p class="t-small t-muted">Nessun posto segnalato.</p>
		{:else}
			<table class="tabella t-small">
				<thead>
					<tr>
						<th>Luogo</th>
						<th class="num">Segn.</th>
						<th>Stato</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					{#each segnalati as l (l.id)}
						<tr>
							<td>
								<a href="https://www.openstreetmap.org/?mlat={l.lat}&mlon={l.lng}#map=18/{l.lat}/{l.lng}" target="_blank" rel="noopener">{l.nome}</a>
								<span class="t-muted">· {l.tipo}</span>
							</td>
							<td class="num">{l.segnalazioni}</td>
							<td>{l.attivo ? 'in gioco' : 'fuori'}</td>
							<td class="num">
								<button
									class="btn btn--sm"
									disabled={salvando}
									onclick={() => agisci(() => rimettiLuogo(l.id), `${l.nome} rimesso in gioco.`)}
								>
									rimetti
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
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

	.regola {
		display: grid;
		gap: 4px;
	}

	.valore {
		width: 6rem;
		text-align: right;
	}

	.corto {
		width: 4rem;
		text-align: right;
	}

	.posta {
		display: inline-block;
		width: 10px;
		height: 10px;
		border: var(--border-thin) solid var(--navy);
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
