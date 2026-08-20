<script lang="ts">
	import { importaItem } from '$lib/db/admin';
	import { COLONNE_CSV, scaricaTemplate, validaCSV, type EsitoImport } from '$lib/game/csv';
	import { etichettaCategoria } from '$lib/game/rules';
	import { schermo } from '$lib/state/schermo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let esito = $state<EsitoImport | null>(null);
	let nomeFile = $state('');
	let sopra = $state(false);
	let importando = $state(false);
	let progresso = $state({ fatte: 0, totali: 0 });
	let risultato = $state<{ inserite: number; falliti: { nome: string; motivo: string }[] } | null>(
		null
	);
	let errore = $state<string | null>(null);

	async function leggi(file: File) {
		nomeFile = file.name;
		risultato = null;
		errore = null;
		try {
			esito = validaCSV(await file.text());
		} catch (e) {
			errore = messaggioErrore(e);
		}
	}

	function suFile(e: Event) {
		const f = (e.currentTarget as HTMLInputElement).files?.[0];
		if (f) void leggi(f);
	}

	function suDrop(e: DragEvent) {
		e.preventDefault();
		sopra = false;
		const f = e.dataTransfer?.files?.[0];
		if (f) void leggi(f);
	}

	async function importa() {
		if (!esito?.valide.length) return;
		importando = true;
		progresso = { fatte: 0, totali: esito.valide.length };
		try {
			risultato = await importaItem(
				esito.valide.map((r) => r.dati!),
				(fatte, totali) => (progresso = { fatte, totali })
			);
			esito = null;
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			importando = false;
		}
	}
</script>

<div class="stack">
	<Finestra titolo="Importa il PachiDex" variante="navy">
		<div class="stack">
			<p class="t-small">
				Colonne attese: <code>{COLONNE_CSV.join(', ')}</code>. Le righe buone entrano comunque,
				quelle rotte te le segnalo una per una senza bloccare le altre.
			</p>

			<button class="btn btn--sm" onclick={scaricaTemplate}>Scarica il template CSV</button>

			<label
				class="zona"
				class:zona--sopra={sopra}
				ondragover={(e) => (e.preventDefault(), (sopra = true))}
				ondragleave={() => (sopra = false)}
				ondrop={suDrop}
			>
				<span class="zona__icona" aria-hidden="true">▤</span>
				{#if schermo.largo}
					<span class="t-label">Trascina qui il CSV</span>
					<span class="t-small t-muted">oppure tocca per sceglierlo</span>
				{:else}
					<span class="t-label">Scegli il file CSV</span>
				{/if}
				{#if nomeFile}<span class="t-small">{nomeFile}</span>{/if}
				<input type="file" accept=".csv,text/csv" onchange={suFile} class="visually-hidden" />
			</label>

			{#if errore}<p class="errore t-small">{errore}</p>{/if}
		</div>
	</Finestra>

	{#if esito?.intestazioniMancanti.length}
		<Finestra titolo="Intestazioni mancanti" variante="orange">
			<p class="t-small">
				Nel file non trovo: <strong>{esito.intestazioniMancanti.join(', ')}</strong>. Servono almeno
				nome, categoria e rarita.
			</p>
		</Finestra>
	{/if}

	{#if esito && !esito.intestazioniMancanti.length}
		<Finestra titolo="Anteprima" variante="blue">
			<div class="bilancio">
				<span class="pill pill--ok">{esito.valide.length} pronte</span>
				{#if esito.invalide.length}
					<span class="pill pill--ko">{esito.invalide.length} da sistemare</span>
				{/if}
			</div>

			{#if esito.invalide.length}
				<div class="errori">
					<p class="t-label">Righe scartate</p>
					<ul class="t-small">
						{#each esito.invalide as r (r.numero)}
							<li>
								<strong>Riga {r.numero}</strong> — {r.errori.join(' · ')}
							</li>
						{/each}
					</ul>
				</div>
			{/if}

			{#if esito.valide.length}
				{#if schermo.largo}
					<table class="tab">
						<thead>
							<tr>
								<th>#</th>
								<th>Nome</th>
								<th>Categoria</th>
								<th>Rarita</th>
								<th class="dx">✦</th>
								<th>Ripet.</th>
								<th>Validaz.</th>
								<th>Coordinate</th>
							</tr>
						</thead>
						<tbody>
							{#each esito.valide as r (r.numero)}
								<tr>
									<td class="t-muted">{r.numero}</td>
									<td><strong>{r.dati?.nome}</strong></td>
									<td>{etichettaCategoria(r.dati!.categoria)}</td>
									<td>{r.dati?.rarita}</td>
									<td class="dx t-num">{r.dati?.croquembouche}</td>
									<td>{r.dati?.ripetibile ? 'si' : 'no'}</td>
									<td>{r.dati?.validazione === 'foto_gps' ? 'foto+GPS' : 'foto'}</td>
									<td class="t-num t-small">
										{r.dati?.lat != null ? `${r.dati.lat}, ${r.dati.lng}` : '—'}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{:else}
					<ul class="carte">
						{#each esito.valide as r (r.numero)}
							<li class="carta">
								<strong>{r.dati?.nome}</strong>
								<span class="t-small t-muted">
									{etichettaCategoria(r.dati!.categoria)} · {r.dati?.rarita} · ✦{r.dati
										?.croquembouche}
									{r.dati?.validazione === 'foto_gps' ? '· foto+GPS' : ''}
								</span>
							</li>
						{/each}
					</ul>
				{/if}

				<button class="btn btn--primary btn--block" onclick={importa} disabled={importando}>
					{importando
						? `Importo ${progresso.fatte}/${progresso.totali}…`
						: `Importa ${esito.valide.length} elementi`}
				</button>
			{/if}
		</Finestra>
	{/if}

	{#if risultato}
		<Finestra titolo="Fatto" variante="green">
			<p><strong>{risultato.inserite}</strong> elementi importati.</p>
			{#if risultato.falliti.length}
				<p class="t-small">Questi no:</p>
				<ul class="t-small errori-lista">
					{#each risultato.falliti as f (f.nome)}
						<li><strong>{f.nome}</strong> — {f.motivo}</li>
					{/each}
				</ul>
			{/if}
			<a class="btn btn--sm" href="/gestione-xk29/item">Vai agli elementi</a>
		</Finestra>
	{/if}
</div>

<style>
	.zona {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 5px;
		padding: var(--space-6) var(--space-4);
		background: var(--cream);
		border: var(--border) dashed var(--navy);
		cursor: pointer;
		text-align: center;
	}

	.zona--sopra {
		background: var(--yellow);
		border-style: solid;
	}

	.zona__icona {
		font-size: 2rem;
		line-height: 1;
	}

	code {
		background: var(--cream);
		padding: 1px 4px;
		font-size: 0.8125rem;
		word-break: break-word;
	}

	.bilancio {
		display: flex;
		gap: var(--space-2);
		margin-bottom: var(--space-2);
	}

	.pill {
		padding: 3px 9px;
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
	}

	.pill--ok {
		background: var(--green);
		color: var(--paper);
	}

	.pill--ko {
		background: var(--red);
		color: var(--paper);
	}

	.errori {
		background: rgba(217, 59, 50, 0.12);
		border: var(--border-thin) solid var(--red);
		padding: var(--space-2);
		margin-bottom: var(--space-3);
	}

	.errori ul,
	.errori-lista {
		display: flex;
		flex-direction: column;
		gap: 3px;
		margin-top: 4px;
	}

	.tab {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8125rem;
		margin-bottom: var(--space-3);
	}

	.tab th {
		text-align: left;
		text-transform: uppercase;
		font-size: 0.625rem;
		letter-spacing: 0.08em;
		padding: 5px;
		background: var(--navy);
		color: var(--paper);
	}

	.tab td {
		padding: 5px;
		border-bottom: 1px solid rgba(22, 27, 61, 0.18);
	}

	.dx {
		text-align: right;
	}

	.carte {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-bottom: var(--space-3);
		max-height: 50dvh;
		overflow-y: auto;
	}

	.carta {
		display: flex;
		flex-direction: column;
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		padding: 5px var(--space-2);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
