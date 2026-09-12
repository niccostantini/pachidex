<script lang="ts">
	/**
	 * Coriandoli e scoppiettii, in pixel.
	 *
	 * Regola della casa: il pixel e' l'interfaccia. Quindi niente cerchietti
	 * che ruotano morbidi — quadretti netti, che cadono a scatti e si girano
	 * di taglio come fa un pezzo di carta vero. Le animazioni sono a `steps()`
	 * come tutto il resto dell'app: e' lo stesso motivo per cui il blocco
	 * della cattura rimbalza invece di dissolversi.
	 *
	 * Gli "scoppiettii" sono i fuochi: un anello di quadretti che parte da un
	 * punto e si allarga, poi sparisce. Servono a segnare un momento preciso
	 * — il nome di chi ha vinto un titolo — mentre i coriandoli fanno da
	 * sfondo continuo.
	 *
	 * Si rimonta per rigiocarla: `{#key}` sul componente e riparte da capo,
	 * che e' piu' semplice che disfare e rifare trenta animazioni a mano.
	 */
	interface Props {
		/** Quanti coriandoli. Zero li spegne. */
		quanti?: number;
		/** Quanti scoppi, e ogni quanto. */
		scoppi?: number;
		/** Da dove cadono: tutta la larghezza, o stretti attorno al centro. */
		larghezza?: 'piena' | 'centro';
	}

	let { quanti = 44, scoppi = 3, larghezza = 'piena' }: Props = $props();

	const COLORI = ['var(--yellow)', 'var(--orange)', 'var(--green)', 'var(--blue)', 'var(--red)'];

	/**
	 * A caso, ma calcolato una volta sola: dipende solo da quanti ne servono,
	 * quindi finche' quel numero non cambia le posizioni restano ferme.
	 * Ricalcolarle a ogni ridisegno farebbe saltellare i coriandoli a meta'
	 * caduta.
	 */
	const pezzi = $derived.by(() =>
		Array.from({ length: quanti }, (_, i) => ({
			x: larghezza === 'piena' ? Math.random() * 100 : 30 + Math.random() * 40,
			colore: COLORI[i % COLORI.length],
			/** Larghi il doppio degli altri: due misure bastano a non sembrare una griglia. */
			grande: Math.random() < 0.35,
			ritardo: Math.random() * 900,
			durata: 1500 + Math.random() * 1400,
			deriva: `${Math.round((Math.random() - 0.5) * 90)}px`
		}))
	);

	/**
	 * Gli scoppi si stringono attorno al centro quando la festa e' "centro":
	 * li' sopra c'e' il nome di chi ha vinto il titolo, ed e' quello che
	 * devono indicare. Sparpagliati per tutto lo schermo scoppierebbero sul
	 * niente, che e' rumore e basta.
	 */
	const botti = $derived.by(() =>
		Array.from({ length: scoppi }, (_, i) => ({
			x: larghezza === 'centro' ? 38 + Math.random() * 24 : 20 + Math.random() * 60,
			y: larghezza === 'centro' ? 26 + Math.random() * 16 : 15 + Math.random() * 45,
			ritardo: i * 320 + Math.random() * 180,
			colore: COLORI[(i + 1) % COLORI.length]
		}))
	);

	/** Otto direzioni: le diagonali di una griglia, non un cerchio. */
	const RAGGI = [0, 45, 90, 135, 180, 225, 270, 315];
</script>

<div class="festicciola" aria-hidden="true">
	{#each pezzi as p, i (i)}
		<span
			class="pezzo"
			class:pezzo--grande={p.grande}
			style:left="{p.x}%"
			style:background={p.colore}
			style:animation-delay="{p.ritardo}ms"
			style:animation-duration="{p.durata}ms"
			style:--deriva={p.deriva}
		></span>
	{/each}

	{#each botti as b, i (i)}
		<span class="botto" style:left="{b.x}%" style:top="{b.y}%">
			{#each RAGGI as ang (ang)}
				<span
					class="scintilla"
					style:--ang="{ang}deg"
					style:background={b.colore}
					style:animation-delay="{b.ritardo}ms"
				></span>
			{/each}
		</span>
	{/each}
</div>

<style>
	.festicciola {
		position: fixed;
		inset: 0;
		overflow: hidden;
		pointer-events: none;
		z-index: 60;
	}

	/* --- i coriandoli --------------------------------------------------- */
	.pezzo {
		position: absolute;
		top: -16px;
		width: 6px;
		height: 6px;
		animation-name: cade;
		animation-timing-function: steps(18, end);
		animation-fill-mode: forwards;
	}

	.pezzo--grande {
		width: 10px;
		height: 6px;
	}

	/*
	 * Il taglio: scaleX che passa per zero fa "girare" il quadretto come un
	 * pezzo di carta, e a steps() si vede il salto invece della morbidezza.
	 * Dura meno della caduta apposta, cosi' i due tempi non vanno a braccetto
	 * e i coriandoli non sembrano marciare.
	 */
	.pezzo::after {
		content: '';
		position: absolute;
		inset: 0;
		background: inherit;
		animation: taglia 420ms steps(4, end) infinite;
	}

	@keyframes cade {
		from {
			transform: translate3d(0, 0, 0);
			opacity: 1;
		}
		85% {
			opacity: 1;
		}
		to {
			transform: translate3d(var(--deriva, 0), 105vh, 0);
			opacity: 0;
		}
	}

	@keyframes taglia {
		0% {
			transform: scaleX(1);
		}
		50% {
			transform: scaleX(0.2);
		}
		100% {
			transform: scaleX(1);
		}
	}

	/* --- gli scoppiettii ------------------------------------------------ */
	.botto {
		position: absolute;
		width: 0;
		height: 0;
	}

	.scintilla {
		position: absolute;
		width: 5px;
		height: 5px;
		animation: scoppia 620ms steps(5, end) forwards;
		opacity: 0;
	}

	@keyframes scoppia {
		from {
			transform: rotate(var(--ang)) translateY(0);
			opacity: 1;
		}
		to {
			transform: rotate(var(--ang)) translateY(-58px);
			opacity: 0;
		}
	}

	/*
	 * Chi ha chiesto meno movimento non vuole quaranta quadretti che gli
	 * attraversano lo schermo. Qui non si perde niente: e' decorazione pura,
	 * quello che conta e' scritto sotto.
	 */
	@media (prefers-reduced-motion: reduce) {
		.festicciola {
			display: none;
		}
	}
</style>
