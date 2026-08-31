<script lang="ts">
	import { maggioranza, tempoRelativo, tempoRimanente } from '$lib/game/rules';
	import { profilo } from '$lib/state/profilo.svelte';
	import { vota } from '$lib/db/azioni';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from './Avatar.svelte';
	import CardCattura from './CardCattura.svelte';
	import type { PostContestazione, Voto } from '$lib/types';

	interface Props {
		post: PostContestazione;
		onCambio?: () => void;
	}

	let { post, onCambio }: Props = $props();

	let inVoto = $state(false);
	let errore = $state<string | null>(null);

	// Countdown che scorre davvero: un tick al minuto, non serve di piu'.
	let ora = $state(Date.now());
	$effect(() => {
		if (post.contest.stato !== 'aperta') return;
		const t = setInterval(() => (ora = Date.now()), 30000);
		return () => clearInterval(t);
	});

	const aperta = $derived(post.contest.stato === 'aperta');
	const contestato = $derived(post.cattura.autore);
	const sonoIoContestato = $derived(contestato.id === profilo.io?.id);
	const mioVoto = $derived(post.voti.find((v) => v.user_id === profilo.io?.id)?.voto ?? null);

	const perNonValido = $derived(post.voti.filter((v) => v.voto === 'non_valido').length);
	const perValido = $derived(post.voti.filter((v) => v.voto === 'valido').length);
	const soglia = $derived(maggioranza(profilo.utenti.length || 6));
	const votantiTotali = $derived(Math.max(profilo.utenti.length - 1, 1));

	const scadenza = $derived.by(() => {
		void ora; // dipendenza esplicita: il countdown deve ricalcolarsi
		return tempoRimanente(post.contest.scadenza);
	});

	const esito = $derived.by(() => {
		switch (post.contest.stato) {
			case 'chiusa_non_valido':
				return {
					titolo: 'Cattura invalidata',
					testo: `Il gruppo ha dato ragione a ${post.contestante.nome}. ${contestato.nome} perde ${post.contest.penalita} Croquembouche oltre alla cattura.`,
					variante: 'ko' as const
				};
			case 'chiusa_valido':
				return {
					titolo: 'Cattura confermata',
					testo: `La cattura regge. ${post.contestante.nome} perde ${post.contest.penalita} Croquembouche per la contestazione persa.`,
					variante: 'ok' as const
				};
			case 'scaduta':
				return {
					titolo: 'Contestazione scaduta',
					testo: 'Non sono arrivati abbastanza voti in tempo: la cattura resta valida.',
					variante: 'neutro' as const
				};
			default:
				return null;
		}
	});

	async function esprimi(v: Voto) {
		if (!profilo.io || inVoto) return;
		inVoto = true;
		errore = null;
		try {
			await vota(post.contest.id, profilo.io.id, v);
			onCambio?.();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			inVoto = false;
		}
	}
</script>

<section class="cont" class:cont--aperta={aperta}>
	<header class="win__bar {aperta ? 'win__bar--navy' : 'win__bar--blue'}">
		<span class="win__title">
			{aperta ? '⚠ Contestazione aperta' : 'Contestazione chiusa'}
		</span>
		<div class="win__btns">
			{#if aperta}
				<span class="countdown t-num">{scadenza}</span>
			{:else}
				<span class="countdown">{tempoRelativo(post.contest.created_at)}</span>
			{/if}
		</div>
	</header>

	<div class="cont__corpo">
		<div class="cont__chi">
			<Avatar utente={post.contestante} dimensione="sm" />
			<p class="t-small grow">
				<a class="chi" href="/profilo/{post.contestante.id}"><strong>{post.contestante.nome}</strong></a>
				contesta la cattura di
				<a class="chi" href="/profilo/{contestato.id}"><strong>{contestato.nome}</strong></a>
			</p>
		</div>

		{#if post.contest.motivo}
			<p class="motivo t-small">“{post.contest.motivo}”</p>
		{/if}

		<div class="cont__prova">
			<CardCattura post={post.cattura} compatta />
		</div>

		<div class="conteggio">
			<div class="barra">
				<div class="barra__ko" style:flex={perNonValido || 0.001}></div>
				<div class="barra__ok" style:flex={perValido || 0.001}></div>
				<div class="barra__vuoto" style:flex={Math.max(votantiTotali - perNonValido - perValido, 0.001)}></div>
			</div>
			<p class="t-small t-muted">
				<strong class="ko">{perNonValido}</strong> non valida ·
				<strong class="ok">{perValido}</strong> valida · servono {soglia} voti
			</p>
		</div>

		{#if esito}
			<div class="esito esito--{esito.variante}">
				<p class="t-label">{esito.titolo}</p>
				<p class="t-small">{esito.testo}</p>
			</div>
		{:else if sonoIoContestato}
			<p class="t-small t-muted avviso">
				Sei tu sotto contestazione: puoi solo guardare il conteggio salire.
			</p>
		{:else if mioVoto}
			<p class="t-small avviso">
				Hai votato <strong>{mioVoto === 'valido' ? 'valida' : 'non valida'}</strong>. Puoi
				cambiare idea finche' resta aperta.
			</p>
			<div class="voti">
				<button class="btn btn--sm" onclick={() => esprimi('valido')} disabled={inVoto}>
					Valida
				</button>
				<button class="btn btn--sm" onclick={() => esprimi('non_valido')} disabled={inVoto}>
					Non valida
				</button>
			</div>
		{:else if profilo.io}
			<div class="voti voti--grandi">
				<button class="btn btn--ok btn--lg grow" onclick={() => esprimi('valido')} disabled={inVoto}>
					Valida
				</button>
				<button
					class="btn btn--danger btn--lg grow"
					onclick={() => esprimi('non_valido')}
					disabled={inVoto}
				>
					Non valida
				</button>
			</div>
		{/if}

		{#if errore}
			<p class="t-small errore">{errore}</p>
		{/if}
	</div>
</section>

<style>
	.chi {
		color: inherit;
		text-decoration: none;
	}

	.chi:active {
		text-decoration: underline;
	}

	.cont {
		background: var(--paper);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow);
	}

	.cont--aperta {
		box-shadow: var(--shadow), 0 0 0 3px var(--yellow);
	}

	.cont__corpo {
		padding: var(--space-2);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.cont__chi {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.countdown {
		font-size: 0.6875rem;
		font-weight: 700;
		background: var(--yellow);
		color: var(--navy);
		border: var(--border-thin) solid var(--navy);
		padding: 0 5px;
	}

	.motivo {
		background: var(--cream);
		border-left: var(--border) solid var(--navy);
		padding: 5px var(--space-2);
	}

	.cont__prova {
		/* La prova del delitto, rimpicciolita: il post resta leggibile ma non
		   ruba la scena alla votazione. */
		transform: scale(0.94);
		transform-origin: top center;
	}

	.conteggio {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.barra {
		display: flex;
		height: 14px;
		border: var(--border-thin) solid var(--navy);
		background: var(--cream);
	}

	.barra__ko {
		background: var(--red);
	}
	.barra__ok {
		background: var(--green);
	}
	.barra__vuoto {
		background: repeating-linear-gradient(
			45deg,
			transparent 0 3px,
			rgba(22, 27, 61, 0.16) 3px 6px
		);
	}

	.ko {
		color: var(--red);
	}
	.ok {
		color: var(--green);
	}

	.voti {
		display: flex;
		gap: var(--space-2);
	}

	.voti--grandi {
		margin-top: var(--space-1);
	}

	.avviso {
		background: var(--cream);
		padding: var(--space-2);
		border: var(--border-thin) dashed var(--navy);
	}

	.esito {
		padding: var(--space-2);
		border: var(--border-thin) solid var(--navy);
	}

	.esito--ko {
		background: rgba(217, 59, 50, 0.16);
	}
	.esito--ok {
		background: rgba(53, 183, 154, 0.18);
	}
	.esito--neutro {
		background: var(--cream);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
