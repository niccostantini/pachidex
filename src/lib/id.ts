/**
 * UUID v4 che funziona anche fuori da un contesto sicuro.
 *
 * `crypto.randomUUID()` e' disponibile solo in secure context (https, oppure
 * localhost): provando l'app dal telefono su http://192.168.x.x e' undefined,
 * e Safari lo segnala con un errore che sembra un bug del codice.
 * `crypto.getRandomValues()` invece c'e' anche in contesto non sicuro, quindi
 * si costruisce l'uuid a mano con quello.
 */
export function idUnico(): string {
	const c = globalThis.crypto;
	if (typeof c?.randomUUID === 'function') return c.randomUUID();

	const b = new Uint8Array(16);
	if (typeof c?.getRandomValues === 'function') {
		c.getRandomValues(b);
	} else {
		// Ultima spiaggia: qui l'id serve solo come chiave di una coda locale,
		// non come segreto, quindi Math.random e' accettabile.
		for (let i = 0; i < 16; i++) b[i] = Math.floor(Math.random() * 256);
	}

	b[6] = (b[6] & 0x0f) | 0x40; // versione 4
	b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122

	const hex = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('');
	return [
		hex.slice(0, 8),
		hex.slice(8, 12),
		hex.slice(12, 16),
		hex.slice(16, 20),
		hex.slice(20)
	].join('-');
}
