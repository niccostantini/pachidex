<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { schermo } from '$lib/state/schermo.svelte';
	import { profilo } from '$lib/state/profilo.svelte';
	import Icona from '$lib/components/Icona.svelte';

	let { children } = $props();

	const sezioni = [
		{ href: '/gestione-xk29', label: 'Riepilogo' },
		{ href: '/gestione-xk29/item', label: 'Sfiziosita' },
		{ href: '/gestione-xk29/import', label: 'Import CSV' },
		{ href: '/gestione-xk29/config', label: 'Regole' },
		{ href: '/gestione-xk29/set', label: 'Set' },
		{ href: '/gestione-xk29/storia', label: 'Storia' },
		{ href: '/gestione-xk29/contestazioni', label: 'Contestazioni' },
		{ href: '/gestione-xk29/profili', label: 'Giocatori' },
		{ href: '/gestione-xk29/finale', label: 'Premiazione' }
	];

	const attiva = (href: string) =>
		href === '/gestione-xk29' ? page.url.pathname === href : page.url.pathname.startsWith(href);

	onMount(() => schermo.init());
</script>

<svelte:head><title>Gestione — Pachino Express</title></svelte:head>

<div class="admin">
	<header class="admin__bar">
		<Icona nome="chiave" dimensione={16} colore="var(--paper)" sfondo="var(--navy)" />
		<span class="win__title">Pannello di gestione</span>
		<span class="grow"></span>
		<a class="esci t-label" href="/">Torna al gioco</a>
	</header>

	<nav class="admin__nav">
		{#each sezioni as s (s.href)}
			<a class="voce" class:voce--on={attiva(s.href)} href={s.href}>{s.label}</a>
		{/each}
	</nav>

	<div class="admin__corpo">
		{#if !profilo.pronto}
			<p class="t-label t-muted">Carico…</p>
		{:else}
			{@render children()}
		{/if}
	</div>
</div>

<style>
	.admin {
		max-width: 1100px;
		margin: 0 auto;
		padding-bottom: var(--space-6);
	}

	.admin__bar {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		background: var(--navy);
		color: var(--paper);
		padding: var(--space-2) var(--space-3);
		padding-top: calc(var(--space-2) + env(safe-area-inset-top));
		position: sticky;
		top: 0;
		z-index: 20;
	}

	.esci {
		color: var(--yellow);
	}

	.admin__nav {
		display: flex;
		overflow-x: auto;
		gap: 3px;
		padding: var(--space-2) var(--space-3) 0;
		background: var(--navy);
		scrollbar-width: none;
	}

	.admin__nav::-webkit-scrollbar {
		display: none;
	}

	.voce {
		flex-shrink: 0;
		padding: 7px var(--space-3);
		background: var(--navy-soft);
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		border-bottom: 0;
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		text-decoration: none;
	}

	/* La linguetta attiva sale sopra il bordo, come le tab di una cartella. */
	.voce--on {
		background: var(--cream);
		color: var(--navy);
		position: relative;
		top: 2px;
	}

	.admin__corpo {
		padding: var(--space-3);
		border-top: var(--border) solid var(--navy);
	}
</style>
