<script lang="ts">
	import { tempoRelativo } from '$lib/game/rules';
	import Avatar from './Avatar.svelte';
	import Icona from './Icona.svelte';
	import type { PostScambio } from '$lib/types';

	interface Props {
		post: PostScambio;
	}

	let { post }: Props = $props();
</script>

<article class="scambio">
	<div class="scambio__riga">
		<Avatar utente={post.mittente} dimensione="sm" />
		<Icona nome="scambio" dimensione={16} sfondo="var(--cream)" />
		<Avatar utente={post.destinatario} dimensione="sm" />

		<div class="grow t-small">
			<a class="chi" href="/profilo/{post.mittente.id}"><strong>{post.mittente.nome}</strong></a>
			ha passato
			<strong class="importo">✦ {post.importo}</strong>
			a <a class="chi" href="/profilo/{post.destinatario.id}"><strong>{post.destinatario.nome}</strong></a>
		</div>

		<span class="t-small t-muted">{tempoRelativo(post.created_at)}</span>
	</div>

	{#if post.causale}
		<p class="causale t-small">“{post.causale}”</p>
	{/if}
</article>

<style>
	.chi {
		color: inherit;
		text-decoration: none;
	}

	.chi:active {
		text-decoration: underline;
	}

	.scambio {
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.scambio__riga {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.importo {
		color: var(--orange-dark);
		font-variant-numeric: tabular-nums;
	}

	.causale {
		color: var(--navy-soft);
		padding-left: 30px;
	}
</style>
