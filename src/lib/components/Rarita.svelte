<script lang="ts">
	import { etichettaRarita } from '$lib/game/rules';
	import type { Rarita } from '$lib/types';

	interface Props {
		rarita: Rarita;
		croquembouche?: number;
	}

	let { rarita, croquembouche }: Props = $props();
</script>

<span class="badge badge--{rarita}">
	{etichettaRarita(rarita)}
	{#if croquembouche !== undefined}
		<span class="sep">·</span>
		{croquembouche} ✦
	{/if}
</span>

<style>
	.sep {
		opacity: 0.5;
	}
</style>
