<script lang="ts">
	import { rete, quantoFa } from '$lib/state/rete.svelte';
	import { coda } from '$lib/state/coda.svelte';

	/**
	 * La striscia che dice come sta la linea.
	 *
	 * Compare solo quando c'e' qualcosa da confessare: niente rete, oppure
	 * dati ripescati dalla cache. Il punto e' non far credere a nessuno che
	 * la classifica che sta guardando sia quella di adesso.
	 */
	const inCoda = $derived(coda.inAttesa.length);
	const mostra = $derived(!rete.online || rete.daCache);

	// Si ricalcola da sola: "poco fa" non deve restare li' per un'ora.
	let adesso = $state(Date.now());
	$effect(() => {
		if (!mostra) return;
		const t = setInterval(() => (adesso = Date.now()), 60000);
		return () => clearInterval(t);
	});

	const eta = $derived.by(() => {
		void adesso; // ridipende dal minuto che passa
		return rete.quando === null ? null : quantoFa(rete.quando);
	});
</script>

{#if mostra}
	<div class="rete" class:rete--giu={!rete.online} role="status">
		<span class="spia" aria-hidden="true"></span>
		<span class="testo t-label">
			{#if !rete.online}
				{eta ? `Sei offline — dati di ${eta}` : 'Sei offline'}
			{:else}
				Dati di {eta ?? 'prima'}
			{/if}
		</span>
		{#if inCoda}
			<span class="coda t-num">{inCoda} in coda</span>
		{/if}
	</div>
{/if}

<style>
	.rete {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: 5px var(--space-3);
		background: var(--yellow);
		color: var(--navy);
		border-bottom: var(--border) solid var(--navy);
	}

	/* Senza linea il tono cambia: arancione, si vede da lontano. */
	.rete--giu {
		background: var(--orange);
	}

	/* Un quadratino che lampeggia a scatti, come una spia che non sta bene. */
	.spia {
		width: 8px;
		height: 8px;
		flex-shrink: 0;
		background: var(--navy);
		animation: spia 1.2s steps(1, end) infinite;
	}

	@keyframes spia {
		0%,
		50% {
			opacity: 1;
		}
		50.01%,
		100% {
			opacity: 0.15;
		}
	}

	.testo {
		flex: 1;
		min-width: 0;
	}

	.coda {
		font-size: 0.6875rem;
		font-weight: 700;
		background: var(--navy);
		color: var(--paper);
		padding: 0 5px;
		flex-shrink: 0;
	}

	@media (prefers-reduced-motion: reduce) {
		.spia {
			animation: none;
		}
	}
</style>
