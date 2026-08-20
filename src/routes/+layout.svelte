<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { dev } from '$app/environment';
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { profilo } from '$lib/state/profilo.svelte';
	import { coda } from '$lib/state/coda.svelte';
	import Intestazione from '$lib/components/Intestazione.svelte';
	import Taskbar from '$lib/components/Taskbar.svelte';

	let { children } = $props();

	const inAdmin = $derived(page.url.pathname.startsWith('/gestione-'));
	const inScelta = $derived(page.url.pathname.startsWith('/chi-sei'));
	const inGioco = $derived(!inAdmin && !inScelta);

	onMount(() => {
		void profilo.carica();
		void coda.init();

		// La registrazione del service worker va fatta a mano: il plugin PWA
		// genera registerSW.js ma con SvelteKit non lo aggancia da nessuna
		// parte, e senza registrazione navigator.serviceWorker.ready non si
		// risolve MAI — le notifiche restavano appese all'infinito.
		//
		// Solo in produzione: in sviluppo il plugin servirebbe il service
		// worker in TypeScript non compilato, che il browser non sa eseguire.
		// Le push vanno comunque provate sul deploy, perche' su iOS servono
		// HTTPS e la PWA installata.
		if (!dev) {
			void import('virtual:pwa-register').then(({ registerSW }) =>
				registerSW({ immediate: true })
			);
		}
	});

	// Nessun profilo scelto: si passa dalla porta "Chi sei?". L'admin no, cosi'
	// il pannello resta raggiungibile anche da un telefono vergine.
	$effect(() => {
		if (profilo.pronto && !profilo.io && inGioco) void goto('/chi-sei', { replaceState: true });
	});
</script>

{#if inGioco}
	<Intestazione />
{/if}

<main class="app" class:app--libera={!inGioco}>
	{#if !profilo.pronto && inGioco}
		<div class="avvio">
			<div class="avvio__box win">
				<div class="win__body">
					<p class="t-label">Caricamento…</p>
				</div>
			</div>
		</div>
	{:else if profilo.errore && inGioco}
		<div class="pad">
			<div class="win">
				<header class="win__bar win__bar--navy"><span class="win__title">Errore</span></header>
				<div class="win__body stack">
					<p>Non riesco a parlare con il database.</p>
					<p class="t-small t-muted">{profilo.errore}</p>
					<button class="btn btn--sm" onclick={() => location.reload()}>Riprova</button>
				</div>
			</div>
		</div>
	{:else}
		{@render children()}
	{/if}
</main>

{#if inGioco}
	<Taskbar />
{/if}

<style>
	.app--libera {
		padding-bottom: var(--space-4);
	}

	.avvio {
		display: grid;
		place-items: center;
		min-height: 60dvh;
		padding: var(--space-4);
	}

	.avvio__box {
		min-width: 200px;
		text-align: center;
	}
</style>
