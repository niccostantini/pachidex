<script lang="ts">
	import type { StatoStoria } from '$lib/db/storia';

	interface Props {
		storia: StatoStoria | null;
	}

	let { storia }: Props = $props();
</script>

{#if storia}
	<a class="barra" href="/storia" data-giro="storia">
		<div class="barra__testa">
			<span class="t-label">
				{#if storia.prossimo}
					Capitolo {storia.prossimo.numero}
				{:else}
					Storia completa
				{/if}
			</span>
			<span class="t-label conta t-num">
				{#if storia.prossimo}
					{storia.mancano} puntini
				{:else}
					tutti e {storia.capitoli.length}
				{/if}
			</span>
		</div>

		<div class="pista">
			<div class="pista__riempi" style:width="{storia.avanzamento * 100}%"></div>
			<!-- Le tacche dei capitoli gia' presi: si vede la strada fatta. -->
			{#each storia.capitoli.filter((c) => c.sbloccato) as c (c.numero)}
				<span class="tacca" aria-hidden="true"></span>
			{/each}
		</div>

		<p class="t-small t-muted">
			{#if storia.prossimo}
				{storia.punti} puntini piccini picciò · mancano {storia.mancano} al prossimo capitolo
			{:else}
				{storia.punti} puntini piccini picciò · li avete sbloccati tutti
			{/if}
		</p>
	</a>
{/if}

<style>
	.barra {
		display: block;
		background: var(--navy);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
		padding: var(--space-2);
		color: var(--paper);
		text-decoration: none;
	}

	.barra:active {
		transform: translate(3px, 3px);
		box-shadow: none;
	}

	.barra__testa {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		margin-bottom: 5px;
	}

	.conta {
		color: var(--yellow);
	}

	.pista {
		position: relative;
		display: flex;
		align-items: center;
		height: 16px;
		background: var(--cream);
		border: var(--border-thin) solid var(--paper);
		overflow: hidden;
	}

	.pista__riempi {
		position: absolute;
		inset: 0 auto 0 0;
		background: repeating-linear-gradient(
			90deg,
			var(--orange) 0 6px,
			var(--orange-dark) 6px 12px
		);
	}

	/* Un quadratino per capitolo gia' sbloccato, come le monete raccolte. */
	.tacca {
		position: relative;
		width: 7px;
		height: 7px;
		margin-left: 4px;
		background: var(--yellow);
		border: 1px solid var(--navy);
		flex-shrink: 0;
	}

	.barra p {
		margin-top: 5px;
		color: rgba(247, 243, 232, 0.72);
	}
</style>
