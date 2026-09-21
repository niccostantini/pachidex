<script lang="ts">
	import { onMount } from 'svelte';
	import { caricaConfig, caricaDex, mieCatture, type MiaVoce } from '$lib/db/dex';
	import {
		apriBlocco,
		blocchiVicini,
		segnalaLuogo,
		POSTE,
		ZOOM_MINIMO,
		type Blocco,
		type Esito
	} from '$lib/db/blocchi';
	import { lanciaDado } from '$lib/game/dado';
	import { distanzaMetri, formattaDistanza, osservaPosizione, type Posizione } from '$lib/game/geo';
	import { profilo } from '$lib/state/profilo.svelte';
	import { RARITA } from '$lib/game/rules';
	import { messaggioErrore } from '$lib/supabase';
	import type { VoceDex } from '$lib/types';

	let contenitore: HTMLDivElement;
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);
	let quanti = $state({ presi: 0, totali: 0 });
	let lontano = $state(false);

	/** Senza checkpoint e senza GPS la mappa parte da qui. */
	const ROMA: [number, number] = [41.8986, 12.4769];

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

	// --- il pin «?» ---------------------------------------------------------
	// Variante B scelta da Niccolo': un segnaposto a pixel, colorato dalla posta.
	const GOCCIA = [
		'...######...',
		'..#......#..',
		'.#........#.',
		'#..........#',
		'#..........#',
		'#..........#',
		'#..........#',
		'.#........#.',
		'..#......#..',
		'...#....#...',
		'....#..#....',
		'.....##.....'
	];
	const PUNTO = ['.###.', '#...#', '....#', '...#.', '..#..', '.....', '..#..'];

	function pinBlocco(posta: string): string {
		const r = (x: number, y: number, fill: string) =>
			`<rect x="${x}" y="${y}" width="1" height="1" style="fill:${fill}"/>`;
		let s = '';
		GOCCIA.forEach((riga, y) => {
			const da = riga.indexOf('#');
			const a = riga.lastIndexOf('#');
			[...riga].forEach((c, x) => {
				if (c === '#') s += r(x + 2, y + 1, 'var(--navy)');
				else if (x > da && x < a) s += r(x + 2, y + 1, `var(--posta-${posta})`);
			});
		});
		PUNTO.forEach((riga, y) =>
			[...riga].forEach((c, x) => {
				if (c === '#') s += r(x + 5.5, y + 2.5, 'var(--paper)');
			})
		);
		return `<svg class="blocco" viewBox="0 0 16 14" width="28" height="25" shape-rendering="crispEdges">${s}</svg>`;
	}

	function riga(testo: string, classe = ''): HTMLElement {
		const p = document.createElement('span');
		p.className = classe;
		p.textContent = testo;
		return p;
	}

	// Il d20 vive in $lib/game/dado: qui solo il posto dove cade.
	function dadoAnimato(e: Esito, fine: () => void): HTMLElement {
		const scena = document.createElement('div');
		scena.className = 'dado-scena';
		const tela = document.createElement('canvas');
		tela.className = 'dado';
		tela.setAttribute('role', 'img');
		tela.setAttribute('aria-label', `d20: ${e.tiro}`);
		scena.append(tela);
		lanciaDado(tela, e.tiro, e.riuscito, fine);
		return scena;
	}

	function racconta(e: Esito): HTMLElement[] {
		const dado = riga(`d20: ${e.tiro} contro CD ${e.cd}`, 'esito__dado');
		if (!e.trappola) {
			return e.riuscito
				? [dado, riga(`Premio! +${e.croquembouche} ✦`, 'esito esito--si')]
				: [dado, riga(`Era un premio, ma serviva ${e.cd}.`, 'esito')];
		}
		return e.riuscito
			? [dado, riga('Era una trappola: schivata.', 'esito esito--si')]
			: [dado, riga(`Trappola! ${e.croquembouche} ✦`, 'esito esito--no')];
	}

	onMount(() => {
		let mappa: import('leaflet').Map | undefined;
		let smetti = () => {};
		let giro: ReturnType<typeof setInterval> | undefined;

		(async () => {
			try {
				// Leaflet arriva solo qui: chi non apre la mappa non lo scarica.
				const [L, voci, mie, config] = await Promise.all([
					import('leaflet'),
					caricaDex(),
					profilo.io ? mieCatture(profilo.io.id) : Promise.resolve(new Map<string, MiaVoce>()),
					caricaConfig()
				]);
				await import('leaflet/dist/leaflet.css');
				const raggio = config.raggio_gps_metri ?? 100;

				const punti = voci.filter(
					(v): v is VoceDex & { lat: number; lng: number } => v.lat != null && v.lng != null
				);
				quanti = {
					presi: punti.filter((p) => mie.has(p.item_id)).length,
					totali: punti.length
				};

				const m = L.map(contenitore, { zoomControl: false, attributionControl: true });
				mappa = m;
				// Via il "Leaflet" che il controllo mette da solo: e' un link a
				// un altro sito, e su iOS installato aprirebbe il browser interno
				// con le barre di Safari sopra la PWA.
				m.attributionControl.setPrefix('');
				L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
					maxZoom: 19,
					attribution: '© OpenStreetMap'
				}).addTo(m);
				L.control.zoom({ position: 'bottomright' }).addTo(m);

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
					L.marker([p.lat, p.lng], { icon: icona }).addTo(m).bindPopup(fumetto(p, preso));
				}

				if (punti.length) {
					m.fitBounds(L.latLngBounds(punti.map((p) => [p.lat, p.lng] as [number, number])), {
						padding: [40, 40],
						maxZoom: 15
					});
				} else {
					m.setView(ROMA, 15);
				}

				// --- dove sei ---------------------------------------------
				let pos: Posizione | null = null;
				let io: import('leaflet').CircleMarker | undefined;
				let centrata = false;
				smetti = osservaPosizione((p) => {
					pos = p;
					if (!io) {
						io = L.circleMarker([p.lat, p.lng], { radius: 7, className: 'io' }).addTo(m);
					} else {
						io.setLatLng([p.lat, p.lng]);
					}
					// La prima posizione buona diventa il centro, come in Pokemon Go: i
					// checkpoint vanno da Pachino a Roma, e inquadrarli tutti apre la
					// mappa sull'Italia intera, dove i blocchi non si vedono.
					if (!centrata) {
						centrata = true;
						m.setView([p.lat, p.lng], 16);
					}
				});

				// --- i blocchi --------------------------------------------
				const strato = L.layerGroup().addTo(m);
				// Le poste passano da un elenco chiuso: finiscono in un nome di variabile CSS.
				const icone = Object.fromEntries(
					POSTE.map((p) => [
						p,
						L.divIcon({ className: 'pin-wrap', html: pinBlocco(p), iconSize: [28, 25], iconAnchor: [14, 24] })
					])
				);

				function fumettoBlocco(b: Blocco): HTMLElement {
					const box = document.createElement('div');
					box.className = 'fumetto-blocco';
					const titolo = document.createElement('strong');
					titolo.textContent = b.nome;
					const scade = new Date(b.scade_at).toLocaleTimeString('it-IT', {
						hour: '2-digit',
						minute: '2-digit'
					});
					box.append(
						titolo,
						riga(`Posta ${b.posta} · ${b.croquembouche} ✦ · CD ${b.cd}`),
						riga(
							`Premio o trappola? Sparisce ${scade === '00:00' ? 'a mezzanotte' : `alle ${scade}`}.`,
							't-small'
						)
					);

					const dist = pos ? distanzaMetri(pos.lat, pos.lng, b.lat, b.lng) : null;
					if (dist == null) {
						box.append(riga('Serve il GPS per aprirlo.', 't-small'));
					} else if (dist > raggio) {
						box.append(riga(`Sei a ${formattaDistanza(dist)}: avvicinati.`, 't-small'));
					} else {
						const apri = document.createElement('button');
						apri.className = 'btn btn--primary';
						apri.textContent = 'Apri e tira il d20';
						apri.onclick = async () => {
							if (!pos) return;
							apri.disabled = true;
							try {
								const esito = await apriBlocco(b.luogo_id, pos.lat, pos.lng);
								const scena = dadoAnimato(esito, () => scena.after(...racconta(esito)));
								apri.replaceWith(scena);
							} catch (e) {
								apri.replaceWith(riga(messaggioErrore(e), 'esito esito--no'));
							}
						};
						box.append(apri);
					}

					const segnala = document.createElement('button');
					segnala.className = 'segnala';
					segnala.textContent = 'Posto brutto o chiuso?';
					segnala.onclick = async () => {
						if (!confirm(`Segnalare «${b.nome}»? Con due segnalazioni esce dal gioco.`)) return;
						try {
							await segnalaLuogo(b.luogo_id);
							segnala.replaceWith(riga('Segnalato, grazie.', 't-small'));
						} catch (e) {
							segnala.replaceWith(riga(messaggioErrore(e), 't-small'));
						}
					};
					box.append(segnala);
					return box;
				}

				let chiesta = 0;
				async function aggiorna() {
					lontano = m.getZoom() < ZOOM_MINIMO;
					if (lontano) {
						strato.clearLayers();
						return;
					}
					// Una risposta vecchia che arriva dopo una nuova non deve vincere.
					const questa = ++chiesta;
					const b = m.getBounds();
					const blocchi = await blocchiVicini(b.getSouth(), b.getWest(), b.getNorth(), b.getEast());
					if (questa !== chiesta) return;
					// Un fumetto aperto con un esito dentro non si chiude sotto le dita.
					const aperto = m.getContainer().querySelector('.fumetto-blocco .dado-scena');
					if (aperto) return;
					strato.clearLayers();
					for (const bl of blocchi) {
						L.marker([bl.lat, bl.lng], { icon: icone[bl.posta] ?? icone.piccola })
							.bindPopup(() => fumettoBlocco(bl))
							.addTo(strato);
					}
				}

				m.on('moveend', () => aggiorna().catch(() => {}));
				m.on('popupclose', () => aggiorna().catch(() => {}));
				// Allo scadere della fascia i blocchi cambiano posto.
				giro = setInterval(() => aggiorna().catch(() => {}), 60_000);
				await aggiorna();

				stato = 'ok';
			} catch (e) {
				errore = messaggioErrore(e);
				stato = 'errore';
			}
		})();

		return () => {
			smetti();
			clearInterval(giro);
			mappa?.remove();
		};
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
			{:else}
				<p class="t-small">{errore}</p>
			{/if}
		</div>
	{:else if lontano}
		<div class="sopra sopra--basso">
			<p class="t-small">Avvicina la mappa per vedere i blocchi «?».</p>
		</div>
	{/if}

	<div class="legenda">
		<span><i class="pin pin--comune pin--libero"></i> comune</span>
		<span><i class="pin pin--raro pin--libero"></i> raro</span>
		<span><i class="pin pin--leggendario pin--libero"></i> leggendario</span>
		<span><i class="pin pin--comune pin--preso"></i> preso</span>
		<span>
			{#each POSTE as p (p)}<i class="posta" style:background="var(--posta-{p})"></i>{/each}
			? piccola → enorme
		</span>
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

	.sopra--basso {
		/* Sopra i pannelli di Leaflet, che arrivano a 1000. */
		z-index: 1001;
		inset: auto var(--space-3) 60px;
		padding: var(--space-2);
	}

	.posta {
		display: inline-block;
		width: 10px;
		height: 10px;
		border: var(--border-thin) solid var(--navy);
	}

	:global(.blocco) {
		display: block;
		image-rendering: pixelated;
	}

	:global(.io) {
		fill: var(--blue);
		fill-opacity: 1;
		stroke: var(--paper);
		stroke-width: 3;
	}

	:global(.fumetto-blocco) {
		display: flex;
		flex-direction: column;
		gap: 4px;
		min-width: 180px;
	}

	:global(.fumetto-blocco .btn) {
		margin-top: var(--space-2);
	}

	:global(.fumetto-blocco .dado-scena) {
		display: flex;
		justify-content: center;
		margin-top: var(--space-2);
	}

	/* 96 pixel del canvas a 96 px CSS: su schermo retina ogni pixel resta netto. */
	:global(.fumetto-blocco .dado) {
		width: 96px;
		height: 96px;
		image-rendering: pixelated;
	}

	:global(.fumetto-blocco .esito__dado) {
		margin-top: var(--space-2);
		font-family: var(--font-mono, monospace);
	}

	:global(.fumetto-blocco .esito) {
		font-weight: 700;
	}
	:global(.fumetto-blocco .esito--si) {
		color: var(--green);
	}
	:global(.fumetto-blocco .esito--no) {
		color: var(--red);
	}

	:global(.fumetto-blocco .segnala) {
		all: unset;
		cursor: pointer;
		margin-top: var(--space-2);
		font-size: 0.6875rem;
		text-decoration: underline;
		color: var(--navy-soft);
	}

	/*
	 * Leaflet porta il suo CSS dopo il nostro, quindi a parita' di peso vince
	 * lui: angoli tondi e font di sistema. Agganciate a .mappa, queste regole
	 * pesano di piu' e il tema resta nostro.
	 */
	.mappa:global(.leaflet-container) {
		font: inherit;
		font-family: var(--font-ui);
		background: var(--cream);
	}

	.mappa :global(.leaflet-popup-content-wrapper) {
		border-radius: 0;
		border: var(--border) solid var(--navy);
		background: var(--paper);
		color: var(--navy);
		box-shadow: var(--shadow-sm);
	}

	.mappa :global(.leaflet-popup-content) {
		margin: var(--space-3);
		font-size: 0.8125rem;
		line-height: 1.4;
	}

	.mappa :global(.leaflet-popup-content strong) {
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.mappa :global(.leaflet-popup-tip) {
		border: var(--border-thin) solid var(--navy);
		background: var(--paper);
		box-shadow: none;
	}

	.mappa :global(.leaflet-popup-close-button) {
		color: var(--navy);
		font-weight: 700;
	}

	.mappa :global(.leaflet-bar),
	.mappa :global(.leaflet-bar a) {
		border-radius: 0;
		border-color: var(--navy);
		color: var(--navy);
		background: var(--paper);
	}

	.mappa :global(.leaflet-bar) {
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
	}
</style>
