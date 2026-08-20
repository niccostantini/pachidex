<script lang="ts">
	import { iniziali } from '$lib/game/rules';
	import { avatarDi } from '$lib/avatars';
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

	const sprite = $derived(avatarDi(utente?.nome));
</script>

{#if sprite}
	<img class={classe} src={sprite} alt={utente?.nome} loading="lazy" />
{:else}
	<!-- Chi non ha uno sprite disegnato (un profilo aggiunto dopo) tiene le
	     iniziali sul suo colore. -->
	<span
		class="{classe} avatar--initials"
		style:background={utente?.colore ?? 'var(--navy-soft)'}
		title={utente?.nome}
	>
		{utente ? iniziali(utente.nome) : '??'}
	</span>
{/if}
