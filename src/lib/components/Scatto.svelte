<script lang="ts">
	/**
	 * Una foto del feed, con le sue proporzioni.
	 *
	 * Prima erano tutte schiacciate a 4:3: un ritratto in verticale veniva
	 * tagliato sopra e sotto, che su un'app dove si fotografano soprattutto
	 * persone e piatti e' il taglio peggiore possibile.
	 *
	 * Il database non sa quanto sono alte le foto — la compressione calcola
	 * larghezza e altezza e poi le butta via — quindi le proporzioni si
	 * scoprono qui, quando l'immagine e' arrivata. Nel frattempo si riserva un
	 * 4:5 verticale: e' la forma piu' probabile, cosi' nella maggioranza dei
	 * casi il posto e' gia' quello giusto e il feed non sobbalza.
	 *
	 * I limiti sono quelli di Instagram, e servono a tenere il feed
	 * scorrevole: una panoramica molto larga diventerebbe una striscia, uno
	 * scatto molto alto si prenderebbe due schermate. Oltre il limite si
	 * ritaglia, ma non si perde niente: toccando la foto la lente la mostra
	 * intera.
	 */
	interface Props {
		src: string;
		alt: string;
		/** L'anteprima appena scattata e' gia' in memoria: inutile aspettarla. */
		pigra?: boolean;
	}

	let { src, alt, pigra = true }: Props = $props();

	/** Verticale massimo 4:5, orizzontale massimo 1.91:1. */
	const PIU_ALTA = 4 / 5;
	const PIU_LARGA = 1.91;

	let el = $state<HTMLImageElement>();
	let rapporto = $state(PIU_ALTA);

	function misura(img: HTMLImageElement) {
		if (!img.naturalWidth || !img.naturalHeight) return;
		rapporto = Math.min(Math.max(img.naturalWidth / img.naturalHeight, PIU_ALTA), PIU_LARGA);
	}

	// Una foto gia' in cache puo' essere completa prima che il gestore onload
	// sia agganciato: in quel caso l'evento non arriva mai piu' e la scheda
	// resterebbe al 4:5 di partenza anche per una foto orizzontale.
	$effect(() => {
		void src;
		if (el?.complete) misura(el);
	});
</script>

<img
	bind:this={el}
	class="scatto"
	style:aspect-ratio={rapporto}
	{src}
	{alt}
	loading={pigra ? 'lazy' : 'eager'}
	onload={(e) => misura(e.currentTarget as HTMLImageElement)}
/>

<style>
	.scatto {
		display: block;
		width: 100%;
		/* Entro i limiti il rapporto e' quello vero, quindi cover non taglia
		   niente: ritaglia solo cio' che li supera. */
		object-fit: cover;
		background: var(--cream);
		border: var(--border) solid var(--navy);
	}
</style>
