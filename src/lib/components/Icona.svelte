<script lang="ts" module>
	/**
	 * Icone disegnate a rettangoli su griglia 12x12: restano pixel perfetti a
	 * qualsiasi dimensione e pesano quanto un attributo.
	 * "pieni" e' l'inchiostro, "buchi" e' quello che si ritaglia via.
	 */
	type Rect = [x: number, y: number, w: number, h: number];
	type Forma = {
		pieni: Rect[];
		buchi?: Rect[];
		/** Disegnati per ultimi, sopra i buchi: pupille, dettagli interni. */
		punti?: Rect[];
	};

	export const ICONE = {
		feed: {
			pieni: [
				[1, 2, 3, 3],
				[5, 2, 6, 1],
				[5, 4, 4, 1],
				[1, 7, 3, 3],
				[5, 7, 6, 1],
				[5, 9, 4, 1]
			]
		},
		dex: {
			pieni: [
				[1, 1, 4, 4],
				[7, 1, 4, 4],
				[1, 7, 4, 4],
				[7, 7, 4, 4]
			]
		},
		mappa: {
			pieni: [
				[4, 0, 4, 1],
				[3, 1, 6, 4],
				[4, 5, 4, 1],
				[5, 6, 2, 1],
				[5, 8, 2, 3]
			],
			buchi: [[5, 2, 2, 2]]
		},
		classifica: {
			pieni: [
				[0, 7, 3, 4],
				[4, 3, 4, 8],
				[9, 6, 3, 5]
			]
		},
		foto: {
			pieni: [
				[4, 1, 4, 1],
				[1, 2, 10, 9]
			],
			buchi: [
				[5, 4, 2, 5],
				[4, 5, 4, 3]
			]
		},
		cuore: {
			pieni: [
				[1, 2, 4, 1],
				[7, 2, 4, 1],
				[0, 3, 12, 3],
				[1, 6, 10, 1],
				[2, 7, 8, 1],
				[3, 8, 6, 1],
				[4, 9, 4, 1],
				[5, 10, 2, 1]
			],
			buchi: [[5, 3, 2, 1]]
		},
		scambio: {
			pieni: [
				[1, 2, 8, 1],
				[7, 0, 1, 1],
				[8, 1, 1, 1],
				[9, 2, 2, 1],
				[8, 3, 1, 1],
				[7, 4, 1, 1],
				[3, 8, 8, 1],
				[4, 6, 1, 1],
				[3, 7, 1, 1],
				[1, 8, 2, 1],
				[3, 9, 1, 1],
				[4, 10, 1, 1]
			]
		},
		alert: {
			pieni: [
				[5, 0, 2, 8],
				[5, 9, 2, 2]
			]
		},
		campana: {
			pieni: [
				[5, 0, 2, 1],
				[3, 1, 6, 1],
				[2, 2, 8, 5],
				[1, 7, 10, 1],
				[0, 8, 12, 1],
				[5, 10, 2, 2]
			]
		},
		occhio: {
			pieni: [
				[4, 3, 4, 1],
				[2, 4, 8, 1],
				[1, 5, 10, 2],
				[2, 7, 8, 1],
				[4, 8, 4, 1]
			],
			buchi: [
				[4, 4, 4, 1],
				[3, 5, 6, 2],
				[4, 7, 4, 1]
			],
			punti: [[5, 5, 2, 2]]
		},
		occhio_chiuso: {
			pieni: [
				[1, 4, 2, 1],
				[9, 4, 2, 1],
				[2, 6, 8, 1],
				[3, 7, 2, 1],
				[7, 7, 2, 1]
			]
		},
		chiave: {
			pieni: [
				[2, 1, 6, 6],
				[5, 7, 2, 4],
				[7, 8, 2, 1],
				[7, 10, 2, 1]
			],
			buchi: [[4, 3, 2, 2]]
		}
	} satisfies Record<string, Forma>;

	export type NomeIcona = keyof typeof ICONE;
</script>

<script lang="ts">
	interface Props {
		nome: NomeIcona;
		dimensione?: number;
		colore?: string;
		sfondo?: string;
	}

	let { nome, dimensione = 20, colore = 'currentColor', sfondo = 'transparent' }: Props = $props();

	const forma = $derived(ICONE[nome] as Forma);
</script>

<svg
	width={dimensione}
	height={dimensione}
	viewBox="0 0 12 12"
	shape-rendering="crispEdges"
	aria-hidden="true"
	focusable="false"
>
	{#each forma.pieni as [x, y, w, h] (`${x}-${y}-${w}-${h}`)}
		<rect {x} {y} width={w} height={h} fill={colore} />
	{/each}
	{#each forma.buchi ?? [] as [x, y, w, h] (`b${x}-${y}-${w}-${h}`)}
		<rect {x} {y} width={w} height={h} fill={sfondo} />
	{/each}
	{#each forma.punti ?? [] as [x, y, w, h] (`p${x}-${y}-${w}-${h}`)}
		<rect {x} {y} width={w} height={h} fill={colore} />
	{/each}
</svg>
