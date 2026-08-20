<script lang="ts">
	interface Props {
		valore: number;
		segno?: boolean;
		etichetta?: boolean;
	}

	let { valore, segno = false, etichetta = false }: Props = $props();
</script>

<span class="croq" class:croq--pos={segno && valore > 0} class:croq--neg={segno && valore < 0}>
	<span class="croq__icon" aria-hidden="true">✦</span>
	<span class="t-num">{segno && valore > 0 ? '+' : ''}{valore}</span>
	{#if etichetta}<span class="t-label">Croquembouche</span>{/if}
</span>
