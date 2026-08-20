/**
 * Gli avatar sono cablati nel codice, non caricati dal pannello: sono sei
 * ritratti pixel disegnati una volta sola per sei amici che non cambiano.
 * Un caricamento da interfaccia sarebbe stato piu' flessibile del necessario,
 * e in cambio avrebbe voluto un bucket, dei permessi e una schermata in piu'.
 *
 * Vite li importa come asset: fingerprint, cache lunga e nessuna richiesta a
 * runtime verso Supabase o R2.
 */
import aliona from '../assets/avatars/aliona.png';
import bf from '../assets/avatars/bf.png';
import gu from '../assets/avatars/gu.png';
import mirko from '../assets/avatars/mirko.png';
import niccu from '../assets/avatars/niccu.png';
import nicola from '../assets/avatars/nicola.png';

/** Chiave: il nome del profilo a database, normalizzato. */
const PER_NOME: Record<string, string> = {
	nicco: niccu,
	nickdevita: nicola,
	aliona: aliona,
	bf: bf,
	mirkothebest: mirko,
	gu: gu
};

/**
 * Lo sprite di un giocatore, se ne ha uno.
 * Chi venisse aggiunto dopo dal pannello non ce l'ha, e ricade sulle
 * iniziali colorate: e' il comportamento giusto, non un caso da gestire.
 */
export function avatarDi(nome: string | undefined | null): string | null {
	if (!nome) return null;
	return PER_NOME[nome.trim().toLowerCase()] ?? null;
}
