<script lang="ts">
	import type { Coccarda } from '$lib/db/coccarde';

	/**
	 * La fila delle coccarde.
	 *
	 * Il colore dice cosa hai vinto, non quanto: oro, argento e bronzo per il
	 * podio, blu per i titoli. Sotto, la stagione — senza quella una coccarda
	 * e' solo un adesivo, con quella e' una data in cui sei stato il migliore
	 * a qualcosa.
	 */
	let { coccarde, compatte = false }: { coccarde: Coccarda[]; compatte?: boolean } = $props();

	const classe = (c: Coccarda) =>
		c.tipo === 'podio' ? `coccarda--podio coccarda--p${c.chiave}` : 'coccarda--titolo';
</script>

{#if coccarde.length}
	<ul class="coccarde" class:coccarde--compatte={compatte}>
		{#each coccarde as c (c.id)}
			<li class="coccarda {classe(c)}" title="Stagione {c.stagione}">
				<span class="coccarda__che">{c.etichetta}</span>
				{#if !compatte}
					<span class="coccarda__quando t-label">
						stagione {c.stagione}{c.quanto ? ` · ${c.quanto}` : ''}
					</span>
				{/if}
			</li>
		{/each}
	</ul>
{/if}

<style>
	.coccarde {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.coccarda {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: 5px 8px;
		border: var(--border-thin) solid var(--navy);
		background: var(--cream);
		color: var(--navy);
	}

	.coccarda__che {
		font-weight: 700;
		font-size: var(--fs-testo);
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.coccarda__quando {
		opacity: 0.75;
	}

	.coccarda--p1 {
		background: var(--yellow);
	}

	.coccarda--p2 {
		background: var(--paper);
	}

	.coccarda--p3 {
		background: var(--orange);
		color: var(--paper);
	}

	.coccarda--titolo {
		background: var(--blue);
		color: var(--paper);
	}

	.coccarde--compatte .coccarda {
		padding: 2px 6px;
	}

	.coccarde--compatte .coccarda__che {
		font-size: var(--fs-testo);
	}
</style>
