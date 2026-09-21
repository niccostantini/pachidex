<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import {
		classificaStagione,
		coccardeStagione,
		fotoStagione,
		segnaWrappedVisto,
		wrapped,
		type FotoStagione,
		type RigaStagione,
		type Wrapped
	} from '$lib/db/stagioni';
	import type { Coccarda } from '$lib/db/coccarde';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import Coriandoli from '$lib/components/Coriandoli.svelte';

	/**
	 * «Queste siete»: la stagione che si e' appena chiusa, una cosa per volta.
	 *
	 * Si va avanti a tappe e non tutto in una schermata perche' e' una
	 * premiazione: se i titoli compaiono tutti insieme, chi li ha vinti non se
	 * ne accorge. Aprendola si segna che l'hai vista — ed e' quel segno che, a
	 * conti fatti, lascia cancellare le foto.
	 */
	let dati = $state<Wrapped | null>(null);
	let righe = $state<RigaStagione[]>([]);
	let coccarde = $state<Coccarda[]>([]);
	let foto = $state<FotoStagione[]>([]);
	let stato = $state<'carico' | 'ok' | 'niente' | 'errore'>('carico');
	let errore = $state<string | null>(null);
	let tappa = $state(0);

	const chi = (id: string) => profilo.utenti.find((u) => u.id === id) ?? null;
	const nome = (id: string) => chi(id)?.nome ?? '?';

	/**
	 * Un titolo per tappa, non una coccarda per tappa.
	 *
	 * A pari merito le coccarde sono due ma il titolo e' uno: mostrarle di
	 * fila vorrebbe dire due schermate identiche una dopo l'altra, e la
	 * seconda sembrerebbe un errore invece che meta' della notizia. Si
	 * raggruppano per titolo e si annunciano insieme, che e' anche il modo in
	 * cui e' successo.
	 */
	const titoli = $derived.by(() => {
		const per = new Map<string, Coccarda[]>();
		for (const c of coccarde) {
			if (c.tipo !== 'titolo') continue;
			per.set(c.chiave, [...(per.get(c.chiave) ?? []), c]);
		}
		return [...per.values()];
	});

	/**
	 * Quanta festa fare, tappa per tappa.
	 *
	 * Non la stessa dappertutto: se i coriandoli cadono uguali dall'inizio
	 * alla fine smettono di voler dire qualcosa dopo dieci secondi. Il podio
	 * apre in grande, i titoli sono scoppiettii secchi sul nome di chi ha
	 * vinto, e le foto finali tornano a una pioggia larga per chiudere.
	 */
	const festa = $derived.by(() => {
		if (tappa === 0) return { quanti: 60, scoppi: 4, larghezza: 'piena' as const };
		if (tappa <= titoli.length) return { quanti: 18, scoppi: 3, larghezza: 'centro' as const };
		return { quanti: 70, scoppi: 5, larghezza: 'piena' as const };
	});
	/** Podio, poi un titolo per volta, poi le foto. */
	const tappe = $derived(2 + titoli.length);
	const ultima = $derived(tappa >= tappe - 1);

	onMount(async () => {
		try {
			dati = await wrapped();
			if (!dati) {
				stato = 'niente';
				return;
			}
			[righe, coccarde, foto] = await Promise.all([
				classificaStagione(dati.stagione),
				coccardeStagione(dati.stagione),
				fotoStagione(dati.stagione)
			]);
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
		}

		// Il segno si mette all'apertura, non alla fine: chi la chiude a meta'
		// l'ha vista lo stesso, e non e' giusto tenere ferme le foto di tutti
		// perche' qualcuno non e' arrivato in fondo.
		//
		// E sta fuori dal blocco di sopra, con il suo silenzio: e' una casella
		// da spuntare, non il contenuto della pagina. Stando dentro, una rete
		// ballerina sostituiva il Wrapped gia' caricato con una schermata di
		// errore — per una chiamata che al lettore non interessa. Se non
		// arriva, pazienza: dopo ventiquattr'ore si cancella lo stesso.
		if (dati) {
			try {
				await segnaWrappedVisto(dati.stagione);
			} catch {
				/* riproveremo alla prossima apertura */
			}
		}
	});
</script>

<svelte:head><title>Queste siete — Pachino Express</title></svelte:head>

<div class="wrap">
	{#if stato === 'carico'}
		<p class="t-label t-muted">Rimetto insieme la stagione…</p>
	{:else if stato === 'niente'}
		<Finestra titolo="Non ancora" variante="navy" onChiudi={() => goto('/')}>
			<p class="t-small">
				Nessuna stagione si è ancora chiusa. Quando succede, questa pagina racconta
				com'è andata.
			</p>
		</Finestra>
	{:else if stato === 'errore'}
		<Finestra titolo="Errore" variante="navy" onChiudi={() => goto('/')}>
			<p class="t-small">{errore}</p>
		</Finestra>
	{:else if dati}
		<!-- Rimontare e' il modo piu' semplice di rigiocare trenta animazioni
		     insieme: si ributta via tutto e riparte, invece di rincorrere
		     ognuna per riavvolgerla. -->
		{#key tappa}
			<Coriandoli quanti={festa.quanti} scoppi={festa.scoppi} larghezza={festa.larghezza} />
		{/key}

		<div class="testa">
			<p class="t-label t-muted">Stagione {dati.stagione}</p>
			<h1>Queste siete</h1>
			<p class="t-small t-muted">
				{new Date(dati.inizio).toLocaleDateString('it-IT', { day: 'numeric', month: 'long' })} —
				{new Date(dati.fine).toLocaleDateString('it-IT', { day: 'numeric', month: 'long' })}
			</p>
		</div>

		{#if tappa === 0}
			<Finestra titolo="Come siete andate" variante="orange">
				<ol class="podio">
					{#each righe.filter((r) => r.punti > 0) as r (r.user_id)}
						<li class="posto" class:posto--primo={r.posizione === 1}>
							<span class="medaglia t-num">{r.posizione}</span>
							<Avatar utente={chi(r.user_id)} />
							<span class="grow">{nome(r.user_id)}</span>
							<span class="t-num">{r.punti} ✦</span>
						</li>
					{/each}
				</ol>
				<p class="t-small t-muted nota">
					I Croquembouche restano nel portacroque. A ripartire da zero è solo la gara.
				</p>
			</Finestra>
		{:else if tappa <= titoli.length}
			{@const gruppo = titoli[tappa - 1]}
			{@const t = gruppo[0]}
			<Finestra titolo={gruppo.length > 1 ? 'Un titolo, in due' : 'Un titolo'} variante="blue">
				<div class="titolo">
					<p class="titolo__che">{t.etichetta}</p>
					<div class="vincitrici">
						{#each gruppo as c (c.id)}
							<div class="vincitrice">
								<Avatar utente={chi(c.user_id)} dimensione="lg" />
								<p class="titolo__chi">{nome(c.user_id)}</p>
							</div>
						{/each}
					</div>
					{#if t.quanto}<p class="t-label t-muted">{t.quanto}</p>{/if}
					{#if gruppo.length > 1}
						<p class="t-small t-muted">Stesso numero, stesso titolo: è di tutte e due.</p>
					{/if}
					{#if t.foto_url}
						<img class="scatto" src={t.foto_url} alt="" />
					{/if}
				</div>
			</Finestra>
		{:else}
			<Finestra titolo="Le foto che restano" variante="green">
				<p class="t-small">
					Una per ciascuna, la più piaciuta. Le altre se ne vanno: queste no.
				</p>
				<div class="galleria">
					{#each foto as f (f.user_id)}
						<figure class="pezzo">
							<img src={f.foto_url} alt={f.item_nome} />
							<figcaption class="t-label">
								{nome(f.user_id)} · {f.item_nome}{f.mi_piace ? ` · ${f.mi_piace} ♥` : ''}
							</figcaption>
						</figure>
					{/each}
				</div>
			</Finestra>
		{/if}

		<div class="passi">
			<button class="btn btn--sm" disabled={tappa === 0} onclick={() => (tappa -= 1)}>
				Indietro
			</button>
			<span class="t-label t-muted">{tappa + 1}/{tappe}</span>
			{#if ultima}
				<a class="btn btn--primary" href="/">Torna al gioco</a>
			{:else}
				<button class="btn btn--primary" onclick={() => (tappa += 1)}>Avanti</button>
			{/if}
		</div>
	{/if}
</div>

<style>
	.wrap {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-3);
	}

	.testa {
		text-align: center;
	}

	.testa h1 {
		margin: 2px 0;
	}

	.podio {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.posto {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.posto--primo {
		font-weight: 700;
	}

	.medaglia {
		width: 1.5rem;
		text-align: center;
	}

	.grow {
		flex: 1;
	}

	.nota {
		margin-top: var(--space-2);
	}

	.titolo {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2);
		text-align: center;
	}

	.titolo__che {
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.vincitrici {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: var(--space-4);
	}

	.vincitrice {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2);
	}

	.titolo__chi {
		font-size: var(--fs-titolo);
	}

	.scatto {
		width: 100%;
		max-width: 240px;
		border: var(--border) solid var(--navy);
	}

	.galleria {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
		gap: var(--space-2);
		margin-top: var(--space-2);
	}

	.pezzo {
		margin: 0;
	}

	.pezzo img {
		width: 100%;
		border: var(--border-thin) solid var(--navy);
	}

	.passi {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-2);
	}
</style>
