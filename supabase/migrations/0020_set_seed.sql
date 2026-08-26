-- ============================================================================
-- Pachino Express — i nove set di partenza
--
-- Idempotente: ogni set entra solo se non c'e' gia' uno con quel nome, cosi'
-- rilanciare la migrazione non li duplica.
--
-- "Colazione siciliana completa" non c'e': nel Dex la granita con brioche e'
-- un elemento solo, quindi il set si sarebbe chiuso con una foto sola.
-- ============================================================================

-- La cassata serviva a "Il dolce siciliano" e nel Dex non c'era.
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, attivo)
select 'Cassata siciliana', 'pietanza', 'comune', 10, false, 'foto',
       'Ricotta, pan di Spagna e una quantità di zucchero che non si discute.', true
where not exists (select 1 from items where nome ilike '%cassat%');

-- 1. Le cinque Vendicari
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, ordine)
	select 'Le cinque Vendicari',
	       'La riserva per intero: le quattro spiagge più la tonnara.', 60, 15, 1
	where not exists (select 1 from game_sets where nome = 'Le cinque Vendicari')
	returning id
)
insert into set_requisiti (set_id, tipo, valore, etichetta, ordine)
select n.id, 'parola', v.valore, v.etichetta, v.ord
from nuovo n, (values
	('calamosche', 'Spiaggia di Calamosche', 1),
	('eloro', 'Spiaggia di Eloro', 2),
	('marianelli', 'Spiaggia di Marianelli', 3),
	('cittadella', 'Spiaggia di Cittadella', 4),
	('tonnara di vendicari', 'Antica Tonnara di Vendicari', 5)
) as v(valore, etichetta, ord);

-- 2. Il giro delle spiagge
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, ordine)
	select 'Il giro delle spiagge',
	       'Tutte le spiagge del PachiDex. Se ne aggiungono altre, il set cresce da solo.',
	       40, 10, 2
	where not exists (select 1 from game_sets where nome = 'Il giro delle spiagge')
	returning id
)
insert into set_requisiti (set_id, tipo, valore, etichetta, ordine)
select n.id, 'tutte_parola', 'spiaggia', 'Tutte le spiagge', 1 from nuovo n;

-- 3. Il barocco
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, ordine)
	select 'Il barocco',
	       'Una sfiziosità per città: Noto, Modica, Scicli, Ragusa. Vale qualsiasi cosa le nomini — un palazzo, un dolce, una degustazione.',
	       50, 12, 3
	where not exists (select 1 from game_sets where nome = 'Il barocco')
	returning id
)
insert into set_requisiti (set_id, tipo, valore, etichetta, ordine)
select n.id, 'parola', v.valore, v.etichetta, v.ord
from nuovo n, (values
	('noto', 'Qualcosa di Noto', 1),
	('modica', 'Qualcosa di Modica', 2),
	('scicli', 'Qualcosa di Scicli', 3),
	('ragusa', 'Qualcosa di Ragusa', 4)
) as v(valore, etichetta, ord);

-- 4. Il dolce siciliano
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, ordine)
	select 'Il dolce siciliano', 'Cannolo, granita, cassata. Il minimo sindacale.', 30, 8, 4
	where not exists (select 1 from game_sets where nome = 'Il dolce siciliano')
	returning id
)
insert into set_requisiti (set_id, tipo, valore, etichetta, ordine)
select n.id, 'parola', v.valore, v.etichetta, v.ord
from nuovo n, (values
	('cannolo', 'Cannolo', 1),
	('granita', 'Granita', 2),
	('cassata', 'Cassata', 3)
) as v(valore, etichetta, ord);

-- 5. I trampolieri
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, ordine)
	select 'I trampolieri', 'I tre dalle gambe lunghe dei pantani.', 40, 10, 5
	where not exists (select 1 from game_sets where nome = 'I trampolieri')
	returning id
)
insert into set_requisiti (set_id, tipo, valore, etichetta, ordine)
select n.id, 'parola', v.valore, v.etichetta, v.ord
from nuovo n, (values
	('airone', 'Airone cenerino', 1),
	('garzetta', 'Garzetta', 2),
	('cavaliere', 'Cavaliere d''Italia', 3)
) as v(valore, etichetta, ord);

-- 6. Gli acquatici
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, ordine)
	select 'Gli acquatici', 'Quelli che stanno a mollo e sembrano sempre indaffarati.', 40, 10, 6
	where not exists (select 1 from game_sets where nome = 'Gli acquatici')
	returning id
)
insert into set_requisiti (set_id, tipo, valore, etichetta, ordine)
select n.id, 'parola', v.valore, v.etichetta, v.ord
from nuovo n, (values
	('folaga', 'Folaga', 1),
	('tuffetto', 'Tuffetto', 2),
	('germano', 'Germano reale', 3)
) as v(valore, etichetta, ord);

-- 7. Il primo giorno — solo il 28
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, giorno, ordine)
	select 'Il primo giorno',
	       'Il selfie inaugurale, una pietanza e un posto. Tutto il 28: o quel giorno, o mai più.',
	       35, 8, date '2026-08-28', 7
	where not exists (select 1 from game_sets where nome = 'Il primo giorno')
	returning id
)
insert into set_requisiti (set_id, tipo, valore, etichetta, ordine)
select n.id, v.tipo, v.valore, v.etichetta, v.ord
from nuovo n, (values
	('parola', 'inaugurale', 'Il selfie inaugurale', 1),
	('categoria', 'pietanza', 'Una pietanza qualsiasi', 2),
	('categoria', 'posto', 'Un posto qualsiasi', 3)
) as v(tipo, valore, etichetta, ord);

-- 8. L'alba e il tramonto — nello stesso giorno
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, stesso_giorno, ordine)
	select 'L''alba e il tramonto',
	       'Una cattura prima delle 8 e una fra le 19 e le 21, nella stessa giornata. Serve alzarsi.',
	       35, 8, true, 8
	where not exists (select 1 from game_sets where nome = 'L''alba e il tramonto')
	returning id
)
insert into set_requisiti (set_id, tipo, ora_da, ora_a, etichetta, ordine)
select n.id, 'orario', v.da, v.a, v.etichetta, v.ord
from nuovo n, (values
	(0, 8, 'Una cattura prima delle 8', 1),
	(19, 21, 'Una cattura fra le 19 e le 21', 2)
) as v(da, a, etichetta, ord);

-- 9. Tutti e sei
with nuovo as (
	insert into game_sets (nome, descrizione, croquembouche, punti_storia, ordine)
	select 'Tutti e sei',
	       'Una cattura sola con dentro tutto il gruppo: chi scatta e gli altri cinque taggati. Vale per tutti quelli che ci sono dentro.',
	       50, 12, 9
	where not exists (select 1 from game_sets where nome = 'Tutti e sei')
	returning id
)
insert into set_requisiti (set_id, tipo, etichetta, ordine)
select n.id, 'tutti_taggati', 'Una foto con tutto il gruppo', 1 from nuovo n;
