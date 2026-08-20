<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		titolo?: string;
		variante?: 'orange' | 'blue' | 'navy' | 'green';
		/** I tre bottoni della barra: decorativi, tranne la X quando c'e' onChiudi. */
		bottoni?: boolean;
		onChiudi?: () => void;
		flush?: boolean;
		ombra?: boolean;
		children: Snippet;
		barra?: Snippet;
	}

	let {
		titolo,
		variante = 'orange',
		bottoni = true,
		onChiudi,
		flush = false,
		ombra = true,
		children,
		barra
	}: Props = $props();
</script>

<section class="win" class:win--flat={!ombra}>
	{#if titolo || barra}
		<header class="win__bar win__bar--{variante}">
			{#if barra}
				{@render barra()}
			{:else}
				<span class="win__title">{titolo}</span>
			{/if}
			{#if bottoni}
				<div class="win__btns">
					<span class="win__btn" aria-hidden="true">–</span>
					<span class="win__btn" aria-hidden="true">□</span>
					{#if onChiudi}
						<button class="win__btn" data-action="chiudi" onclick={onChiudi} aria-label="Chiudi">
							×
						</button>
					{:else}
						<span class="win__btn" aria-hidden="true">×</span>
					{/if}
				</div>
			{/if}
		</header>
	{/if}
	<div class="win__body" class:win__body--flush={flush}>
		{@render children()}
	</div>
</section>
