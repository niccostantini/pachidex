<script lang="ts">
	import { page } from '$app/state';
	import Icona, { type NomeIcona } from './Icona.svelte';

	const voci: { href: string; label: string; icona: NomeIcona }[] = [
		{ href: '/', label: 'Feed', icona: 'feed' },
		{ href: '/pachidex', label: 'Dex', icona: 'dex' },
		{ href: '/mappa', label: 'Mappa', icona: 'mappa' },
		{ href: '/classifica', label: 'Top', icona: 'classifica' }
	];

	const attivo = (href: string) =>
		href === '/' ? page.url.pathname === '/' : page.url.pathname.startsWith(href);
</script>

<nav class="taskbar" aria-label="Navigazione principale">
	<div class="taskbar__lato">
		{#each voci.slice(0, 2) as v (v.href)}
			<a class="tab" class:tab--attivo={attivo(v.href)} href={v.href}>
				<Icona nome={v.icona} dimensione={18} sfondo="var(--navy)" />
				<span class="tab__label">{v.label}</span>
			</a>
		{/each}
	</div>

	<a class="fab" href="/cattura" aria-label="Cattura">
		<Icona nome="foto" dimensione={28} colore="var(--paper)" sfondo="var(--orange)" />
	</a>

	<div class="taskbar__lato">
		{#each voci.slice(2) as v (v.href)}
			<a class="tab" class:tab--attivo={attivo(v.href)} href={v.href}>
				<Icona nome={v.icona} dimensione={18} sfondo="var(--navy)" />
				<span class="tab__label">{v.label}</span>
			</a>
		{/each}
	</div>
</nav>

<style>
	.taskbar {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		z-index: 40;
		display: flex;
		align-items: stretch;
		justify-content: space-between;
		height: var(--bar-h);
		padding-bottom: env(safe-area-inset-bottom);
		background: var(--navy);
		border-top: var(--border) solid var(--navy);
		box-shadow: 0 -3px 0 rgba(22, 27, 61, 0.15);
	}

	.taskbar__lato {
		display: flex;
		flex: 1;
		min-width: 0;
	}

	.tab {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 2px;
		color: rgba(247, 243, 232, 0.65);
		text-decoration: none;
		border-right: var(--border-thin) solid rgba(247, 243, 232, 0.12);
		-webkit-tap-highlight-color: transparent;
	}

	/* La voce attiva e' "premuta", come un bottone di taskbar vero. */
	.tab--attivo {
		color: var(--paper);
		background: rgba(247, 243, 232, 0.14);
		box-shadow: inset 2px 2px 0 rgba(22, 27, 61, 0.6);
	}

	.tab__label {
		font-size: 0.5625rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.1em;
	}

	.fab {
		position: relative;
		flex-shrink: 0;
		width: 62px;
		height: 62px;
		margin: -16px 6px 0;
		display: grid;
		place-items: center;
		background: var(--orange);
		border: var(--border) solid var(--navy);
		box-shadow: 4px 4px 0 rgba(22, 27, 61, 0.55);
		-webkit-tap-highlight-color: transparent;
	}

	.fab:active {
		transform: translate(4px, 4px);
		box-shadow: none;
	}
</style>
