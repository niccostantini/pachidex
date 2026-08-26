<script lang="ts">
	import { onMount } from 'svelte';
	import {
		eliminaRequisito,
		eliminaSet,
		quanteCon,
		salvaRequisito,
		salvaSet,
		setAdmin,
		type Requisito,
		type SetGioco
	} from '$lib/db/set';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	type SetPieno = SetGioco & { requisiti: Requisito[] };

	let sets = $state<SetPieno[]>([]);
	let caricando = $state(true);
	let errore = $state<string | null>(null);
	let apertoId = $state<string | null>(null);

	/** Quanti elementi becca ogni parola chiave: si vede mentre si scrive. */
	let conteggi = $state<Record<string, number>>({});

	const TIPI = [
		{ v: 'parola', l: 'Un elemento che contiene la parola…' },
		{ v: 'tutte_parola', l: 'TUTTI gli elementi che contengono la parola…' },
		{ v: 'categoria', l: 'Un elemento di categoria…' },
		{ v: 'orario', l: 'Una cattura in una fascia oraria' },
		{ v: 'tutti_taggati', l: 'Una foto con tutto il gruppo' }
	];

	async function rileggi() {
		caricando = true;
		errore = null;
		try {
			sets = await setAdmin();
			for (const s of sets) {
				for (const r of s.requisiti) {
					if (r.tipo === 'parola' || r.tipo === 'tutte_parola') void conta(r.valore ?? '');
				}
			}
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	async function conta(parola: string) {
		const k = parola.trim().toLowerCase();
		if (!k || conteggi[k] !== undefined) return;
		try {
			conteggi[k] = await quanteCon(k);
		} catch {
			/* un conteggio mancante non e' un problema: e' solo un aiuto */
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

	function nuovoSet() {
		void agisci(async () => {
			const creato = await salvaSet({
				nome: 'Set senza nome',
				ordine: sets.length + 1
			});
			apertoId = creato.id;
		});
	}

	onMount(rileggi);
</script>

<div class="stack">
	<Finestra titolo="I set" variante="navy">
		<div class="stack">
			<p class="t-small">
				Un set è una lista di requisiti: chi li soddisfa tutti lo chiude e prende
				i Croquembouche, mentre i puntini vanno alla barra della storia — che è
				di tutti, quindi ogni giocatrice che lo completa la fa salire di nuovo.
			</p>
			<p class="t-small t-muted">
				Le parole chiave non fanno distinzione fra maiuscole e minuscole e cercano
				dentro il nome: «modica» prende sia il Castello dei Conti di Modica sia
				gli 'Mpanatigghi modicani. Il numero accanto dice quanti elementi becca:
				se è zero, il requisito non si potrà mai soddisfare.
			</p>
			<button class="btn btn--primary" onclick={nuovoSet}>Nuovo set</button>
		</div>
	</Finestra>

	{#if errore}
		<Finestra titolo="Errore" variante="navy"><p class="t-small">{errore}</p></Finestra>
	{/if}

	{#if caricando}
		<p class="t-label t-muted">Carico…</p>
	{:else}
		{#each sets as s (s.id)}
			<Finestra titolo={s.nome} variante={s.attivo ? 'blue' : 'navy'}>
				<div class="stack">
					<div class="riga">
						<button
							class="btn btn--sm"
							onclick={() => (apertoId = apertoId === s.id ? null : s.id)}
						>
							{apertoId === s.id ? 'Chiudi' : 'Modifica'}
						</button>
						<span class="t-small t-muted grow">
							{s.requisiti.length}
							{s.requisiti.length === 1 ? 'requisito' : 'requisiti'}
							· {s.croquembouche} ✦ · {s.punti_storia} puntini
							{#if s.giorno}· solo il {s.giorno}{/if}
							{#if s.stesso_giorno}· stessa giornata{/if}
						</span>
						<button
							class="btn btn--sm"
							onclick={() => agisci(() => salvaSet({ ...s, attivo: !s.attivo }))}
						>
							{s.attivo ? 'Spegni' : 'Accendi'}
						</button>
					</div>

					{#if apertoId === s.id}
						<div class="campi">
							<label class="campo">
								<span class="t-label">Nome</span>
								<input class="field" bind:value={s.nome} />
							</label>
							<label class="campo campo--largo">
								<span class="t-label">Descrizione</span>
								<input class="field" bind:value={s.descrizione} />
							</label>
							<label class="campo">
								<span class="t-label">Croquembouche</span>
								<input class="field" type="number" min="0" bind:value={s.croquembouche} />
							</label>
							<label class="campo">
								<span class="t-label">Puntini storia</span>
								<input class="field" type="number" min="0" bind:value={s.punti_storia} />
							</label>
							<label class="campo">
								<span class="t-label">Solo il giorno</span>
								<input class="field" type="date" bind:value={s.giorno} />
							</label>
							<label class="campo campo--riga">
								<input type="checkbox" bind:checked={s.stesso_giorno} />
								<span class="t-small">Tutto nella stessa giornata</span>
							</label>
							<label class="campo">
								<span class="t-label">Ordine</span>
								<input class="field" type="number" bind:value={s.ordine} />
							</label>
						</div>

						<div class="riga">
							<button class="btn btn--sm btn--ok" onclick={() => agisci(() => salvaSet(s))}>
								Salva il set
							</button>
							<span class="grow"></span>
							<button
								class="btn btn--sm btn--danger"
								onclick={() => {
									if (confirm(`Elimino "${s.nome}" e i suoi requisiti?`))
										void agisci(() => eliminaSet(s.id));
								}}
							>
								Elimina
							</button>
						</div>

						<p class="t-label">Requisiti</p>
						<ul class="req">
							{#each s.requisiti as r (r.id)}
								{@const k = (r.valore ?? '').trim().toLowerCase()}
								<li class="req__riga">
									<select class="field" bind:value={r.tipo}>
										{#each TIPI as t (t.v)}
											<option value={t.v}>{t.l}</option>
										{/each}
									</select>

									{#if r.tipo === 'parola' || r.tipo === 'tutte_parola'}
										<input
											class="field stretto"
											placeholder="parola"
											bind:value={r.valore}
											oninput={() => conta(r.valore ?? '')}
										/>
										<span class="quanti t-num" class:quanti--zero={conteggi[k] === 0}>
											{conteggi[k] ?? '—'}
										</span>
									{:else if r.tipo === 'categoria'}
										<select class="field stretto" bind:value={r.valore}>
											<option value="posto">posto</option>
											<option value="pietanza">pietanza</option>
											<option value="animale">animale</option>
											<option value="attivita">attivita</option>
										</select>
									{:else if r.tipo === 'orario'}
										<input class="field ore" type="number" min="0" max="23" bind:value={r.ora_da} />
										<input class="field ore" type="number" min="1" max="24" bind:value={r.ora_a} />
									{/if}

									<input class="field" placeholder="come si legge" bind:value={r.etichetta} />

									<button class="btn btn--sm btn--ok" onclick={() => agisci(() => salvaRequisito(r))}>
										Salva
									</button>
									<button
										class="btn btn--sm btn--danger"
										onclick={() => agisci(() => eliminaRequisito(r.id))}
									>
										×
									</button>
								</li>
							{/each}
						</ul>

						<button
							class="btn btn--sm"
							onclick={() =>
								agisci(() =>
									salvaRequisito({
										set_id: s.id,
										tipo: 'parola',
										valore: '',
										etichetta: 'Nuovo requisito',
										ordine: s.requisiti.length + 1
									})
								)}
						>
							Aggiungi requisito
						</button>
					{/if}
				</div>
			</Finestra>
		{/each}
	{/if}
</div>

<style>
	.riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
	}

	.campi {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: var(--space-2);
	}

	.campo {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.campo--largo {
		grid-column: 1 / -1;
	}

	.campo--riga {
		flex-direction: row;
		align-items: center;
		gap: 6px;
	}

	.req {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.req__riga {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-wrap: wrap;
	}

	.stretto {
		max-width: 160px;
	}

	.ore {
		max-width: 70px;
	}

	/* Il conteggio degli elementi agganciati: a zero e' rosso, perche' vuol
	   dire che quel requisito non si potra' mai soddisfare. */
	.quanti {
		font-weight: 700;
		min-width: 26px;
		text-align: center;
		background: var(--navy);
		color: var(--yellow);
		padding: 2px 5px;
	}

	.quanti--zero {
		background: var(--red);
		color: var(--paper);
	}
</style>
