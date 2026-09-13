<script lang="ts">
	import { tempoRelativo } from '$lib/game/rules';
	import { butta, conIlNome, vota } from '$lib/db/oversharing';
	import { spezzaMenzioni } from '$lib/game/tag';
	import { profilo } from '$lib/state/profilo.svelte';
	import Avatar from './Avatar.svelte';
	import Icona from './Icona.svelte';
	import type { PostOversharing } from '$lib/types';

	interface Props {
		post: PostOversharing;
		onCambio?: () => void;
	}

	let { post, onCambio }: Props = $props();

	/**
	 * Come per i cuori sulle foto: il voto si vede subito e la verita' resta
	 * quella del server. Si tiene solo lo scarto fra i due, cosi' quando il
	 * realtime porta il conteggio buono lo scarto si azzera da solo.
	 */
	let ottimistico = $state<{ id: string; voto: 'chic' | 'cheap' | null } | null>(null);

	const mio = $derived(ottimistico?.id === post.id ? ottimistico.voto : post.mio_voto);

	const scarto = (quale: 'chic' | 'cheap') =>
		(mio === quale ? 1 : 0) - (post.mio_voto === quale ? 1 : 0);

	const chic = $derived(post.chic + scarto('chic'));
	const cheap = $derived(post.cheap + scarto('cheap'));

	const mia = $derived(post.user_id === profilo.io?.id);
	// Il proprio non si vota: il pulsante non deve nemmeno accendersi.
	const posso = $derived(!!profilo.io && !profilo.soloSguardo && !mia);

	let erroreVoto = $state<string | null>(null);

	async function premi(quale: 'chic' | 'cheap') {
		if (!posso) return;
		const prima = mio;
		erroreVoto = null;
		ottimistico = { id: post.id, voto: prima === quale ? null : quale };
		try {
			await vota(post.id, quale);
			onCambio?.();
		} catch (e) {
			ottimistico = null;
			// La stagione chiusa e' il caso vero: si dice, invece di lasciare il
			// pulsante che torna indietro da solo senza spiegare perche'.
			erroreVoto = e instanceof Error ? e.message : 'Non ha funzionato';
		}
	}

	let chiedeButta = $state(false);

	async function confermaButta() {
		try {
			await butta(post.id);
			onCambio?.();
		} catch {
			chiedeButta = false;
		}
	}
</script>

<article class="os">
	<div class="os__testa">
		<Avatar utente={post.autore} dimensione="sm" />
		<p class="formula grow t-small">
			<a class="chi" href="/profilo/{post.autore.id}">
				<strong>{conIlNome(post.formula, post.autore.nome)}</strong>
			</a>
		</p>
		<span class="t-small t-muted quando">{tempoRelativo(post.created_at)}</span>
	</div>

	<p class="detto">
		{#each spezzaMenzioni(post.testo, profilo.utenti) as pezzo, i (i)}
			{#if pezzo.utente}
				<a class="menzione" href="/profilo/{pezzo.utente.id}">{pezzo.testo}</a>
			{:else}{pezzo.testo}{/if}
		{/each}
	</p>

	<div class="os__azioni">
		<button
			class="voto"
			class:voto--chic={mio === 'chic'}
			onclick={() => premi('chic')}
			disabled={!posso}
			aria-label="Chic"
		>
			<Icona nome="chic" dimensione={9} />
			<span class="t-num">&nbsp;{chic}</span>
		</button>

		<button
			class="voto"
			class:voto--cheap={mio === 'cheap'}
			onclick={() => premi('cheap')}
			disabled={!posso}
			aria-label="Cheap"
		>
			<Icona nome="cheap" dimensione={9} />
			<span class="t-num">&nbsp;{cheap}</span>
		</button>

		{#if mia}
			{#if chiedeButta}
				<div class="butta">
					<button class="voto voto--butta" onclick={confermaButta}>Sicura?</button>
					<button class="voto" onclick={() => (chiedeButta = false)}>No</button>
				</div>
			{:else}
				<button class="voto voto--fine" onclick={() => (chiedeButta = true)}>Butta</button>
			{/if}
		{/if}
	</div>

	{#if erroreVoto}
		<p class="t-small errore">{erroreVoto}</p>
	{/if}
</article>

<style>
	/*
	 * Piu' stretto e piu' chiaro delle catture: un oversharing non e' una
	 * prova, e' una voce. Se avesse la stessa cornice di una foto validata col
	 * GPS il feed peserebbe il doppio senza dire il doppio.
	 */
	.os {
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		box-shadow: var(--shadow-sm);
		padding: var(--space-2);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.os__testa {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.formula {
		line-height: 1.2;
	}

	.quando {
		flex-shrink: 0;
		align-self: flex-start;
	}

	.chi {
		color: inherit;
		text-decoration: none;
	}

	.chi:active {
		text-decoration: underline;
	}

	/*
	 * La frase e' la cosa: grande, su carta color crema, con la barra a
	 * sinistra come una citazione. Tutto il resto della card e' cornice.
	 */
	.detto {
		font-size: 1.05rem;
		line-height: 1.35;
		background: var(--cream);
		border-left: var(--border) solid var(--orange);
		padding: var(--space-2) var(--space-3);
		white-space: pre-wrap;
		overflow-wrap: anywhere;
	}

	.menzione {
		font-weight: 700;
		text-decoration: none;
		color: var(--blue);
	}

	.os__azioni {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.voto {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		padding: 4px 9px;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		cursor: pointer;
		-webkit-tap-highlight-color: transparent;
	}

	.voto:active {
		background: var(--cream);
	}

	.voto:disabled {
		cursor: default;
		opacity: 0.75;
	}

	/* Verde e blu, non verde e rosso: il rosso qui e' gia' la penalita' e la
	   cattura invalidata, e un CHEAP non e' un castigo. */
	.voto--chic {
		background: var(--green);
		color: var(--paper);
	}

	.voto--cheap {
		background: var(--blue);
		color: var(--paper);
	}

	.voto--fine {
		margin-left: auto;
		font-size: 0.7rem;
		color: var(--navy-soft);
	}

	.butta {
		margin-left: auto;
		display: flex;
		gap: 4px;
	}

	.voto--butta {
		background: var(--red);
		color: var(--paper);
	}

	.t-num {
		font-size: 1.05rem;
	}

	.errore {
		color: var(--orange-dark);
	}
</style>
