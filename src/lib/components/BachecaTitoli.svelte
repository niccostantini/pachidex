<script lang="ts">
	import { TITOLI, type VoceTitolo } from '$lib/db/titoli';
	import { profilo } from '$lib/state/profilo.svelte';
	import Avatar from './Avatar.svelte';

	interface Props {
		titoli: VoceTitolo[];
	}

	let { titoli }: Props = $props();

	const perTitolo = $derived(new Map(titoli.map((t) => [t.titolo, t])));
</script>

<ul class="bacheca">
	{#each TITOLI as t (t.titolo)}
		{@const vinto = perTitolo.get(t.titolo)}
		{@const chi = vinto ? profilo.utenti.find((u) => u.id === vinto.user_id) : null}
		<li class="riga" class:riga--mia={chi && chi.id === profilo.io?.id}>
			<div class="grow">
				<p class="titolo">{t.nome}</p>
				<p class="come t-small t-muted">{t.come}</p>
			</div>

			{#if chi && vinto}
				<div class="chi">
					<Avatar utente={chi} dimensione="sm" />
					<div class="chi__testo">
						<span class="chi__nome t-small">{chi.nome}</span>
						<span class="chi__conta t-num t-small">{t.unita(vinto.conteggio)}</span>
					</div>
				</div>
			{:else}
				<!-- Nessuna l'ha ancora preso: si dice, perche' un titolo libero
				     e' un invito e vale piu' di una riga vuota. -->
				<span class="palio t-label">in palio</span>
			{/if}
		</li>
	{/each}
</ul>

<style>
	.bacheca {
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

	/* Il tuo si vede: e' quello che ti possono soffiare. */
	.riga--mia {
		background: var(--yellow);
		box-shadow: var(--shadow-sm);
	}

	.titolo {
		font-weight: 700;
		line-height: 1.15;
	}

	.come {
		margin-top: 1px;
	}

	.chi {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-shrink: 0;
	}

	.chi__testo {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		line-height: 1.2;
	}

	.chi__nome {
		font-weight: 700;
	}

	.chi__conta {
		color: var(--orange-dark);
		font-weight: 700;
	}

	.palio {
		flex-shrink: 0;
		color: var(--navy);
		background: var(--paper);
		border: var(--border-thin) dashed var(--navy);
		padding: 3px 7px;
	}
</style>
