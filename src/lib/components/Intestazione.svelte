<script lang="ts">
	import { profilo } from '$lib/state/profilo.svelte';
	import { coda } from '$lib/state/coda.svelte';
	import Avatar from './Avatar.svelte';
	import Notifiche from './Notifiche.svelte';
	import Icona from './Icona.svelte';

	/**
	 * I due numeri.
	 *
	 * A sinistra quello della gara: i Croquembouche acquisiti in questa
	 * stagione, meno le penalita'. Riparte da zero ogni due settimane.
	 * A destra il portacroque, che invece non si azzera mai — quello che hai
	 * davvero da spendere.
	 *
	 * Lampeggia quello di classifica: guadagnare e' il punto del gioco, e
	 * finora succedeva in silenzio in un angolo. Il portacroque no: si muove
	 * anche quando spendi, e un lampo a ogni spesa sarebbe una festa per una
	 * cosa che festa non e'.
	 *
	 * Chi guarda da fuori non li ha: sarebbero due zeri fermi per sempre,
	 * cioe' la promessa di un gioco a cui non prende parte.
	 */
	let puntiPrecedenti = $state<number | null>(null);
	let lampeggia = $state(false);

	$effect(() => {
		const ora = profilo.punti;
		if (puntiPrecedenti !== null && ora !== puntiPrecedenti) {
			lampeggia = true;
			const t = setTimeout(() => (lampeggia = false), 700);
			puntiPrecedenti = ora;
			return () => clearTimeout(t);
		}
		puntiPrecedenti = ora;
	});

	/** La scorciatoia al pannello: stessa domanda che si fa il pannello stesso. */
	const ammesso = $derived(profilo.pronto && profilo.io?.is_admin === true);
</script>

<header class="testata">
	<div class="testata__bar">
		<span class="win__title">Pachino Express</span>

		{#if coda.inAttesa.length}
			<span class="attesa" title="Catture in attesa di rete">
				⇈ {coda.inAttesa.length}
			</span>
		{/if}

		<div class="testata__dx">
			<Notifiche />
			{#if !profilo.soloSguardo}
				<a class="conti" href="/classifica" aria-label="Classifica e portacroque">
					<span class="chip chip--gara" class:chip--cambia={lampeggia}>
						<span class="chip__n t-num">{profilo.punti} ✦</span>
						<span class="chip__che">CLASSIFICA</span>
					</span>
					<span class="chip chip--tasca">
						<span class="chip__n t-num">{profilo.saldo} ✦</span>
						<span class="chip__che">PORTACROQUE</span>
					</span>
				</a>
			{/if}

			{#if ammesso}
				<a class="gestione" href="/gestione-xk29" aria-label="Pannello di gestione">
					<Icona nome="chiaveinglese" dimensione={15} colore="var(--paper)" sfondo="var(--orange)" />
				</a>
			{/if}

			<button
				class="testata__io"
				aria-label="Esci"
				onclick={() => {
					if (confirm('Esci da Pachino Express?')) void profilo.esci();
				}}
			>
				<Avatar utente={profilo.io} dimensione="sm" />
			</button>
		</div>
	</div>
</header>

<style>
	.testata {
		position: sticky;
		top: 0;
		z-index: 30;
	}

	.testata__bar {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		background: var(--orange);
		border-bottom: var(--border) solid var(--navy);
		padding: 5px var(--space-2);
		padding-top: calc(5px + env(safe-area-inset-top));
		color: var(--paper);
	}

	.testata__dx {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-left: auto;
	}

	.chip--cambia {
		animation: lampeggia 700ms steps(1, end);
	}

	@keyframes lampeggia {
		0%, 40%, 80% {
			background: var(--yellow);
			color: var(--navy);
		}
		20%, 60%, 100% {
			background: var(--navy);
			color: var(--yellow);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.chip--cambia {
			animation: none;
		}
	}

	.conti {
		display: flex;
		gap: 4px;
		text-decoration: none;
	}

	.chip {
		display: flex;
		flex-direction: column;
		align-items: center;
		line-height: 1.05;
		padding: 2px 6px;
	}

	.chip--gara {
		background: var(--navy);
		color: var(--paper);
	}

	.chip--tasca {
		background: var(--paper);
		color: var(--navy);
	}

	.chip__n {
		font-size: var(--fs-testo);
	}

	/* Sotto gli 8px la scritta non si legge piu': e' il limite, non una scelta. */
	.chip__che {
		font-size: var(--fs-testo);
		letter-spacing: 0.04em;
		opacity: 0.8;
	}

	.attesa {
		font-size: var(--fs-testo);
		font-weight: 700;
		background: var(--yellow);
		color: var(--navy);
		border: var(--border-thin) solid var(--navy);
		padding: 0 4px;
	}

	.testata__io {
		display: block;
		line-height: 0;
		cursor: pointer;
	}
	/* Vestita come la campanella qui accanto: e' l'altro pulsante della barra. */
	.gestione {
		display: grid;
		place-items: center;
		width: 26px;
		height: 26px;
		background: var(--orange);
		border: var(--border-thin) solid var(--navy);
		-webkit-tap-highlight-color: transparent;
	}
</style>
