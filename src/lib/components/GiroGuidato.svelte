<script lang="ts" module>
	/**
	 * Giro guidato con effetto riflettore.
	 *
	 * Il buco nel velo non si fa con maschere o clip-path, che a bordo
	 * frattale danno problemi diversi su ogni browser: si disegnano quattro
	 * pannelli scuri attorno al bersaglio. Il ritaglio e' esatto per
	 * costruzione, i bordi restano netti come vuole lo stile, e ogni pannello
	 * puo' portarsi la trama a puntini.
	 */
	export interface Tappa {
		/** Valore dell'attributo data-giro sull'elemento da illuminare. */
		bersaglio: string;
		titolo: string;
		testo: string;
		/** Righe extra: le usa solo la tappa della cattura, spiegata in dettaglio. */
		dettagli?: string[];
	}

	export const TAPPE: Tappa[] = [
		{
			bersaglio: 'feed',
			titolo: 'Il feed',
			testo:
				'Qui scorre tutto quello che succede: ogni cattura, ogni scambio, ogni contestazione. È la cronaca della vacanza, in ordine di quando è successa.'
		},
		{
			bersaglio: 'dex',
			titolo: 'Il PachiDex',
			testo:
				'Le sfiziosità da trovare, divise in posti, pietanze, animali e attività. I blocchi ? sono quelle che ti mancano: il nome si vede sempre, così sai cosa cercare. Toccane uno e ti dice com’è fatto.'
		},
		{
			bersaglio: 'mappa',
			titolo: 'La mappa',
			testo:
				'I checkpoint sparsi sul territorio, colorati per rarità. Quelli con l’alone attorno non li ha ancora presi nessuno.'
		},
		{
			bersaglio: 'top',
			titolo: 'La classifica',
			testo:
				'Due gare diverse: chi ha più Croquembouche e chi ha collezionato più roba. Si può vincere una e perdere l’altra, perché i Croquembouche si scambiano fra voi.'
		},
		{
			bersaglio: 'storia',
			titolo: 'I puntini piccini picciò',
			testo:
				'Questa barra è di tutti. Ogni cattura del gruppo la riempie di quanto vale, e a ogni soglia si sblocca un capitolo della storia. Si svuota solo con le contestazioni.'
		},
		{
			bersaglio: 'campanella',
			titolo: 'Le notifiche',
			testo:
				'Da qui si attivano, una volta sola. Su iPhone funzionano solo se hai aggiunto l’app alla schermata Home: dal browser non arriva niente, e non è colpa tua.'
		},
		{
			bersaglio: 'cattura',
			titolo: 'E adesso: cattura',
			testo: 'Il pulsante che fa girare tutto. Funziona così:',
			dettagli: [
				'Scatti la foto, o la prendi dalla galleria se l’animale non ti ha aspettato',
				'Scegli cosa hai catturato dalla lista',
				'Se sei su un checkpoint te lo propone da solo: il GPS sa dove sei — ma quelli vanno fotografati sul posto, niente galleria',
				'Nella didascalia scrivi @nome per dare i punti anche a chi era con te',
				'I Croquembouche arrivano subito, ma gli altri possono contestare'
			]
		}
	];
</script>

<script lang="ts">
	import { onMount } from 'svelte';

	interface Props {
		tappe?: Tappa[];
		onFine: () => void;
	}

	let { tappe = TAPPE, onFine }: Props = $props();

	/** Quanto respiro lasciare attorno all'elemento illuminato. */
	const ARIA = 6;

	let indice = $state(0);
	let rect = $state<{ top: number; left: number; width: number; height: number } | null>(null);
	let vh = $state(0);
	let vw = $state(0);

	const tappa = $derived(tappe[indice]);
	const ultima = $derived(indice === tappe.length - 1);

	/** Il fumetto sta sotto il riflettore se c'e' posto, altrimenti sopra. */
	const sotto = $derived(rect ? rect.top + rect.height < vh * 0.45 : true);

	function misura() {
		vh = window.innerHeight;
		vw = window.innerWidth;
		const el = document.querySelector<HTMLElement>(`[data-giro="${tappa?.bersaglio}"]`);
		if (!el) {
			rect = null;
			return;
		}
		const r = el.getBoundingClientRect();
		rect = {
			top: Math.max(r.top - ARIA, 0),
			left: Math.max(r.left - ARIA, 0),
			width: Math.min(r.width + ARIA * 2, window.innerWidth),
			height: r.height + ARIA * 2
		};
	}

	function avanti() {
		if (ultima) {
			onFine();
			return;
		}
		indice++;
	}

	onMount(() => {
		// Il giro parte dall'alto: la barra della storia e in cima al feed e
		// se la pagina e gia' scrollata resterebbe fuori dal riflettore.
		window.scrollTo({ top: 0 });
		misura();

		const suCambio = () => misura();
		addEventListener('resize', suCambio);
		addEventListener('scroll', suCambio, { passive: true });

		const suTasto = (e: KeyboardEvent) => {
			if (e.key === 'Escape') onFine();
			if (e.key === 'ArrowRight' || e.key === 'Enter' || e.key === ' ') {
				e.preventDefault();
				avanti();
			}
		};
		addEventListener('keydown', suTasto);

		return () => {
			removeEventListener('resize', suCambio);
			removeEventListener('scroll', suCambio);
			removeEventListener('keydown', suTasto);
		};
	});

	// Cambiando tappa si rimisura: l'elemento e un altro.
	$effect(() => {
		void indice;
		misura();
	});
</script>

<div class="giro" role="dialog" aria-modal="true" aria-label="Giro guidato">
	{#if rect}
		<!-- I quattro pannelli attorno al buco. Cliccarli avanza: cosi' un tocco
		     qualunque sullo schermo va avanti, che e' quello che uno fa. -->
		<button class="velo" style:top="0" style:left="0" style:width="100%" style:height="{rect.top}px" onclick={avanti} aria-label="Avanti"></button>
		<button
			class="velo"
			style:top="{rect.top + rect.height}px"
			style:left="0"
			style:width="100%"
			style:height="{Math.max(vh - rect.top - rect.height, 0)}px"
			onclick={avanti}
			aria-label="Avanti"
		></button>
		<button class="velo" style:top="{rect.top}px" style:left="0" style:width="{rect.left}px" style:height="{rect.height}px" onclick={avanti} aria-label="Avanti"></button>
		<button
			class="velo"
			style:top="{rect.top}px"
			style:left="{rect.left + rect.width}px"
			style:width="{Math.max(vw - rect.left - rect.width, 0)}px"
			style:height="{rect.height}px"
			onclick={avanti}
			aria-label="Avanti"
		></button>

		<!-- La cornice sul bersaglio. Intercetta il tocco, altrimenti si
		     finirebbe per navigare davvero invece di proseguire il giro. -->
		<button
			class="faro"
			style:top="{rect.top}px"
			style:left="{rect.left}px"
			style:width="{rect.width}px"
			style:height="{rect.height}px"
			onclick={avanti}
			aria-label="Avanti"
		></button>
	{:else}
		<button class="velo velo--pieno" onclick={avanti} aria-label="Avanti"></button>
	{/if}

	<div
		class="fumetto"
		class:fumetto--sotto={sotto}
		style:top={rect && sotto ? `${rect.top + rect.height + 12}px` : 'auto'}
		style:bottom={rect && !sotto ? `${Math.max(vh - rect.top + 12, 0)}px` : 'auto'}
	>
		<div class="win">
			<header class="win__bar">
				<span class="win__title">{tappa.titolo}</span>
				<span class="passo t-num">{indice + 1}/{tappe.length}</span>
			</header>
			<div class="win__body">
				<p class="testo">{tappa.testo}</p>

				{#if tappa.dettagli}
					<ul class="dettagli">
						{#each tappa.dettagli as d (d)}
							<li>{d}</li>
						{/each}
					</ul>
				{/if}

				<div class="azioni">
					<button class="btn btn--sm" onclick={onFine}>
						{ultima ? 'Chiudi' : 'Salta'}
					</button>
					<button class="btn btn--sm btn--primary grow" onclick={avanti}>
						{ultima ? 'Comincia!' : 'Avanti'}
					</button>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.giro {
		position: fixed;
		inset: 0;
		z-index: 100;
	}

	.velo {
		position: fixed;
		border: 0;
		padding: 0;
		cursor: pointer;
		/* Stessa trama dei fogli modali: puntini, non sfocatura. */
		background: repeating-conic-gradient(
			rgba(22, 27, 61, 0.88) 0% 25%,
			rgba(22, 27, 61, 0.74) 0% 50%
		);
		background-size: 4px 4px;
	}

	.velo--pieno {
		inset: 0;
		width: 100%;
		height: 100%;
	}

	.faro {
		position: fixed;
		background: transparent;
		border: var(--border) solid var(--orange);
		box-shadow:
			0 0 0 2px var(--navy),
			inset 0 0 0 2px var(--navy);
		cursor: pointer;
		padding: 0;
	}

	.fumetto {
		position: fixed;
		left: 50%;
		transform: translateX(-50%);
		width: min(340px, calc(100vw - var(--space-4) * 2));
		max-height: 60dvh;
		overflow-y: auto;
	}

	.passo {
		margin-left: auto;
		font-size: 0.6875rem;
		font-weight: 700;
		background: var(--navy);
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		padding: 0 5px;
		flex-shrink: 0;
	}

	.testo {
		font-size: 0.9375rem;
		margin-bottom: var(--space-3);
	}

	.dettagli {
		display: flex;
		flex-direction: column;
		gap: 5px;
		margin-bottom: var(--space-3);
		font-size: 0.875rem;
	}

	.dettagli li {
		position: relative;
		padding-left: 16px;
	}

	.dettagli li::before {
		content: '▪';
		position: absolute;
		left: 0;
		color: var(--orange);
	}

	.azioni {
		display: flex;
		gap: var(--space-2);
	}
</style>
