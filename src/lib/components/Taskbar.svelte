<script lang="ts">
	import { page } from '$app/state';
	import Icona, { type NomeIcona } from './Icona.svelte';
	import { profilo } from '$lib/state/profilo.svelte';
	import { visto } from '$lib/state/visto.svelte';

	const voci: { href: string; label: string; icona: NomeIcona; giro: string }[] = [
		{ href: '/', label: 'Feed', icona: 'feed', giro: 'feed' },
		{ href: '/pachidex', label: 'Dex', icona: 'dex', giro: 'dex' },
		{ href: '/mappa', label: 'Mappa', icona: 'mappa', giro: 'mappa' },
		{ href: '/classifica', label: 'Top', icona: 'classifica', giro: 'top' }
	];

	const attivo = (href: string) =>
		href === '/' ? page.url.pathname === '/' : page.url.pathname.startsWith(href);

	/**
	 * Il pallino sul feed: c'e' roba che non hai visto.
	 *
	 * Senza numero. Un "12" li' sopra diventa un compito da smaltire, e
	 * questo non e' un lavoro arretrato: e' una vacanza di cui ti sei perso
	 * un pezzo. Che ci sia qualcosa basta a farti guardare.
	 *
	 * Sul feed non si mostra mai: se lo stai guardando, il puntino ti sta
	 * dicendo una cosa che hai gia' sotto gli occhi.
	 */
	const pallino = $derived(visto.nuovi > 0 && page.url.pathname !== '/');
</script>

<nav class="taskbar" aria-label="Navigazione principale">
	<div class="taskbar__lato">
		{#each voci.slice(0, 2) as v (v.href)}
			<a class="tab" class:tab--attivo={attivo(v.href)} href={v.href} data-giro={v.giro}>
				<span class="tab__icona">
					<Icona nome={v.icona} dimensione={18} sfondo="var(--navy)" />
					{#if v.href === '/' && pallino}
						<span class="pallino" aria-label="C'è qualcosa di nuovo"></span>
					{/if}
				</span>
				<span class="tab__label">{v.label}</span>
			</a>
		{/each}
	</div>

	<!-- Chi ha un account di sola lettura non vede il pulsante: il server lo
	     fermerebbe comunque, ma invitarlo a premere sarebbe scortese. -->
	{#if !profilo.soloSguardo}
		<a class="fab" href="/cattura" aria-label="Cattura" data-giro="cattura">
			<Icona nome="foto" dimensione={28} colore="var(--paper)" sfondo="var(--orange)" />
		</a>
	{/if}

	<div class="taskbar__lato">
		{#each voci.slice(2) as v (v.href)}
			<a class="tab" class:tab--attivo={attivo(v.href)} href={v.href} data-giro={v.giro}>
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
		/*
		 * L'altezza DEVE sommare la safe-area, non contenerla: con
		 * box-sizing border-box — che vale globalmente — scrivere
		 * `height: 56px` e `padding-bottom: 34px` lascia 22px al contenuto,
		 * e icone ed etichette si schiacciano. Su un iPhone con la barra
		 * home l'icona finiva resa a 2px invece di 18.
		 */
		height: calc(var(--bar-h) + env(safe-area-inset-bottom));
		padding-bottom: env(safe-area-inset-bottom);
		background: var(--navy);
		border-top: var(--border) solid var(--navy);
		box-shadow: 0 -3px 0 rgba(22, 27, 61, 0.15);
	}

	.tab__icona {
		position: relative;
		display: block;
		line-height: 0;
	}

	/*
	 * Arancione su blu scuro, quadrato come tutto il resto: un cerchietto qui
	 * sarebbe l'unica cosa tonda dell'interfaccia.
	 */
	.pallino {
		position: absolute;
		top: -3px;
		right: -5px;
		width: 8px;
		height: 8px;
		background: var(--orange);
		border: 1px solid var(--navy);
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
		font-size: var(--fs-testo);
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
