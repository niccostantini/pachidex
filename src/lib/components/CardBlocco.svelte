<script lang="ts">
	import { tempoRelativo } from '$lib/game/rules';
	import Avatar from './Avatar.svelte';
	import type { PostBlocco } from '$lib/types';

	interface Props {
		post: PostBlocco;
	}

	let { post }: Props = $props();

	const riuscito = $derived(post.tiro >= post.cd);
	// Frasi senza genere: nel gruppo non si da' per scontato chi e' chi.
	const cosa = $derived(
		post.trappola
			? riuscito
				? 'ha schivato una trappola a'
				: 'ha preso una trappola a'
			: riuscito
				? 'ha aperto un ? a'
				: 'ha aperto un ? a vuoto a'
	);
</script>

<article class="blocco">
	<Avatar utente={post.autore} dimensione="sm" />

	<div class="grow t-small">
		<a class="chi" href="/profilo/{post.autore.id}"><strong>{post.autore.nome}</strong></a>
		{cosa}
		<strong>{post.luogo_nome}</strong>
		· d20 <strong class="t-num">{post.tiro}</strong>/{post.cd}
		{#if post.croquembouche > 0}
			· <strong class="piu">+{post.croquembouche} ✦</strong>
		{:else if post.croquembouche < 0}
			· <strong class="meno">−{-post.croquembouche} ✦</strong>
		{/if}
	</div>

	<span class="t-small t-muted">{tempoRelativo(post.created_at)}</span>
</article>

<style>
	.blocco {
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.chi {
		color: inherit;
		text-decoration: none;
	}

	.chi:active {
		text-decoration: underline;
	}

	.piu {
		color: var(--green);
		font-variant-numeric: tabular-nums;
	}

	.meno {
		color: var(--red);
		font-variant-numeric: tabular-nums;
	}
</style>
