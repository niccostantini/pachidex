<script lang="ts">
	import { onMount } from 'svelte';
	import { capitoliAdmin, caricaStoria, salvaCapitolo, type Capitolo, type StatoStoria } from '$lib/db/storia';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let capitoli = $state<Capitolo[]>([]);
	let storia = $state<StatoStoria | null>(null);
	let caricando = $state(true);
	let salvando = $state(false);
	let salvato = $state(false);
	let errore = $state<string | null>(null);

	// Copia modificabile: si salva solo cio' che e' cambiato davvero.
	let bozza = $state<Record<number, { soglia: number; titolo: string }>>({});

	const cambiati = $derived(
		capitoli.filter(
			(c) =>
				bozza[c.numero] &&
				(bozza[c.numero].soglia !== c.soglia || bozza[c.numero].titolo !== (c.titolo ?? ''))
		)
	);

	const crescenti = $derived.by(() => {
		const s = capitoli.map((c) => bozza[c.numero]?.soglia ?? c.soglia);
		return s.every((v, i) => i === 0 || v > s[i - 1]);
	});

	async function rileggi() {
		caricando = true;
		try {
			[capitoli, storia] = await Promise.all([capitoliAdmin(), caricaStoria()]);
			bozza = Object.fromEntries(
				capitoli.map((c) => [c.numero, { soglia: c.soglia, titolo: c.titolo ?? '' }])
			);
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	onMount(rileggi);

	async function salva() {
		salvando = true;
		errore = null;
		try {
			for (const c of cambiati) {
				await salvaCapitolo(c.numero, {
					soglia: bozza[c.numero].soglia,
					titolo: bozza[c.numero].titolo
				});
			}
			await rileggi();
			salvato = true;
			setTimeout(() => (salvato = false), 2500);
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			salvando = false;
		}
	}
</script>

<div class="stack">
	<Finestra titolo="La storia" variante="navy">
		{#if caricando}
			<p class="t-label t-muted">Carico…</p>
		{:else if storia}
			<div class="sommario">
				<div class="n">
					<span class="n__v t-num">{storia.punti}</span>
					<span class="t-label">puntini raccolti</span>
				</div>
				<div class="n">
					<span class="n__v t-num">{capitoli.filter((c) => c.sbloccato).length}/{capitoli.length}</span>
					<span class="t-label">capitoli sbloccati</span>
				</div>
			</div>
			<p class="t-small t-muted nota">
				I puntini sono la somma dei croquembouche di tutte le catture valide del gruppo.
				Non li muovono gli scambi, e una cattura invalidata li restituisce da sola.
			</p>
		{/if}
	</Finestra>

	<Finestra titolo="Soglie e titoli" variante="blue">
		{#if !caricando}
			<p class="t-small t-muted avviso">
				I titoli si vedono <strong>solo a capitolo sbloccato</strong>: prima non escono
				nemmeno dalla risposta di rete. Lasciali vuoti se preferisci mostrare solo il numero.
			</p>

			<div class="righe">
				{#each capitoli as c (c.numero)}
					<div class="riga" class:riga--sbloccato={c.sbloccato}>
						<span class="num t-num">{c.numero}</span>

						<label class="campo campo--soglia">
							<span class="field-label">Soglia</span>
							<input
								class="field t-num"
								type="number"
								min="0"
								disabled={c.numero === 1}
								bind:value={bozza[c.numero].soglia}
							/>
						</label>

						<label class="campo grow">
							<span class="field-label">Titolo</span>
							<input
								class="field"
								placeholder="(solo il numero)"
								bind:value={bozza[c.numero].titolo}
							/>
						</label>

						<span class="stato t-label">
							{c.sbloccato ? 'sbloccato' : '—'}
						</span>
					</div>
				{/each}
			</div>

			{#if !crescenti}
				<p class="t-small errore">
					Le soglie devono crescere capitolo dopo capitolo: cosi' com'e', qualcuno si
					sbloccherebbe prima del precedente.
				</p>
			{/if}

			{#if errore}<p class="t-small errore">{errore}</p>{/if}

			<div class="salva">
				<button
					class="btn btn--primary"
					onclick={salva}
					disabled={!cambiati.length || !crescenti || salvando}
				>
					{salvando
						? 'Salvo…'
						: cambiati.length
							? `Salva ${cambiati.length} modifiche`
							: 'Niente da salvare'}
				</button>
				{#if salvato}<span class="ok t-label">Salvato</span>{/if}
			</div>

			<p class="t-small t-muted nota">
				Abbassare una soglia sotto i puntini gia' raccolti sblocca il capitolo alla
				prossima cattura. Alzarla sopra non richiude quelli gia' aperti: lo sblocco e' una
				data, non una condizione.
			</p>
		{/if}
	</Finestra>
</div>

<style>
	.sommario {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
		gap: var(--space-2);
	}

	.n {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: var(--space-3);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.n__v {
		font-size: 1.75rem;
		font-weight: 700;
		line-height: 1;
	}

	.nota {
		margin-top: var(--space-2);
	}

	.avviso {
		background: rgba(245, 197, 24, 0.22);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
		margin-bottom: var(--space-3);
	}

	.righe {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin-bottom: var(--space-3);
	}

	.riga {
		display: flex;
		align-items: flex-end;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		flex-wrap: wrap;
	}

	.riga--sbloccato {
		background: rgba(245, 197, 24, 0.18);
	}

	.num {
		width: 30px;
		height: 30px;
		display: grid;
		place-items: center;
		background: var(--navy);
		color: var(--paper);
		font-weight: 700;
		flex-shrink: 0;
	}

	.campo {
		display: flex;
		flex-direction: column;
	}

	.campo--soglia {
		width: 96px;
	}

	.stato {
		color: var(--navy-soft);
		align-self: center;
	}

	.salva {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.ok {
		color: var(--green);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
