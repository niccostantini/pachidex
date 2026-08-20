/**
 * Le foto restano nitide (e' una scelta di design: pixel e' l'interfaccia,
 * non il contenuto), ma non ha senso spedire 6 MB da una spiaggia con una
 * tacca di segnale. Qui si ridimensiona e si ricomprime prima dell'upload.
 */

export interface FotoPronta {
	blob: Blob;
	larghezza: number;
	altezza: number;
	estensione: 'webp' | 'jpg';
}

let supportoWebp: boolean | null = null;

function webpDisponibile(): boolean {
	if (supportoWebp === null) {
		const c = document.createElement('canvas');
		c.width = c.height = 1;
		supportoWebp = c.toDataURL('image/webp').startsWith('data:image/webp');
	}
	return supportoWebp;
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

	const webp = webpDisponibile();
	const blob = await new Promise<Blob | null>((r) =>
		canvas.toBlob(r, webp ? 'image/webp' : 'image/jpeg', qualita)
	);
	if (!blob) throw new Error('Non riesco a comprimere la foto');

	return { blob, larghezza, altezza, estensione: webp ? 'webp' : 'jpg' };
}

/** Anteprima locale immediata: la foto si vede prima ancora di partire. */
export const anteprima = (b: Blob) => URL.createObjectURL(b);
