import { CROQ_DEFAULT } from './rules';
import { esisteRiferimento } from '$lib/riferimenti';
import type { Categoria, Rarita, Validazione } from '$lib/types';

export const COLONNE_CSV = [
	'nome',
	'categoria',
	'rarita',
	'croquembouche',
	'ripetibile',
	'validazione',
	'note',
	'lat',
	'lng',
	'riferimento'
] as const;

export interface RigaItem {
	nome: string;
	categoria: Categoria;
	rarita: Rarita;
	croquembouche: number;
	ripetibile: boolean;
	validazione: Validazione;
	note: string | null;
	lat: number | null;
	lng: number | null;
	riferimento: string | null;
}

export interface EsitoRiga {
	numero: number; // numero di riga nel file, com'e' in Excel
	dati?: RigaItem;
	errori: string[];
	/**
	 * Cose storte che non giustificano lo scarto della riga. Un riferimento
	 * che non trova la sua immagine e' un elemento senza foto, non un
	 * elemento rotto: entra lo stesso e l'avviso lo dice.
	 */
	avvisi: string[];
}

export interface EsitoImport {
	valide: EsitoRiga[];
	invalide: EsitoRiga[];
	intestazioniMancanti: string[];
}

/**
 * Parser CSV: virgolette, ritorni a capo dentro le celle, CRLF.
 * Riconosce da solo il separatore, perche' Excel italiano esporta con il
 * punto e virgola e nessuno se lo ricorda mai.
 */
export function parseCSV(testo: string): string[][] {
	const pulito = testo.replace(/^\uFEFF/, '');
	const primaRiga = pulito.split(/\r?\n/)[0] ?? '';
	const sep =
		(primaRiga.match(/;/g)?.length ?? 0) > (primaRiga.match(/,/g)?.length ?? 0) ? ';' : ',';

	const righe: string[][] = [];
	let campo = '';
	let riga: string[] = [];
	let traVirgolette = false;

	for (let i = 0; i < pulito.length; i++) {
		const c = pulito[i];
		if (traVirgolette) {
			if (c === '"') {
				if (pulito[i + 1] === '"') {
					campo += '"';
					i++;
				} else traVirgolette = false;
			} else campo += c;
			continue;
		}
		if (c === '"') traVirgolette = true;
		else if (c === sep) {
			riga.push(campo);
			campo = '';
		} else if (c === '\n') {
			riga.push(campo);
			righe.push(riga);
			riga = [];
			campo = '';
		} else if (c !== '\r') campo += c;
	}
	if (campo !== '' || riga.length) {
		riga.push(campo);
		righe.push(riga);
	}
	return righe.filter((r) => r.some((v) => v.trim() !== ''));
}

const normalizza = (s: string) =>
	s
		.trim()
		.toLowerCase()
		.normalize('NFD')
		.replace(/[\u0300-\u036f]/g, '');

const VERO = new Set(['si', 'sì', 'true', '1', 'x', 'vero', 'yes', 'y']);
const FALSO = new Set(['', 'no', 'false', '0', 'falso', 'n']);

function numero(v: string): number | null {
	const t = v.trim().replace(',', '.');
	if (t === '') return null;
	const n = Number(t);
	return Number.isFinite(n) ? n : null;
}

/**
 * Valida riga per riga senza mai fermarsi: le righe buone entrano lo stesso,
 * quelle rotte tornano indietro con il motivo scritto in chiaro.
 */
export function validaCSV(testo: string): EsitoImport {
	const righe = parseCSV(testo);
	if (!righe.length) {
		return { valide: [], invalide: [], intestazioniMancanti: [...COLONNE_CSV] };
	}

	const intestazioni = righe[0].map(normalizza);
	const indice = (nome: string) => intestazioni.indexOf(nome);
	const obbligatorie = ['nome', 'categoria', 'rarita'];
	const intestazioniMancanti = obbligatorie.filter((c) => indice(c) === -1);
	if (intestazioniMancanti.length) {
		return { valide: [], invalide: [], intestazioniMancanti };
	}

	const valide: EsitoRiga[] = [];
	const invalide: EsitoRiga[] = [];
	const nomiVisti = new Set<string>();

	for (let r = 1; r < righe.length; r++) {
		const cella = (nome: string) => {
			const i = indice(nome);
			return i === -1 ? '' : (righe[r][i] ?? '').trim();
		};
		const errori: string[] = [];
		const avvisi: string[] = [];

		const nome = cella('nome');
		if (!nome) errori.push('nome mancante');

		const categoria = normalizza(cella('categoria'));
		if (!['posto', 'pietanza', 'animale', 'attivita'].includes(categoria)) {
			errori.push(`categoria "${cella('categoria')}" non valida`);
		}

		const rarita = normalizza(cella('rarita'));
		if (!['comune', 'raro', 'leggendario'].includes(rarita)) {
			errori.push(`rarita "${cella('rarita')}" non valida`);
		}

		const croqGrezzo = cella('croquembouche');
		let croquembouche = numero(croqGrezzo);
		if (croqGrezzo === '') {
			croquembouche = CROQ_DEFAULT[rarita as Rarita] ?? null;
		} else if (croquembouche === null || croquembouche < 0) {
			errori.push(`croquembouche "${croqGrezzo}" non e' un numero valido`);
		}

		const ripGrezzo = normalizza(cella('ripetibile'));
		if (!VERO.has(ripGrezzo) && !FALSO.has(ripGrezzo)) {
			errori.push(`ripetibile "${cella('ripetibile')}" non e' si/no`);
		}
		const ripetibile = VERO.has(ripGrezzo);

		const lat = numero(cella('lat'));
		const lng = numero(cella('lng'));
		if (cella('lat') !== '' && lat === null) errori.push('lat non e un numero');
		if (cella('lng') !== '' && lng === null) errori.push('lng non e un numero');
		if (lat !== null && (lat < -90 || lat > 90)) errori.push('lat fuori scala');
		if (lng !== null && (lng < -180 || lng > 180)) errori.push('lng fuori scala');

		// Se non specificata, la validazione si deduce: un posto con coordinate
		// si prende col GPS, tutto il resto per foto.
		let validazione = normalizza(cella('validazione')).replace(/[\s-]/g, '_') as Validazione;
		if (!validazione) {
			validazione = categoria === 'posto' && lat !== null && lng !== null ? 'foto_gps' : 'foto';
		}
		if (!['foto_gps', 'foto'].includes(validazione)) {
			errori.push(`validazione "${cella('validazione')}" non valida`);
		}
		if (validazione === 'foto_gps' && categoria !== 'posto') {
			errori.push('foto_gps vale solo per la categoria posto');
		}
		if (validazione === 'foto_gps' && (lat === null || lng === null)) {
			errori.push('un checkpoint foto_gps ha bisogno di lat e lng');
		}

		// Il riferimento punta a un file nel repo: se non c'e', si segnala
		// senza bocciare la riga.
		const riferimento = cella('riferimento').trim().toLowerCase() || null;
		if (riferimento && !esisteRiferimento(riferimento)) {
			avvisi.push(`nessuna immagine chiamata "${riferimento}" in src/assets/riferimenti`);
		}

		const chiave = `${normalizza(nome)}|${categoria}`;
		if (nome && nomiVisti.has(chiave)) errori.push('nome ripetuto nel file');
		nomiVisti.add(chiave);

		const esito: EsitoRiga = { numero: r + 1, errori, avvisi };
		if (!errori.length) {
			esito.dati = {
				nome,
				categoria: categoria as Categoria,
				rarita: rarita as Rarita,
				croquembouche: croquembouche as number,
				ripetibile,
				validazione,
				note: cella('note') || null,
				lat,
				lng,
				riferimento
			};
			valide.push(esito);
		} else {
			invalide.push(esito);
		}
	}

	return { valide, invalide, intestazioniMancanti: [] };
}

/** Template vuoto, con due righe d'esempio per far capire il formato. */
export function templateCSV(): string {
	return [
		COLONNE_CSV.join(','),
		'Isola di Vendicari,posto,raro,25,no,foto_gps,Portati le scarpe chiuse,36.8106,15.1042,',
		'Granita alla mandorla,pietanza,comune,10,si,foto,Vale ogni volta,,,',
		'Folaga,animale,raro,25,no,foto,Nera col becco bianco,,,folaga'
	].join('\n');
}

export function scaricaTemplate() {
	const blob = new Blob([templateCSV()], { type: 'text/csv;charset=utf-8' });
	const url = URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = 'pachidex-template.csv';
	a.click();
	setTimeout(() => URL.revokeObjectURL(url), 1000);
}
