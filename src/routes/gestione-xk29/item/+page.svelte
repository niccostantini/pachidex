<script lang="ts">
	import { onMount } from 'svelte';
	import { attivaItem, eliminaItem, salvaItem, tuttiGliItem } from '$lib/db/admin';
	import { caricaConfig } from '$lib/db/dex';
	import { CATEGORIE, RARITA, etichettaCategoria } from '$lib/game/rules';
	import { schermo } from '$lib/state/schermo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';
	import Foglio from '$lib/components/Foglio.svelte';
	import Rarita from '$lib/components/Rarita.svelte';
	import type { Categoria, Item, Rarita as TRarita, Validazione } from '$lib/types';

	let item = $state<Item[]>([]);
	let config = $state<Record<string, number>>({});
	let filtro = $state<Categoria | 'tutte'>('tutte');
	let cerca = $state('');
	let caricando = $state(true);
	let errore = $state<string | null>(null);

	let modifica = $state<Partial<Item> | null>(null);
	let salvando = $state(false);
	let erroreForm = $state<string | null>(null);

	const visibili = $derived(
		item
			.filter((i) => filtro === 'tutte' || i.categoria === filtro)
			.filter((i) => !cerca.trim() || i.nome.toLowerCase().includes(cerca.trim().toLowerCase()))
	);

	async function rileggi() {
		caricando = true;
		try {
			[item, config] = await Promise.all([tuttiGliItem(), caricaConfig()]);
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	onMount(rileggi);

	function nuovo() {
		modifica = {
			nome: '',
			categoria: 'pietanza',
			rarita: 'comune',
			croquembouche: config.croq_comune ?? 10,
			ripetibile: false,
			validazione: 'foto',
			note: null,
			lat: null,
			lng: null,
			attivo: true
		};
		erroreForm = null;
	}

	// Cambiando rarita' il valore si riallinea al default, ma solo se non e'
	// stato ritoccato a mano: altrimenti si perderebbe una scelta voluta.
	function cambiaRarita(r: TRarita) {
		if (!modifica) return;
		const eraDefault = RARITA.some(
			(x) => modifica?.croquembouche === (config[`croq_${x.valore}`] ?? x.croq)
		);
		modifica.rarita = r;
		if (eraDefault) modifica.croquembouche = config[`croq_${r}`] ?? 10;
	}

	function cambiaCategoria(c: Categoria) {
		if (!modifica) return;
		modifica.categoria = c;
		if (c !== 'posto' && modifica.validazione === 'auto_gps') modifica.validazione = 'foto';
	}

	async function salva() {
		if (!modifica?.nome?.trim()) {
			erroreForm = 'Il nome serve.';
			return;
		}
		if (modifica.validazione === 'auto_gps' && (modifica.lat == null || modifica.lng == null)) {
			erroreForm = 'Un checkpoint GPS ha bisogno di lat e lng.';
			return;
		}
		salvando = true;
		erroreForm = null;
		try {
			await salvaItem({ ...(modifica as Item), nome: modifica.nome.trim() });
			modifica = null;
			await rileggi();
		} catch (e) {
			erroreForm = messaggioErrore(e);
		} finally {
			salvando = false;
		}
	}

	async function elimina(i: Item) {
		if (!confirm(`Elimino "${i.nome}"? Sparisce anche dalle catture gia' fatte.`)) return;
		try {
			await eliminaItem(i.id);
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		}
	}

	async function alterna(i: Item) {
		await attivaItem(i.id, !i.attivo);
		await rileggi();
	}
</script>

<div class="stack">
	<Finestra titolo="Le sfiziosita" variante="navy">
		<div class="filtri">
			<input class="field cerca" type="search" bind:value={cerca} placeholder="Cerca…" />
			<select class="field" bind:value={filtro}>
				<option value="tutte">Tutte le categorie</option>
				{#each CATEGORIE as c (c.valore)}
					<option value={c.valore}>{c.plurale}</option>
				{/each}
			</select>
			<button class="btn btn--primary" onclick={nuovo}>+ Aggiungi</button>
		</div>

		<p class="t-small t-muted conteggio">
			{visibili.length} di {item.length} elementi
		</p>

		{#if caricando}
			<p class="t-label t-muted">Carico…</p>
		{:else if errore}
			<p class="errore t-small">{errore}</p>
		{:else if !visibili.length}
			<p class="empty t-small">Niente qui. Aggiungi un elemento o importa un CSV.</p>
		{:else if schermo.largo}
			<!-- Desktop: tabella, si scorre con gli occhi -->
			<table class="tab">
				<thead>
					<tr>
						<th>Nome</th>
						<th>Categoria</th>
						<th>Rarita</th>
						<th class="dx">✦</th>
						<th>Ripet.</th>
						<th>Validaz.</th>
						<th>Stato</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					{#each visibili as i (i.id)}
						<tr class:spenta={!i.attivo}>
							<td><strong>{i.nome}</strong></td>
							<td>{etichettaCategoria(i.categoria)}</td>
							<td><Rarita rarita={i.rarita} /></td>
							<td class="dx t-num">{i.croquembouche}</td>
							<td>{i.ripetibile ? 'si' : 'no'}</td>
							<td>{i.validazione === 'auto_gps' ? 'GPS' : 'foto'}</td>
							<td>{i.attivo ? 'attiva' : 'spenta'}</td>
							<td class="azioni">
								<button class="btn btn--sm" onclick={() => (modifica = { ...i })}>Modifica</button>
								<button class="btn btn--sm" onclick={() => alterna(i)}>
									{i.attivo ? 'Spegni' : 'Riaccendi'}
								</button>
								<button class="btn btn--sm btn--danger" onclick={() => elimina(i)}>×</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{:else}
			<!-- Mobile: card, si toccano col pollice -->
			<ul class="carte">
				{#each visibili as i (i.id)}
					<li class="carta" class:spenta={!i.attivo}>
						<div class="carta__testa">
							<strong class="grow">{i.nome}</strong>
							<Rarita rarita={i.rarita} croquembouche={i.croquembouche} />
						</div>
						<p class="t-small t-muted">
							{etichettaCategoria(i.categoria)}
							· {i.validazione === 'auto_gps' ? 'GPS' : 'foto'}
							{#if i.ripetibile}· ripetibile{/if}
							{#if !i.attivo}· <strong>spenta</strong>{/if}
						</p>
						<div class="carta__azioni">
							<button class="btn btn--sm grow" onclick={() => (modifica = { ...i })}>
								Modifica
							</button>
							<button class="btn btn--sm" onclick={() => alterna(i)}>
								{i.attivo ? 'Spegni' : 'Riaccendi'}
							</button>
							<button class="btn btn--sm btn--danger" onclick={() => elimina(i)}>×</button>
						</div>
					</li>
				{/each}
			</ul>
		{/if}
	</Finestra>
</div>

<Foglio
	aperto={!!modifica}
	titolo={modifica?.id ? 'Modifica elemento' : 'Nuovo elemento'}
	onChiudi={() => (modifica = null)}
>
	{#if modifica}
		<div class="stack">
			<div class="field-row">
				<label class="field-label" for="f-nome">Nome</label>
				<input id="f-nome" class="field" bind:value={modifica.nome} />
			</div>

			<div class="due">
				<div class="field-row">
					<label class="field-label" for="f-cat">Categoria</label>
					<select
						id="f-cat"
						class="field"
						value={modifica.categoria}
						onchange={(e) => cambiaCategoria(e.currentTarget.value as Categoria)}
					>
						{#each CATEGORIE as c (c.valore)}
							<option value={c.valore}>{c.label}</option>
						{/each}
					</select>
				</div>

				<div class="field-row">
					<label class="field-label" for="f-rar">Rarita</label>
					<select
						id="f-rar"
						class="field"
						value={modifica.rarita}
						onchange={(e) => cambiaRarita(e.currentTarget.value as TRarita)}
					>
						{#each RARITA as r (r.valore)}
							<option value={r.valore}>{r.label}</option>
						{/each}
					</select>
				</div>
			</div>

			<div class="due">
				<div class="field-row">
					<label class="field-label" for="f-croq">Croquembouche</label>
					<input id="f-croq" class="field t-num" type="number" min="0" bind:value={modifica.croquembouche} />
				</div>

				<div class="field-row">
					<label class="field-label" for="f-val">Validazione</label>
					<select
						id="f-val"
						class="field"
						bind:value={modifica.validazione}
						disabled={modifica.categoria !== 'posto'}
					>
						<option value="foto">Foto + autocertificazione</option>
						<option value="auto_gps">GPS automatico</option>
					</select>
				</div>
			</div>

			{#if modifica.categoria !== 'posto'}
				<p class="t-small t-muted">Il GPS vale solo per i posti.</p>
			{/if}

			{#if modifica.validazione === 'auto_gps' || modifica.categoria === 'posto'}
				<div class="due">
					<div class="field-row">
						<label class="field-label" for="f-lat">Latitudine</label>
						<input id="f-lat" class="field t-num" type="number" step="any" bind:value={modifica.lat} />
					</div>
					<div class="field-row">
						<label class="field-label" for="f-lng">Longitudine</label>
						<input id="f-lng" class="field t-num" type="number" step="any" bind:value={modifica.lng} />
					</div>
				</div>
			{/if}

			<div class="field-row">
				<label class="field-label" for="f-note">Note</label>
				<textarea id="f-note" class="field" rows="2" bind:value={modifica.note}></textarea>
			</div>

			<label class="check">
				<input type="checkbox" bind:checked={modifica.ripetibile} />
				<span>Ripetibile — si puo' catturare piu' volte, sempre a valore pieno</span>
			</label>

			<label class="check">
				<input type="checkbox" bind:checked={modifica.attivo} />
				<span>Attiva — visibile ai giocatori</span>
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
	.filtri {
		display: flex;
		gap: var(--space-2);
		flex-wrap: wrap;
		margin-bottom: var(--space-2);
	}

	.cerca {
		flex: 1;
		min-width: 140px;
	}

	.filtri select {
		width: auto;
	}

	.conteggio {
		margin-bottom: var(--space-2);
	}

	.tab {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.8125rem;
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
		vertical-align: middle;
	}

	.dx {
		text-align: right;
	}

	.azioni {
		display: flex;
		gap: 4px;
		justify-content: flex-end;
	}

	.spenta {
		opacity: 0.5;
	}

	.carte {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.carta {
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.carta__testa {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.carta__azioni {
		display: flex;
		gap: 4px;
	}

	.due {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2);
	}

	.check {
		display: flex;
		gap: var(--space-2);
		align-items: flex-start;
		font-size: 0.875rem;
	}

	.check input {
		width: 20px;
		height: 20px;
		accent-color: var(--orange);
		flex-shrink: 0;
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
