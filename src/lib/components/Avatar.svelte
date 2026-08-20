<script lang="ts">
	import { iniziali } from '$lib/game/rules';
	import type { User } from '$lib/types';

	interface Props {
		utente: User | null | undefined;
		dimensione?: 'sm' | 'md' | 'lg';
	}

	let { utente, dimensione = 'md' }: Props = $props();

	const classe = $derived(
		['avatar', dimensione === 'lg' && 'avatar--lg', dimensione === 'sm' && 'avatar--sm']
			.filter(Boolean)
			.join(' ')
	);
</script>

{#if utente?.avatar}
	<img class={classe} src={utente.avatar} alt={utente.nome} loading="lazy" />
{:else}
	<!-- Finche' l'admin non carica lo sprite, le iniziali sul colore del giocatore. -->
	<span
		class="{classe} avatar--initials"
		style:background={utente?.colore ?? 'var(--navy-soft)'}
		title={utente?.nome}
	>
		{utente ? iniziali(utente.nome) : '??'}
	</span>
{/if}
