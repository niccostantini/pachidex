<script lang="ts">
	import { onMount } from 'svelte';
	import { caricaClassifica } from '$lib/db/dex';
	import { caricaTitoli, type VoceTitolo } from '$lib/db/titoli';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import BachecaTitoli from '$lib/components/BachecaTitoli.svelte';
	import type { RigaClassifica } from '$lib/types';

	let righe = $state<RigaClassifica[]>([]);
	let titoli = $state<VoceTitolo[]>([]);
	let tab = $state<'croq' | 'unici'>('croq');
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);

	const ordinate = $derived(
		[...righe].sort((a, b) =>
			tab === 'croq' ? b.punti - a.punti : b.item_unici - a.item_unici || b.punti - a.punti
		)
	);

	const massimo = $derived(
		Math.max(1, ...ordinate.map((r) => (tab === 'croq' ? r.punti : r.item_unici)))
	);

	/**
	 * Le posizioni, con i pari merito.
	 *
	 * Non "la riga numero tre e' terza": a parita' di punti la posizione e' la
	 * stessa, e dopo due prime viene il terzo. E' quello che fa gia' il conto
	 * congelato di fine stagione — `rank()` e non `row_number()` — e se qui si
	 * contassero le righe la classifica direbbe per due settimane una cosa che
	 * la premiazione poi smentisce.
	 */
	const posizioni = $derived.by(() => {
		const v = ordinate.map((r) => (tab === 'croq' ? r.punti : r.item_unici));
		return v.map((x) => v.findIndex((y) => y === x) + 1);
	});

	onMount(async () => {
		try {
			righe = await caricaClassifica();
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
			return;
		}

		// I titoli si chiedono a parte: sono un di piu', e se non arrivano la
		// classifica deve restare in piedi lo stesso.
		try {
			titoli = await caricaTitoli();
		} catch {
			titoli = [];
		}
	});
</script>

<svelte:head><title>Classifica — Pachino Express</title></svelte:head>

<div class="cl stack">
	<div class="tabs">
		<button class="tabb" class:tabb--on={tab === 'croq'} onclick={() => (tab = 'croq')}>
			Croquembouche
		</button>
		<button class="tabb" class:tabb--on={tab === 'unici'} onclick={() => (tab = 'unici')}>
			Elementi unici
		</button>
	</div>

	<p class="spiega t-small t-muted">
		{#if tab === 'croq'}
			Contano i Croquembouche acquisiti in questa stagione, meno le penalità. Gli
			scambi non spostano la classifica: quelli sono affari del portacroque.
		{:else}
			Solo elementi diversi, le ripetizioni non contano: qui vince chi colleziona.
		{/if}
	</p>

	<Finestra titolo={tab === 'croq' ? 'Punti di stagione' : 'Collezione'} variante="navy">
		{#if stato === 'carico'}
			<p class="t-label t-muted">Conto…</p>
		{:else if stato === 'errore'}
			<p class="t-small">{errore}</p>
		{:else}
			<ol class="podio">
				{#each ordinate as r, i (r.user_id)}
					{@const valore = tab === 'croq' ? r.punti : r.item_unici}
					{@const posto = posizioni[i]}
					<li class="riga" class:riga--io={r.user_id === profilo.io?.id}>
						<span class="pos t-num" class:pos--primo={posto === 1}>{posto}</span>
						<Avatar utente={profilo.utenti.find((u) => u.id === r.user_id)} />
						<div class="grow">
							<p class="nome"><a class="chi" href="/profilo/{r.user_id}">{r.nome}</a></p>
							<div class="barra">
								<div
									class="barra__riempi"
									style:width="{Math.max((valore / massimo) * 100, 2)}%"
									class:barra__riempi--primo={posto === 1}
								></div>
							</div>
						</div>
						<div class="valore">
							<span class="t-num grande">{valore}</span>
							<span class="t-label">{tab === 'croq' ? '✦' : 'pezzi'}</span>
						</div>
					</li>
				{/each}
			</ol>
		{/if}
	</Finestra>

	{#if stato === 'ok'}
		<Finestra titolo="I titoli" variante="orange">
			<BachecaTitoli {titoli} />
			<p class="spiega t-small t-muted">
				Sempre a chi è in testa adesso, e se in testa ci sono in due il titolo è
				di tutte e due. Si perdono: è il bello.
			</p>
		</Finestra>

		<Finestra titolo="Dettaglio" variante="blue">
			<div class="tabella">
				<div class="th">
					<span class="grow">Giocatore</span>
					<span>Presi</span>
					<span>Scambi</span>
					<span>Penalita</span>
				</div>
				{#each ordinate as r (r.user_id)}
					<div class="tr">
						<span class="grow">{r.nome}</span>
						<span class="t-num">{r.guadagnati}</span>
						<span class="t-num" class:neg={r.saldo_scambi < 0}>
							{r.saldo_scambi > 0 ? '+' : ''}{r.saldo_scambi}
						</span>
						<span class="t-num neg">
							{r.penalita + r.spesi_in_contestazioni
								? `-${r.penalita + r.spesi_in_contestazioni}`
								: '0'}
						</span>
					</div>
				{/each}
			</div>
		</Finestra>

		<a class="btn btn--primary btn--block" href="/scambi">Passa Croquembouche a qualcuno</a>
	{/if}
</div>

<style>
	/* Dal podio si va al profilo: e' il posto in cui viene piu' naturale
	   chiedersi "ma cosa ha catturato per stare li' sopra?". */
	.chi {
		color: inherit;
		text-decoration: none;
	}

	.chi:active {
		text-decoration: underline;
	}

	.cl {
		padding: var(--space-3);
	}

	.tabs {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 3px;
	}

	.tabb {
		padding: 9px;
		background: var(--paper);
		border: var(--border) solid var(--navy);
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		cursor: pointer;
	}

	.tabb--on {
		background: var(--orange);
		color: var(--paper);
		box-shadow: inset 3px 3px 0 rgba(22, 27, 61, 0.3);
	}

	.podio {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.riga--io {
		background: rgba(240, 85, 43, 0.16);
		border-width: var(--border);
	}

	.pos {
		width: 22px;
		text-align: center;
		font-weight: 700;
		color: var(--navy-soft);
	}

	.pos--primo {
		color: var(--navy);
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
	}

	.nome {
		font-weight: 700;
		font-size: 0.9375rem;
	}

	.barra {
		height: 9px;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		margin-top: 3px;
	}

	.barra__riempi {
		height: 100%;
		background: var(--blue);
	}

	.barra__riempi--primo {
		background: var(--orange);
	}

	.valore {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		min-width: 46px;
	}

	.grande {
		font-size: 1.25rem;
		font-weight: 700;
		line-height: 1;
	}

	.tabella {
		font-size: 0.8125rem;
	}

	.th,
	.tr {
		display: flex;
		gap: var(--space-2);
		padding: 4px 0;
	}

	.th {
		font-weight: 700;
		text-transform: uppercase;
		font-size: 0.625rem;
		letter-spacing: 0.06em;
		border-bottom: var(--border-thin) solid var(--navy);
	}

	.th span:not(.grow),
	.tr span:not(.grow) {
		width: 58px;
		text-align: right;
	}

	.tr + .tr {
		border-top: 1px solid rgba(22, 27, 61, 0.15);
	}

	.neg {
		color: var(--red);
	}
</style>
