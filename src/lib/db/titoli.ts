import { supabase } from '$lib/supabase';
import { conCache } from '$lib/db/cache';

/**
 * I titoli contesi.
 *
 * Uno solo per titolo, sempre a chi e' in testa adesso. Si perdono, ed e'
 * tutto il punto: una medaglia la prendi il terzo giorno e da li' in poi e'
 * arredamento, un titolo che qualcuno ti puo' soffiare resta vivo fino
 * all'ultimo giorno.
 *
 * Il calcolo sta tutto in v_titoli, che non ha una tabella dietro: si
 * ricalcola a ogni lettura da cio' che e' gia' successo.
 */
export type Titolo =
	| 'ghiottona'
	| 'birdwatcher'
	| 'camminatrice'
	| 'scopritrice'
	| 'businessperson'
	| 'piaciona';

export interface VoceTitolo {
	titolo: Titolo;
	user_id: string;
	conteggio: number;
}

/**
 * L'anagrafica sta qui e non nel database perche' e' presentazione: cambiare
 * un nome non deve voler dire una migrazione.
 */
export const TITOLI: {
	titolo: Titolo;
	nome: string;
	come: string;
	unita: (n: number) => string;
}[] = [
	{
		titolo: 'ghiottona',
		nome: 'La ghiottona',
		come: 'più pietanze diverse',
		unita: (n) => (n === 1 ? '1 pietanza' : `${n} pietanze`)
	},
	{
		titolo: 'birdwatcher',
		nome: 'La birdwatcher',
		come: 'più animali diversi',
		unita: (n) => (n === 1 ? '1 animale' : `${n} animali`)
	},
	{
		titolo: 'camminatrice',
		nome: 'La camminatrice',
		come: 'più posti diversi',
		unita: (n) => (n === 1 ? '1 posto' : `${n} posti`)
	},
	{
		titolo: 'scopritrice',
		nome: 'La scopritrice',
		come: 'più primati del gruppo',
		unita: (n) => (n === 1 ? '1 primato' : `${n} primati`)
	},
	{
		titolo: 'businessperson',
		nome: 'La businessperson',
		come: 'più Croquembouche usciti dalle sue tasche',
		unita: (n) => `${n} ✦`
	},
	{
		titolo: 'piaciona',
		nome: 'La piaciona',
		come: 'più like ricevuti',
		unita: (n) => (n === 1 ? '1 like' : `${n} like`)
	}
];

export async function caricaTitoli(): Promise<VoceTitolo[]> {
	return conCache('titoli', async () => {
		const { data, error } = await supabase.from('v_titoli').select('*');
		if (error) throw error;
		return (data ?? []) as VoceTitolo[];
	});
}
