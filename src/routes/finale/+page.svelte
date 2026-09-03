<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import {
		chiudiPremio,
		cominciaPremi,
		premiAttivi,
		scartoOrologio,
		sottoscriviFinale,
		statoFinale,
		vota,
		votiEEsiti,
		type Esito,
		type Premio,
		type StatoFinale,
		type Voto
	} from '$lib/db/finale';
	import { caricaClassifica } from '$lib/db/dex';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import type { RigaClassifica } from '$lib/types';

	let stato = $state<StatoFinale | null>(null);
	let premi = $state<Premio[]>([]);
	let voti = $state<Voto[]>([]);
	let esiti = $state<Esito[]>([]);
	let righe = $state<RigaClassifica[]>([]);
	let scarto = $state(0);
	let caricando = $state(true);
	let errore = $state<string | null>(null);
	let inVoto = $state(false);

	/** L'ora del server, non quella del telefono. */
	let ora = $state(Date.now());
	const adesso = $derived(ora + scarto);

	const premio = $derived(premi.find((p) => p.numero === stato?.premio_numero) ?? null);
	const apertura = $derived(stato?.apertura ? new Date(stato.apertura).getTime() : 0);

	/** Prima che si apra il voto si guarda chi ha vinto il premio precedente. */
	const inPausa = $derived(stato?.fase === 'premi' && adesso < apertura);
	const secondiPausa = $derived(Math.max(0, Math.ceil((apertura - adesso) / 1000)));
	const secondiVoto = $derived(
		Math.max(0, Math.ceil((apertura + (stato?.secondi_voto ?? 60) * 1000 - adesso) / 1000))
	);

	const mieiVoti = $derived(new Map(voti.filter((v) => v.premio_id === premio?.id).map((v) => [v.votante_id, v.votato_id])));
	const mioVoto = $derived(profilo.io ? mieiVoti.get(profilo.io.id) : undefined);
	const quantiHannoVotato = $derived(mieiVoti.size);
	const tuttiVotato = $derived(quantiHannoVotato >= profilo.utenti.length && profilo.utenti.length > 0);

	const esitoDi = (premioId: string) => esiti.find((e) => e.premio_id === premioId) ?? null;
	/** Il premio appena assegnato: quello prima di quello in ballo. */
	const precedente = $derived(
		premi.filter((p) => p.numero < (stato?.premio_numero ?? 0)).at(-1) ?? null
	);

	/** Quanto ha portato la premiazione a ciascuno: serve al confronto finale. */
	function daiPremi(userId: string): number {
		return esiti
			.filter((e) => e.vincitore_id === userId)
			.reduce((t, e) => t + (premi.find((p) => p.id === e.premio_id)?.croquembouche ?? 0), 0);
	}

	const classificaOra = $derived([...righe].sort((a, b) => b.saldo - a.saldo));
	const classificaPrima = $derived(
		[...righe]
			.map((r) => ({ ...r, saldo: r.saldo - daiPremi(r.user_id) }))
			.sort((a, b) => b.saldo - a.saldo)
	);
	const podio = $derived(stato?.fase === 'podio_finale' ? classificaOra : classificaPrima);

	const utente = (id: string | null | undefined) =>
		id ? (profilo.utenti.find((u) => u.id === id) ?? null) : null;

	async function rileggi() {
		try {
			stato = await statoFinale();
			if (!stato) {
				// Nessuna cerimonia in corso: qui non c'e' niente da vedere.
				void goto('/', { replaceState: true });
				return;
			}
			const [p, ve, cl] = await Promise.all([premiAttivi(), votiEEsiti(stato.id), caricaClassifica()]);
			premi = p;
			voti = ve.voti;
			esiti = ve.esiti;
			righe = cl;
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	onMount(() => {
		void (async () => {
			scarto = await scartoOrologio();
			await rileggi();
		})();

		const stop = sottoscriviFinale(() => void rileggi());
		const t = setInterval(() => (ora = Date.now()), 500);
		return () => {
			stop();
			clearInterval(t);
		};
	});

	/**
	 * Quando il tempo scade — o quando hanno votato tutti — ogni telefono
	 * chiede di chiudere. Arrivano insieme ed e' voluto: la prima assegna, le
	 * altre trovano l'esito gia' scritto.
	 */
	$effect(() => {
		if (!stato || stato.fase !== 'premi' || !premio || inPausa) return;
		if (esitoDi(premio.id)) return;
		if (tuttiVotato || secondiVoto <= 0) {
			void chiudiPremio(stato.id, premio.id);
		}
	});

	async function daiIlVoto(votatoId: string) {
		if (!stato || !premio || !profilo.io || inVoto) return;
		inVoto = true;
		errore = null;
		try {
			await vota(stato.id, premio.id, profilo.io.id, votatoId);
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			inVoto = false;
		}
	}
</script>

<svelte:head><title>La premiazione — Pachino Express</title></svelte:head>

<div class="fin">
	{#if caricando}
		<p class="t-label t-muted">Carico…</p>
	{:else if !stato}
		<p class="t-label t-muted">Nessuna premiazione in corso.</p>
	{:else}
		{#if errore}
			<p class="errore t-small">{errore}</p>
		{/if}

		<!-- ======================= PODIO ======================= -->
		{#if stato.fase === 'podio' || stato.fase === 'podio_finale'}
			<Finestra
				titolo={stato.fase === 'podio' ? 'Come siamo messi' : 'Come è finita'}
				variante={stato.fase === 'podio_finale' ? 'green' : 'navy'}
			>
				<div class="stack">
					{#if stato.fase === 'podio_finale'}
						<p class="t-small">
							Dieci giorni, {righe.length} giocatori e {esiti.length} premi assegnati.
						</p>
					{/if}

					<ol class="podio">
						{#each podio as r, i (r.user_id)}
							{@const guadagno = daiPremi(r.user_id)}
							<li class="posto" class:posto--primo={i === 0} class:posto--io={r.user_id === profilo.io?.id}>
								<span class="medaglia t-num">{i + 1}</span>
								<Avatar utente={utente(r.user_id)} />
								<span class="grow nome">{r.nome}</span>
								<span class="t-num punti">{r.saldo}</span>
								{#if stato.fase === 'podio_finale' && guadagno > 0}
									<span class="delta t-label">+{guadagno}</span>
								{/if}
							</li>
						{/each}
					</ol>
				</div>
			</Finestra>

			{#if stato.fase === 'podio' && profilo.io?.is_admin}
				<button class="btn btn--primary btn--lg btn--block" onclick={() => stato && cominciaPremi(stato.id)}>
					Comincia i premi
				</button>
			{:else if stato.fase === 'podio'}
				<p class="attesa t-label">In attesa che si comincia…</p>
			{/if}

			{#if stato.fase === 'podio_finale' && esiti.length}
				<Finestra titolo="I premi" variante="blue">
					<ul class="albo">
						{#each premi as p (p.id)}
							{@const e = esitoDi(p.id)}
							{#if e}
								<li class="albo__riga">
									<span class="grow t-small">{p.domanda}</span>
									<Avatar utente={utente(e.vincitore_id)} dimensione="sm" />
									<span class="t-small vinto">{utente(e.vincitore_id)?.nome ?? '—'}</span>
								</li>
							{/if}
						{/each}
					</ul>
				</Finestra>
			{/if}

		<!-- ======================= PREMI ======================= -->
		{:else if stato.fase === 'premi' && premio}
			{#if inPausa && precedente}
				{@const e = esitoDi(precedente.id)}
				<Finestra titolo="E il premio va a…" variante="green">
					<div class="vincitore">
						<Avatar utente={utente(e?.vincitore_id)} dimensione="lg" />
						<p class="vincitore__nome">{utente(e?.vincitore_id)?.nome ?? 'Nessuno'}</p>
						<p class="t-small t-muted">{precedente.domanda}</p>
						<p class="vincitore__premio t-label">
							+{precedente.croquembouche} ✦ · {e?.voti ?? 0} voti
						</p>
					</div>
					<p class="conto t-label">Prossimo premio fra {secondiPausa}</p>
				</Finestra>
			{:else}
				<Finestra titolo="Premio {premio.numero} di {premi.length}" variante="orange">
					<div class="stack">
						<p class="domanda">{premio.domanda}</p>
						<p class="t-label t-muted">Vale {premio.croquembouche} ✦</p>

						<div class="tempo">
							<div class="tempo__pista">
								<div
									class="tempo__riempi"
									style:width="{(secondiVoto / (stato.secondi_voto || 60)) * 100}%"
								></div>
							</div>
							<span class="t-num tempo__conta">{secondiVoto}</span>
						</div>

						<div class="scelte">
							{#each profilo.utenti as u (u.id)}
								<button
									class="scelta"
									class:scelta--mia={mioVoto === u.id}
									disabled={inVoto || !profilo.io}
									onclick={() => daiIlVoto(u.id)}
								>
									<Avatar utente={u} />
									<span class="grow">{u.nome}</span>
									{#if mioVoto === u.id}<span class="t-label spunta">il tuo voto</span>{/if}
								</button>
							{/each}
						</div>

						<div class="votanti">
							<span class="t-label t-muted">Hanno votato {quantiHannoVotato} su {profilo.utenti.length}</span>
							<div class="pallini">
								{#each profilo.utenti as u (u.id)}
									<span class="pallino" class:pallino--pieno={mieiVoti.has(u.id)}></span>
								{/each}
							</div>
						</div>
					</div>
				</Finestra>
			{/if}
		{/if}
	{/if}
</div>

<style>
	.fin {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-3);
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
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.posto--primo {
		background: var(--yellow);
		box-shadow: var(--shadow-sm);
	}

	.posto--io {
		border-width: var(--border);
	}

	.medaglia {
		width: 22px;
		text-align: center;
		font-weight: 700;
	}

	.nome {
		font-weight: 700;
	}

	.punti {
		font-weight: 700;
		font-size: 1.0625rem;
	}

	.delta {
		background: var(--green);
		color: var(--paper);
		padding: 1px 5px;
	}

	.attesa {
		text-align: center;
		padding: var(--space-3);
		color: var(--navy);
	}

	.domanda {
		font-size: 1.25rem;
		font-weight: 700;
		line-height: 1.2;
		text-transform: uppercase;
	}

	.tempo {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.tempo__pista {
		flex: 1;
		height: 14px;
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		overflow: hidden;
	}

	.tempo__riempi {
		height: 100%;
		background: repeating-linear-gradient(90deg, var(--orange) 0 6px, var(--orange-dark) 6px 12px);
		/* A scatti di un secondo: e' un conto alla rovescia, non un'animazione. */
		transition: width 500ms steps(2, end);
	}

	.tempo__conta {
		font-weight: 700;
		min-width: 28px;
		text-align: right;
	}

	.scelte {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.scelta {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font: inherit;
		text-align: left;
		cursor: pointer;
	}

	.scelta--mia {
		background: var(--navy);
		color: var(--paper);
		box-shadow: var(--shadow-sm);
	}

	.spunta {
		background: var(--yellow);
		color: var(--navy);
		padding: 1px 5px;
	}

	.votanti {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-2);
	}

	.pallini {
		display: flex;
		gap: 4px;
	}

	.pallino {
		width: 10px;
		height: 10px;
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.pallino--pieno {
		background: var(--orange);
	}

	.vincitore {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2);
		text-align: center;
		padding: var(--space-3) 0;
	}

	.vincitore__nome {
		font-size: 1.5rem;
		font-weight: 700;
		line-height: 1.1;
	}

	.vincitore__premio {
		background: var(--navy);
		color: var(--yellow);
		padding: 3px 8px;
	}

	.conto {
		text-align: center;
		color: var(--navy);
	}

	.albo {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.albo__riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.vinto {
		font-weight: 700;
	}

	.errore {
		background: var(--red);
		color: var(--paper);
		padding: var(--space-2);
	}
</style>
