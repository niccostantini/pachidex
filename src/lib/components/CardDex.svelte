<script lang="ts">
	import { goto } from '$app/navigation';
	import { etichettaRarita } from '$lib/game/rules';
	import type { MiaVoce } from '$lib/db/dex';
	import type { VoceDex } from '$lib/types';

	interface Props {
		voce: VoceDex;
		mia: MiaVoce | undefined;
		/** Chiamata quando si tocca una carta ancora bloccata. */
		onApri?: (voce: VoceDex) => void;
	}

	let { voce, mia, onApri }: Props = $props();

	let salta = $state(false);

	const sbloccato = $derived(!!mia);
	// La foto e' quella del gruppo: il Dex e' un archivio comune, non un album
	// personale. Cambia solo cosa hai sbloccato tu.
	const immagine = $derived(voce.prima_foto);

	function tocca() {
		if (sbloccato) {
			void goto(`/pachidex/${voce.item_id}`);
			return;
		}
		// Bloccato: il blocco rimbalza e apre la scheda, dove c'e' la foto di
		// riferimento. Serve proprio adesso che l'elemento non e' ancora preso:
		// e' quando non sai cosa stai guardando.
		salta = true;
		setTimeout(() => (salta = false), 340);
		onApri?.(voce);
	}
</script>

<button
	class="carta"
	class:carta--sbloccata={sbloccato}
	class:holo={voce.rarita === 'leggendario' && sbloccato}
	onclick={tocca}
	aria-label={sbloccato
		? `${voce.nome}, sbloccato`
		: `${voce.nome}, ancora da sbloccare — apri la scheda`}
>
	<div class="carta__immagine">
		{#if sbloccato && immagine}
			<img class="foto" src={immagine} alt={voce.nome} loading="lazy" />
		{:else if sbloccato}
			<!-- Preso, ma la foto non c'e' piu': meglio un segnaposto che un buco. -->
			<div class="qblock" style:--rarity="var(--rarity-{voce.rarita})">
				<span class="qblock__mark">✓</span>
			</div>
		{:else}
			<div
				class="qblock"
				class:qblock--bump={salta}
				class:qblock--luccica={voce.rarita === 'leggendario'}
				style:--rarity="var(--rarity-{voce.rarita})"
			>
				<span class="qblock__mark">?</span>
			</div>
		{/if}

		{#if voce.ripetibile && (mia?.quante ?? 0) > 1}
			<span class="conta t-num">×{mia?.quante}</span>
		{/if}

		{#if voce.validazione === 'foto_gps'}
			<span class="gps" title="Checkpoint GPS">▲</span>
		{/if}
	</div>

	<p class="carta__nome">{voce.nome}</p>
	<p class="carta__rarita" style:color="var(--rarity-{voce.rarita})">
		{etichettaRarita(voce.rarita)} · {voce.croquembouche} ✦
	</p>
</button>

<style>
	.carta {
		display: flex;
		flex-direction: column;
		gap: 3px;
		padding: 5px;
		background: var(--paper);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
		text-align: left;
		cursor: pointer;
		-webkit-tap-highlight-color: transparent;
	}

	.carta:active {
		transform: translate(3px, 3px);
		box-shadow: none;
	}

	.carta__immagine {
		position: relative;
		aspect-ratio: 1;
	}

	.foto {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border: var(--border-thin) solid var(--navy);
	}

	.carta__nome {
		font-size: 0.8125rem;
		font-weight: 700;
		line-height: 1.15;
		/* Il nome si vede sempre, anche da bloccato: il Dex e' la lista delle
		   cose da fare in vacanza, non un indovinello. */
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
		min-height: 2.3em;
	}

	.carta__rarita {
		font-size: 0.625rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	/* Solo i leggendari luccicano: se lo facessero tutti non vorrebbe dire
	   niente, e sarebbero 114 elementi ad animarsi insieme. */
	.qblock--luccica {
		position: relative;
		overflow: hidden;
	}

	.qblock--luccica::after {
		content: '';
		position: absolute;
		top: 0;
		bottom: 0;
		width: 26px;
		background: rgba(255, 255, 255, 0.45);
		transform: skewX(-20deg);
		animation: luccichio 3.4s steps(10, end) infinite;
	}

	@keyframes luccichio {
		0% {
			left: -40%;
		}
		35%, 100% {
			left: 130%;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.qblock--luccica::after {
			display: none;
		}
	}

	.conta {
		position: absolute;
		right: -3px;
		bottom: -3px;
		background: var(--orange);
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		font-weight: 700;
		padding: 0 4px;
	}

	.gps {
		position: absolute;
		left: 3px;
		top: 3px;
		background: var(--blue);
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.625rem;
		line-height: 1.2;
		padding: 0 3px;
	}
</style>
