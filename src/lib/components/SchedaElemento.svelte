<script lang="ts">
	import { etichettaCategoria } from '$lib/game/rules';
	import { riferimentoDi } from '$lib/riferimenti';
	import Foglio from './Foglio.svelte';
	import Rarita from './Rarita.svelte';
	import type { VoceDex } from '$lib/types';

	interface Props {
		voce: VoceDex | null;
		onChiudi: () => void;
	}

	let { voce, onChiudi }: Props = $props();

	const foto = $derived(riferimentoDi(voce?.riferimento));
</script>

<Foglio aperto={!!voce} titolo={voce?.nome ?? ''} variante="navy" {onChiudi}>
	{#if voce}
		<div class="stack">
			{#if foto}
				<figure class="riferimento">
					<img src={foto} alt="Com'e' fatto: {voce.nome}" />
					<figcaption class="t-label">Cosa devi cercare</figcaption>
				</figure>
			{/if}

			<div class="row">
				<Rarita rarita={voce.rarita} croquembouche={voce.croquembouche} />
				<span
					class="badge"
					style:background="var(--cat-{voce.categoria})"
					style:color="var(--paper)"
				>
					{etichettaCategoria(voce.categoria)}
				</span>
				{#if voce.ripetibile}<span class="badge">ripetibile</span>{/if}
				{#if voce.validazione === 'foto_gps'}<span class="badge badge--gps">foto + GPS</span>{/if}
			</div>

			{#if voce.note}
				<p class="note">{voce.note}</p>
			{/if}

			{#if !foto && !voce.note}
				<p class="t-small t-muted">
					Nessun indizio per questo elemento: te la cavi da solo.
				</p>
			{/if}

			<p class="t-small t-muted">
				{#if voce.catture_gruppo > 0}
					Gia' preso da {voce.scopritori}
					{voce.scopritori === 1 ? 'persona' : 'persone'} del gruppo. Tu no, ancora.
				{:else}
					Nessuno del gruppo l'ha ancora trovato. C'e' un primato da prendersi.
				{/if}
			</p>
		</div>
	{/if}
</Foglio>

<style>
	.riferimento {
		border: var(--border) solid var(--navy);
		background: var(--cream);
	}

	.riferimento img {
		width: 100%;
		aspect-ratio: 4 / 3;
		object-fit: cover;
		display: block;
		border-bottom: var(--border-thin) solid var(--navy);
	}

	.riferimento figcaption {
		padding: 5px var(--space-2);
		color: var(--navy-soft);
	}

	.note {
		background: var(--cream);
		border-left: var(--border) solid var(--navy);
		padding: var(--space-2);
		font-size: 0.9375rem;
	}
</style>
