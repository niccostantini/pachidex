export type Categoria = 'posto' | 'pietanza' | 'animale' | 'attivita';
export type Rarita = 'comune' | 'raro' | 'leggendario';
export type Validazione = 'foto_gps' | 'foto';
export type StatoCattura = 'valido' | 'in_contestazione' | 'invalidato';
export type StatoContestazione = 'aperta' | 'chiusa_valido' | 'chiusa_non_valido' | 'scaduta';
export type Voto = 'valido' | 'non_valido';

export interface User {
	id: string;
	nome: string;
	avatar: string | null;
	colore: string;
	is_admin: boolean;
	created_at: string;
}

export interface Item {
	id: string;
	nome: string;
	categoria: Categoria;
	rarita: Rarita;
	croquembouche: number;
	ripetibile: boolean;
	validazione: Validazione;
	note: string | null;
	lat: number | null;
	lng: number | null;
	/** Nome del file in src/assets/riferimenti/, non un URL. */
	riferimento: string | null;
	attivo: boolean;
	created_at: string;
}

export interface Capture {
	id: string;
	user_id: string;
	item_id: string;
	foto_url: string;
	nota: string | null;
	lat: number | null;
	lng: number | null;
	timestamp: string;
	stato: StatoCattura;
}

export interface Contest {
	id: string;
	capture_id: string;
	contestante_id: string;
	stato: StatoContestazione;
	costo_pagato: number;
	penalita: number;
	motivo: string | null;
	scadenza: string;
	risolta_at: string | null;
	created_at: string;
}

export interface Vote {
	id: string;
	contest_id: string;
	user_id: string;
	voto: Voto;
	created_at: string;
}

export interface CaptureTag {
	id: string;
	capture_id: string;
	user_id: string;
	created_at: string;
}

export interface Reaction {
	id: string;
	capture_id: string;
	user_id: string;
	created_at: string;
}

export interface Transfer {
	id: string;
	from_user_id: string;
	to_user_id: string;
	importo: number;
	causale: string | null;
	annullato: boolean;
	created_at: string;
}

export interface Saldo {
	user_id: string;
	nome: string;
	guadagnati: number;
	spesi_in_contestazioni: number;
	penalita: number;
	saldo_scambi: number;
	saldo: number;
}

export interface RigaClassifica extends Saldo {
	item_unici: number;
	catture_totali: number;
}

/** Riga della vista v_dex: l'elemento piu' cio' che il gruppo ne ha fatto. */
export interface VoceDex {
	item_id: string;
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
	prima_foto: string | null;
	primo_scopritore: string | null;
	prima_volta: string | null;
	catture_gruppo: number;
	scopritori: number;
}

/** Cattura arricchita con item e autore, come la mostra il feed. */
export interface PostCattura extends Capture {
	tipo: 'cattura';
	item: Item;
	autore: User;
	likes: number;
	ho_messo_like: boolean;
	/** Chi altro prende i Croquembouche di questa foto. */
	taggati: User[];
	contestazione: Contest | null;
	at: string;
}

export interface PostScambio extends Transfer {
	tipo: 'scambio';
	mittente: User;
	destinatario: User;
	at: string;
}

export interface PostContestazione {
	tipo: 'contestazione';
	id: string;
	contest: Contest;
	cattura: PostCattura;
	contestante: User;
	voti: Vote[];
	at: string;
}

export type PostFeed = PostCattura | PostScambio | PostContestazione;
