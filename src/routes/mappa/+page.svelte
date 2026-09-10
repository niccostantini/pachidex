<script lang="ts">
	import { onMount } from 'svelte';
	import { caricaDex, mieCatture, type MiaVoce } from '$lib/db/dex';
	import { profilo } from '$lib/state/profilo.svelte';
	import { RARITA } from '$lib/game/rules';
	import { messaggioErrore } from '$lib/supabase';
	import type { VoceDex } from '$lib/types';

	let contenitore: HTMLDivElement;
	let stato = $state<'carico' | 'ok' | 'errore' | 'vuota'>('carico');
	let errore = $state<string | null>(null);
	let quanti = $state({ presi: 0, totali: 0 });

	/**
	 * Il fumetto si costruisce a nodi, non a stringa.
	 *
	 * Leaflet mette l'HTML che gli passi dentro innerHTML, quindi qui
	 * l'escape di Svelte non arriva: era l'unico punto dell'app in cui il
	 * nome di una sfiziosita' — che entra anche da un CSV che qualcuno ti
	 * passa — poteva diventare codice invece che testo. Con textContent la
	 * domanda non si pone piu'.
	 */
	function fumetto(p: VoceDex, preso: boolean): HTMLElement {
		const box = document.createElement('div');
		const titolo = document.createElement('strong');
		titolo.textContent = p.nome;
		const valore = document.createElement('span');
		valore.textContent = `${p.rarita} · ${p.croquembouche} ✦`;
		const stato = document.createElement('span');
		stato.textContent = preso ? 'Sbloccato' : 'Ancora da prendere';
		box.append(titolo, document.createElement('br'), valore, document.createElement('br'), stato);
		return box;
	}

	onMount(() => {
		let mappa: import('leaflet').Map | undefined;

		(async () => {
			try {
				// Leaflet arriva solo qui: chi non apre la mappa non lo scarica.
				const [L, voci, mie] = await Promise.all([
					import('leaflet'),
					caricaDex(),
					profilo.io ? mieCatture(profilo.io.id) : Promise.resolve(new Map<string, MiaVoce>())
				]);
				await import('leaflet/dist/leaflet.css');

				const punti = voci.filter(
					(v): v is VoceDex & { lat: number; lng: number } => v.lat != null && v.lng != null
				);
				quanti = {
					presi: punti.filter((p) => mie.has(p.item_id)).length,
					totali: punti.length
				};

				if (!punti.length) {
					stato = 'vuota';
					return;
				}

				mappa = L.map(contenitore, { zoomControl: false, attributionControl: true });
				// Via il "Leaflet" che il controllo mette da solo: e' un link a
				// un altro sito, e su iOS installato aprirebbe il browser interno
				// con le barre di Safari sopra la PWA.
				mappa.attributionControl.setPrefix('');
				L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
					maxZoom: 19,
					attribution: '© OpenStreetMap'
				}).addTo(mappa);
				L.control.zoom({ position: 'bottomright' }).addTo(mappa);

				for (const p of punti) {
					const preso = mie.has(p.item_id);
					// La rarita' passa da un elenco chiuso invece che dal database:
					// finisce dentro un nome di classe, e un nome di classe e' HTML.
					const rarita = RARITA.some((r) => r.valore === p.rarita) ? p.rarita : 'comune';
					const icona = L.divIcon({
						className: 'pin-wrap',
						html: `<span class="pin pin--${rarita} ${preso ? 'pin--preso' : 'pin--libero'}"></span>`,
						iconSize: [22, 22],
						iconAnchor: [11, 11]
					});
					L.marker([p.lat, p.lng], { icon: icona }).addTo(mappa).bindPopup(fumetto(p, preso));
				}

				mappa.fitBounds(
					L.latLngBounds(punti.map((p) => [p.lat, p.lng] as [number, number])),
					{ padding: [40, 40], maxZoom: 15 }
				);

				stato = 'ok';
			} catch (e) {
				errore = messaggioErrore(e);
				stato = 'errore';
			}
		})();

		return () => mappa?.remove();
	});
</script>

<svelte:head><title>Mappa — Pachino Express</title></svelte:head>

<div class="wrap">
	<div class="barra">
		<span class="win__title">Checkpoint</span>
		<span class="conta t-num">{quanti.presi}/{quanti.totali}</span>
	</div>

	<div class="mappa" bind:this={contenitore}></div>

	{#if stato !== 'ok'}
		<div class="sopra">
			{#if stato === 'carico'}
				<p class="t-label">Carico la mappa…</p>
			{:else if stato === 'vuota'}
				<p><strong>Nessun checkpoint.</strong></p>
				<p class="t-small">Servono elementi "posto" con lat e lng, caricati dall'admin.</p>
			{:else}
				<p class="t-small">{errore}</p>
			{/if}
		</div>
	{/if}

	<div class="legenda">
		<span><i class="pin pin--comune pin--libero"></i> comune</span>
		<span><i class="pin pin--raro pin--libero"></i> raro</span>
		<span><i class="pin pin--leggendario pin--libero"></i> leggendario</span>
		<span><i class="pin pin--comune pin--preso"></i> preso</span>
	</div>
</div>

<style>
	.wrap {
		display: flex;
		flex-direction: column;
		height: calc(100dvh - var(--bar-h) - 40px);
		padding: var(--space-3);
		gap: var(--space-2);
		position: relative;
	}

	.barra {
		display: flex;
		align-items: center;
		background: var(--blue);
		color: var(--paper);
		border: var(--border) solid var(--navy);
		padding: 4px var(--space-2);
	}

	.conta {
		margin-left: auto;
		font-weight: 700;
		font-size: 0.8125rem;
	}

	.mappa {
		flex: 1;
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow);
		background: var(--cream);
		min-height: 260px;
	}

	.sopra {
		position: absolute;
		inset: 60px var(--space-3) auto;
		background: var(--paper);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow);
		padding: var(--space-3);
		text-align: center;
	}

	.legenda {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
		font-size: 0.6875rem;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		font-weight: 700;
	}

	.legenda span {
		display: inline-flex;
		align-items: center;
		gap: 4px;
	}

	/* I pin vivono dentro Leaflet, quindi le regole devono uscire dallo scope. */
	:global(.pin) {
		display: block;
		width: 18px;
		height: 18px;
		border: var(--border) solid var(--navy);
		box-sizing: border-box;
	}

	:global(.pin--comune) {
		background: var(--rarity-comune);
	}
	:global(.pin--raro) {
		background: var(--rarity-raro);
	}
	:global(.pin--leggendario) {
		background: var(--rarity-leggendario);
	}

	/* Alone attorno a quelli ancora da prendere: si vedono da lontano. */
	:global(.pin--libero) {
		box-shadow:
			0 0 0 3px var(--paper),
			0 0 0 6px rgba(240, 85, 43, 0.55);
	}

	:global(.pin--preso) {
		opacity: 0.75;
		box-shadow: inset 0 0 0 3px var(--paper);
	}

	:global(.leaflet-container) {
		font-family: var(--font-ui);
		background: var(--cream);
	}

	:global(.leaflet-popup-content-wrapper) {
		border-radius: 0;
		border: var(--border) solid var(--navy);
		background: var(--paper);
		box-shadow: var(--shadow-sm);
	}

	:global(.leaflet-popup-tip) {
		border: var(--border-thin) solid var(--navy);
		background: var(--paper);
	}
</style>
