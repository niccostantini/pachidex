-- ============================================================================
-- Pachino Express — seed
-- Solo i giocatori e la configurazione. Nessun elemento di gioco: quelli
-- arrivano dal CSV caricato dal pannello admin.
-- ============================================================================

insert into users (nome, colore, is_admin) values
	('Nicco',        '#F0552B', true),
	('NickDeVita',   '#2B5ED0', false),
	('Aliona',       '#35B79A', false),
	('BF',           '#8B5CF6', false),
	('MirkoTheBest', '#D93B32', false),
	('Gu',           '#C98A18', false)
on conflict (nome) do nothing;

insert into game_config (chiave, valore, descrizione) values
	('costo_apertura_contestazione', 1,   'Croquembouche che paga chi apre una contestazione, comunque vada'),
	('penalita_extra_contestazione', 15,  'Croquembouche in piu'' persi da chi perde la contestazione'),
	('croq_comune',                  10,  'Valore di default per gli elementi comuni'),
	('croq_raro',                    25,  'Valore di default per gli elementi rari'),
	('croq_leggendario',             60,  'Valore di default per gli elementi leggendari'),
	('raggio_gps_metri',             100, 'Distanza massima per validare un checkpoint via GPS'),
	('durata_contestazione_ore',     24,  'Ore di validita'' di una contestazione prima che scada')
on conflict (chiave) do nothing;
