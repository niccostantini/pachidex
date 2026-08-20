/**
 * Le foto restano nitide (e' una scelta di design: pixel e' l'interfaccia,
 * non il contenuto), ma non ha senso spedire 6 MB da una spiaggia con una
 * tacca di segnale. Qui si ridimensiona e si ricomprime prima dell'upload,
 * scegliendo il formato piu' efficiente che il browser sa davvero produrre.
 */

export type Formato = 'avif' | 'webp' | 'jpg';

export interface FotoPronta {
	blob: Blob;
	larghezza: number;
	altezza: number;
	estensione: Formato;
}

const MIME: Record<Formato, string> = {
	avif: 'image/avif',
	webp: 'image/webp',
	jpg: 'image/jpeg'
};

/** Dal piu' efficiente al piu' compatibile. */
const PREFERENZE: Formato[] = ['avif', 'webp', 'jpg'];

let supportati: Formato[] | null = null;

/**
 * Quali formati il browser sa davvero codificare.
 *
 * Il controllo e' necessario perche' canvas.toBlob NON fallisce quando non
 * conosce un formato: ripiega in silenzio su PNG. Chiedere image/avif a un
 * browser senza encoder AVIF restituisce quindi un PNG, che per una foto e'
 * il peggior formato possibile. L'unico modo di saperlo e' guardare il
 * blob.type di cio' che torna indietro.
 */
async function formatiDisponibili(): Promise<Formato[]> {
	if (supportati) return supportati;

	const canvas = document.createElement('canvas');
	canvas.width = canvas.height = 8;
	const ctx = canvas.getContext('2d');
	if (ctx) {
		ctx.fillStyle = '#000';
		ctx.fillRect(0, 0, 8, 8);
	}

	const esiti: Formato[] = [];
	for (const formato of PREFERENZE) {
		const blob = await new Promise<Blob | null>((r) => canvas.toBlob(r, MIME[formato], 0.8));
		if (blob?.type === MIME[formato]) esiti.push(formato);
	}

	// jpeg e' obbligatorio per specifica: se la sonda fallisse comunque,
	// meglio provarci che restare senza formati.
	supportati = esiti.length ? esiti : ['jpg'];
	return supportati;
}

async function decodifica(file: File): Promise<ImageBitmap | HTMLImageElement> {
	if ('createImageBitmap' in window) {
		try {
			// from-image applica l'orientamento EXIF: senza, le foto scattate
			// in verticale arrivano coricate.
			return await createImageBitmap(file, { imageOrientation: 'from-image' });
		} catch {
			/* si passa al ripiego */
		}
	}
	const url = URL.createObjectURL(file);
	try {
		const img = new Image();
		img.src = url;
		await img.decode();
		return img;
	} finally {
		setTimeout(() => URL.revokeObjectURL(url), 0);
	}
}

export async function comprimiFoto(
	file: File,
	latoMax = 1600,
	qualita = 0.82
): Promise<FotoPronta> {
	const sorgente = await decodifica(file);
	const w0 = 'width' in sorgente ? sorgente.width : 0;
	const h0 = 'height' in sorgente ? sorgente.height : 0;
	const scala = Math.min(1, latoMax / Math.max(w0, h0));
	const larghezza = Math.round(w0 * scala);
	const altezza = Math.round(h0 * scala);

	const canvas = document.createElement('canvas');
	canvas.width = larghezza;
	canvas.height = altezza;
	const ctx = canvas.getContext('2d');
	if (!ctx) throw new Error('Non riesco a preparare la foto');
	ctx.drawImage(sorgente as CanvasImageSource, 0, 0, larghezza, altezza);
	if ('close' in sorgente) sorgente.close();

	const formati = await formatiDisponibili();
	for (const formato of formati) {
		const blob = await new Promise<Blob | null>((r) =>
			canvas.toBlob(r, MIME[formato], qualita)
		);
		// Si ricontrolla il tipo anche qui: la sonda usa un quadrato di 8px,
		// e non e' detto che un encoder regga un'immagine grande allo stesso modo.
		if (blob && blob.type === MIME[formato]) {
			return { blob, larghezza, altezza, estensione: formato };
		}
	}

	throw new Error('Non riesco a comprimere la foto');
}

/** Anteprima locale immediata: la foto si vede prima ancora di partire. */
export const anteprima = (b: Blob) => URL.createObjectURL(b);
