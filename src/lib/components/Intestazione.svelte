<script lang="ts">
	import { profilo } from '$lib/state/profilo.svelte';
	import { coda } from '$lib/state/coda.svelte';
	import Avatar from './Avatar.svelte';

	/**
	 * Il saldo lampeggia quando cambia: guadagnare Croquembouche e' il punto
	 * del gioco e finora succedeva in silenzio, in un angolo dell'intestazione.
	 */
	let saldoPrecedente = $state<number | null>(null);
	let lampeggia = $state(false);

	$effect(() => {
		const ora = profilo.saldo;
		if (saldoPrecedente !== null && ora !== saldoPrecedente) {
			lampeggia = true;
			const t = setTimeout(() => (lampeggia = false), 700);
			saldoPrecedente = ora;
			return () => clearTimeout(t);
		}
		saldoPrecedente = ora;
	});
	import Notifiche from './Notifiche.svelte';
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
			<span class="saldo t-num" class:saldo--cambia={lampeggia}>✦ {profilo.saldo}</span>
			<a class="testata__io" href="/chi-sei" aria-label="Cambia profilo">
				<Avatar utente={profilo.io} dimensione="sm" />
			</a>
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

	.saldo--cambia {
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
		.saldo--cambia {
			animation: none;
		}
	}

	.saldo {
		font-size: 0.8125rem;
		font-weight: 700;
		background: var(--navy);
		color: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		padding: 1px 6px;
	}

	.attesa {
		font-size: 0.6875rem;
		font-weight: 700;
		background: var(--yellow);
		color: var(--navy);
		border: var(--border-thin) solid var(--navy);
		padding: 0 4px;
	}

	.testata__io {
		display: block;
		line-height: 0;
	}
</style>
