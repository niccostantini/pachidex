/**
 * Genera le icone PWA come pixel art, senza dipendenze:
 * un croquembouche disegnato su griglia 32x32 e scalato a numeri interi
 * (192 = 32x6, 512 = 32x16) cosi' i pixel restano perfettamente quadrati.
 *
 *   node scripts/gen-icons.mjs
 */
import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

/* --- encoder PNG minimale ------------------------------------------------ */
const CRC = (() => {
	const t = new Int32Array(256);
	for (let n = 0; n < 256; n++) {
		let c = n;
		for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
		t[n] = c;
	}
	return t;
})();

const crc32 = (buf) => {
	let c = ~0;
	for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
	return ~c >>> 0;
};

const chunk = (type, data) => {
	const len = Buffer.alloc(4);
	len.writeUInt32BE(data.length);
	const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
	const crc = Buffer.alloc(4);
	crc.writeUInt32BE(crc32(body));
	return Buffer.concat([len, body, crc]);
};

const png = (w, h, rgba) => {
	const stride = w * 4;
	const raw = Buffer.alloc((stride + 1) * h);
	for (let y = 0; y < h; y++) {
		raw[y * (stride + 1)] = 0; // filtro "none": l'arte e' a blocchi piatti
		rgba.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
	}
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(w, 0);
	ihdr.writeUInt32BE(h, 4);
	ihdr[8] = 8; // bit depth
	ihdr[9] = 6; // RGBA
	return Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk('IHDR', ihdr),
		chunk('IDAT', deflateSync(raw, { level: 9 })),
		chunk('IEND', Buffer.alloc(0))
	]);
};

/* --- palette ------------------------------------------------------------- */
const P = {
	_: [240, 85, 43, 255], // arancione, fondo
	n: [22, 27, 61, 255], // navy, contorni
	c: [231, 221, 198, 255], // crema, bignè
	h: [247, 243, 232, 255], // crema chiara, luce
	y: [245, 197, 24, 255], // giallo, caramello
	b: [43, 94, 208, 255] // blu, vassoio
};

/* --- disegno ------------------------------------------------------------- */
const N = 32;
const grid = Array.from({ length: N }, () => Array(N).fill('_'));

const put = (x, y, ch) => {
	x = Math.round(x);
	y = Math.round(y);
	if (x >= 0 && x < N && y >= 0 && y < N) grid[y][x] = ch;
};

/**
 * Un bignè: anello navy piu' cerchio pieno crema con luce in alto a sinistra.
 * L'anello serve a staccare ogni bignè da quelli della fila sotto, altrimenti
 * la piramide legge come una massa unica.
 */
const puff = (cx, cy, r) => {
	const outer = r + 0.9;
	for (let y = Math.floor(cy - outer); y <= Math.ceil(cy + outer); y++) {
		for (let x = Math.floor(cx - outer); x <= Math.ceil(cx + outer); x++) {
			const d = Math.hypot(x - cx, y - cy);
			if (d > outer) continue;
			if (d > r) put(x, y, 'n');
			else put(x, y, d <= r - 1.4 && x < cx && y < cy ? 'h' : 'c');
		}
	}
};

// Quattro file a piramide, dal vertice alla base.
const rows = [1, 2, 3, 4];
const step = 5.6;
const r = 2.4;
// Dal basso verso l'alto: cosi' ogni fila copre il bordo superiore di quella
// sotto, come in un croquembouche vero, invece di venirne intaccata.
[...rows].reverse().forEach((count, ri) => {
	const i = rows.length - 1 - ri;
	const cy = 6.5 + i * 5.3;
	const spread = (count - 1) * step;
	for (let k = 0; k < count; k++) puff(16 - spread / 2 + k * step, cy, r);
});

// Caramello che cola dal vertice.
[
	[16, 3],
	[16, 4],
	[15, 5],
	[17, 5],
	[14, 9],
	[18, 10],
	[11, 14],
	[21, 15]
].forEach(([x, y]) => put(x, y, 'y'));

// Vassoio.
for (let x = 5; x <= 26; x++) {
	put(x, 26, 'b');
	put(x, 27, 'n');
}
for (let x = 7; x <= 24; x++) put(x, 25, 'b');

// Contorno navy: ogni pixel di fondo adiacente al dolce diventa bordo.
const isArt = (ch) => ch !== '_' && ch !== 'n';
const outlined = grid.map((row) => [...row]);
for (let y = 0; y < N; y++) {
	for (let x = 0; x < N; x++) {
		if (grid[y][x] !== '_') continue;
		const near = [
			[1, 0],
			[-1, 0],
			[0, 1],
			[0, -1]
		].some(([dx, dy]) => {
			const ny = y + dy;
			const nx = x + dx;
			return ny >= 0 && ny < N && nx >= 0 && nx < N && isArt(grid[ny][nx]);
		});
		if (near) outlined[y][x] = 'n';
	}
}

// Turappa i buchi di fondo rimasti intrappolati tra due bignè.
for (let y = 0; y < N; y++) {
	for (let x = 0; x < N; x++) {
		if (outlined[y][x] !== '_') continue;
		const filled = [
			[1, 0],
			[-1, 0],
			[0, 1],
			[0, -1]
		].filter(([dx, dy]) => {
			const ny = y + dy;
			const nx = x + dx;
			return ny >= 0 && ny < N && nx >= 0 && nx < N && outlined[ny][nx] !== '_';
		}).length;
		if (filled >= 3) outlined[y][x] = 'n';
	}
}

/* --- rasterizzazione ----------------------------------------------------- */
const render = (scale) => {
	const size = N * scale;
	const buf = Buffer.alloc(size * size * 4);
	for (let y = 0; y < size; y++) {
		for (let x = 0; x < size; x++) {
			const [r0, g0, b0, a0] = P[outlined[(y / scale) | 0][(x / scale) | 0]];
			const o = (y * size + x) * 4;
			buf[o] = r0;
			buf[o + 1] = g0;
			buf[o + 2] = b0;
			buf[o + 3] = a0;
		}
	}
	return png(size, size, buf);
};

for (const [scale, name] of [
	[1, 'static/favicon.png'],
	[6, 'static/icon-192.png'],
	[16, 'static/icon-512.png']
]) {
	const out = render(scale);
	writeFileSync(name, out);
	console.log(`${name} — ${N * scale}x${N * scale} — ${(out.length / 1024).toFixed(1)}KB`);
}
