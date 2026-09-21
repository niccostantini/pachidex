/**
 * Il d20 del blocco «?»: un icosaedro vero, disegnato a pixel.
 *
 * Variante C scelta da Niccolo': 96 px, fluido, retinato fine. Ogni fotogramma
 * ruota i dodici vertici, tiene le facce rivolte verso chi guarda e le riempie
 * a mano su un'ImageData — niente canvas antialias, quindi i bordi restano
 * pixel netti.
 *
 * Il numero lo decide il server prima che il dado parta. L'animazione e'
 * costruita all'indietro: si parte dall'orientamento finale, con la faccia del
 * tiro rivolta verso lo schermo, e ci si mette sopra una rotazione che si
 * smorza fino a zero. Il dado non "cerca" il numero: ci arriva per forza.
 */

type Vec = [number, number, number];
type Mat = [Vec, Vec, Vec];
type Rgba = [number, number, number, number];

const LATO = 96;
const DURATA = 1500;

const PHI = (1 + Math.sqrt(5)) / 2;
const GREZZI: Vec[] = [
	[0, 1, PHI], [0, -1, PHI], [0, 1, -PHI], [0, -1, -PHI],
	[1, PHI, 0], [-1, PHI, 0], [1, -PHI, 0], [-1, -PHI, 0],
	[PHI, 0, 1], [-PHI, 0, 1], [PHI, 0, -1], [-PHI, 0, -1]
];

const norm = (v: Vec): Vec => {
	const l = Math.hypot(...v);
	return [v[0] / l, v[1] / l, v[2] / l];
};
const dist2 = (a: Vec, b: Vec) => (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2;

// Le venti facce: le terne di vertici a distanza 2 l'uno dall'altro.
const FACCE: [number, number, number][] = [];
for (let i = 0; i < 12; i++)
	for (let j = i + 1; j < 12; j++)
		for (let k = j + 1; k < 12; k++)
			if ([dist2(GREZZI[i], GREZZI[j]), dist2(GREZZI[j], GREZZI[k]), dist2(GREZZI[i], GREZZI[k])].every((d) => Math.abs(d - 4) < 0.01))
				FACCE.push([i, j, k]);

const VERTICI = GREZZI.map(norm);
const NORMALI = FACCE.map((f) =>
	norm([0, 1, 2].map((a) => VERTICI[f[0]][a] + VERTICI[f[1]][a] + VERTICI[f[2]][a]) as Vec)
);

function ruota(asse: Vec, t: number): Mat {
	const [x, y, z] = asse;
	const c = Math.cos(t), s = Math.sin(t), C = 1 - c;
	return [
		[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
		[y * x * C + z * s, c + y * y * C, y * z * C - x * s],
		[z * x * C - y * s, z * y * C + x * s, c + z * z * C]
	];
}
const per = (A: Mat, B: Mat): Mat =>
	A.map((r) => [0, 1, 2].map((j) => r[0] * B[0][j] + r[1] * B[1][j] + r[2] * B[2][j])) as Mat;
const applica = (M: Mat, v: Vec): Vec => M.map((r) => r[0] * v[0] + r[1] * v[1] + r[2] * v[2]) as Vec;

/** La rotazione che porta la faccia n verso lo schermo. */
function versoDiMe(n: Vec): Mat {
	const d = n[2];
	if (d > 0.9999) return ruota([1, 0, 0], 0);
	if (d < -0.9999) return ruota([1, 0, 0], Math.PI);
	return ruota(norm([n[1], -n[0], 0]), Math.acos(d));
}

// Font 4x7: piu' piccolo del 3x5 raddoppiato, cosi' il numero sta dentro la faccia.
const CIFRE: Record<string, string> = {
	'0': '.##.#..##..##..##..##..#.##.',
	'1': '.#..##...#...#...#...#..###.',
	'2': '.##.#..#...#..#..#..#...####',
	'3': '###....#...#.##....#...####.',
	'4': '#..##..##..#####...#...#...#',
	'5': '#####...###....#...##..#.##.',
	'6': '.##.#...#...###.#..##..#.##.',
	'7': '####...#..#...#..#...#...#..',
	'8': '.##.#..##..#.##.#..##..#.##.',
	'9': '.##.#..##..#.###...#...#.##.'
};

const hex = (h: string): Rgba => [
	parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16), 255
];
// Le rampe partono dai colori di app.css: --orange, --green, --red al terzo gradino.
const TONI = {
	gira: ['#8f2a10', '#c93f1c', '#f0552b', '#ff946a'].map(hex),
	si: ['#146b56', '#1f8a6f', '#35b79a', '#7fe0c8'].map(hex),
	no: ['#6e1511', '#a8261f', '#d93b32', '#f2847d'].map(hex)
};
const NAVY = hex('#161b3d');
const CARTA = hex('#f7f3e8');
const OMBRA: Rgba = [22, 27, 61, 90];
const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const LUCE = norm([-0.45, 0.6, 1]);

function scrivi(img: ImageData, x0: number, y0: number, numero: number) {
	const s = String(numero);
	let x = Math.round(x0 - (s.length * 5 - 1) / 2);
	const y = Math.round(y0 - 3.5);
	for (const c of s) {
		const g = CIFRE[c];
		for (let r = 0; r < 7; r++)
			for (let k = 0; k < 4; k++) {
				const px = x + k, py = y + r;
				if (g[r * 4 + k] === '#' && px >= 0 && py >= 0 && px < LATO && py < LATO)
					img.data.set(CARTA, (py * LATO + px) * 4);
			}
		x += 5;
	}
}

function disegna(ctx: CanvasRenderingContext2D, M: Mat, salto: number, tono: Rgba[]) {
	const W = LATO;
	const img = ctx.createImageData(W, W);
	const faccia = new Int16Array(W * W).fill(-1);
	const luce = new Float32Array(W * W);
	const R = W * 0.3, cx = W / 2, terra = W * 0.52;
	const cy = terra + salto * W * 0.55;

	// L'ombra a terra: piu' il dado e' in alto, piu' si stringe.
	const larga = R * (1 - Math.min(1, -salto) * 0.6);
	for (let y = 0; y < W; y++)
		for (let x = 0; x < W; x++) {
			const dx = (x - cx) / larga, dy = (y - (terra + R * 1.05)) / (larga * 0.25);
			if (dx * dx + dy * dy < 1 && (x + y) % 2 === 0) img.data.set(OMBRA, (y * W + x) * 4);
		}

	const S = VERTICI.map((v) => {
		const p = applica(M, v);
		return [cx + p[0] * R, cy - p[1] * R];
	});
	const davanti: [number, Vec][] = [];

	FACCE.forEach((f, i) => {
		const n = applica(M, NORMALI[i]);
		if (n[2] <= 0) return; // convesso: basta scartare quelle girate
		davanti.push([i, n]);
		const l = Math.max(0, n[0] * LUCE[0] + n[1] * LUCE[1] + n[2] * LUCE[2]);
		const [a, b, c] = f.map((k) => S[k]);
		const x0 = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0])));
		const x1 = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
		const y0 = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1])));
		const y1 = Math.min(W - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
		const area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
		for (let y = y0; y <= y1; y++)
			for (let x = x0; x <= x1; x++) {
				const px = x + 0.5, py = y + 0.5;
				const w0 = ((b[0] - px) * (c[1] - py) - (b[1] - py) * (c[0] - px)) / area;
				const w1 = ((c[0] - px) * (a[1] - py) - (c[1] - py) * (a[0] - px)) / area;
				if (w0 >= 0 && w1 >= 0 && 1 - w0 - w1 >= 0) {
					faccia[y * W + x] = i;
					luce[y * W + x] = l;
				}
			}
	});

	// Il bordo fra due facce e' il pixel che ha un vicino diverso da lui.
	for (let y = 0; y < W; y++)
		for (let x = 0; x < W; x++) {
			const p = y * W + x, f = faccia[p];
			if (f < 0) continue;
			const bordo = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
				const q = x + dx, r = y + dy;
				return q < 0 || r < 0 || q >= W || r >= W || faccia[r * W + q] !== f;
			});
			if (bordo) {
				img.data.set(NAVY, p * 4);
				continue;
			}
			const gradino = Math.floor(luce[p] * 3.2 + (BAYER[y % 4][x % 4] / 16 - 0.5));
			img.data.set(tono[Math.max(0, Math.min(3, gradino))], p * 4);
		}

	for (const [i, n] of davanti) {
		if (n[2] < 0.55) continue; // di taglio il numero non si legge, e non ci sta
		const c = FACCE[i].map((k) => S[k]);
		scrivi(img, (c[0][0] + c[1][0] + c[2][0]) / 3, (c[0][1] + c[1][1] + c[2][1]) / 3, i + 1);
	}
	ctx.putImageData(img, 0, 0);
}

/** Cade, rimbalza due volte e si posa. */
function salto(t: number): number {
	if (t < 0.32) return -(1 - (t / 0.32) ** 2);
	if (t < 0.58) return -0.28 * Math.sin((Math.PI * (t - 0.32)) / 0.26);
	if (t < 0.78) return -0.09 * Math.sin((Math.PI * (t - 0.58)) / 0.2);
	return 0;
}

/**
 * Tira il dado dentro un canvas e chiama `fine` quando si e' posato.
 * Restituisce la funzione per fermarlo, se il fumetto si chiude prima.
 */
export function lanciaDado(
	canvas: HTMLCanvasElement,
	tiro: number,
	riuscito: boolean,
	fine: () => void
): () => void {
	canvas.width = LATO;
	canvas.height = LATO;
	const ctx = canvas.getContext('2d');
	if (!ctx) {
		fine();
		return () => {};
	}
	const finale = versoDiMe(NORMALI[tiro - 1]);
	const esito = riuscito ? TONI.si : TONI.no;

	if (matchMedia('(prefers-reduced-motion: reduce)').matches) {
		disegna(ctx, finale, 0, esito);
		queueMicrotask(fine);
		return () => {};
	}

	const asse = norm([Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5]);
	const giri = Math.PI * (6 + Math.random() * 3);
	const inizio = performance.now();
	let fermo = false;

	function fotogramma(ora: number) {
		if (fermo) return;
		const t = Math.min(1, (ora - inizio) / DURATA);
		const frena = 1 - (1 - t) ** 3;
		disegna(ctx!, per(ruota(asse, giri * (1 - frena)), finale), salto(t), t === 1 ? esito : TONI.gira);
		if (t < 1) requestAnimationFrame(fotogramma);
		else fine();
	}
	requestAnimationFrame(fotogramma);
	return () => (fermo = true);
}
