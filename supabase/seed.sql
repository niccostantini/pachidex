-- ============================================================================
-- Pachino Express — dati per l'ambiente locale
--
-- GENERATO DA scripts/genera-seed.mjs — non modificarlo a mano, si rifa'.
--
-- Il catalogo e' quello vero, scaricato dall'API di produzione. La vacanza
-- qui sotto e' inventata ma deterministica: stesso seme, stessa partita.
--
-- Le foto puntano a un'icona statica servita dal dev server: cosi' il feed
-- funziona anche senza rete e senza credenziali R2.
-- ============================================================================

-- I giocatori e la configurazione arrivano dalle migrazioni (0004), i set
-- dalla 0020: qui si aggiunge solo il catalogo e cosa e' successo.

-- --- il catalogo ------------------------------------------------------------
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Airone cenerino', 'animale', 'comune', 10, false, 'foto', 'Pattuglia i pantani con l''eleganza di un guardiano medievale. Cercarlo immobile presso l''acqua bassa.', null, null, 'airone_cenerino') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Gabbiano reale', 'animale', 'comune', 10, false, 'foto', 'Cercarlo in spiaggia, sul porto o mentre giudica silenziosamente le vostre scelte alimentari.', null, null, 'gabbiano_reale') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Folaga', 'animale', 'comune', 10, false, 'foto', 'Nei pantani e nei canali. Sembra indaffarata, ma probabilmente sta solo attraversando l''acqua con grande convinzione.', null, null, 'folaga') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Germano reale', 'animale', 'comune', 10, false, 'foto', 'Cercarlo nei pantani e nelle zone d''acqua calma. Il maschio sfoggia colori da pavone con budget contenuto.', null, null, 'germano_reale') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Tuffetto', 'animale', 'comune', 10, false, 'foto', 'Presente negli specchi d''acqua tranquilli. Piccolo, rapido e dotato di una notevole propensione a sparire appena estratta la fotocamera.', null, null, 'tuffetto') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Garzetta', 'animale', 'raro', 25, false, 'foto', 'Cercarla lungo i margini dei pantani e nei bassi fondali. Un airone in versione elegante, compatta e leggermente snob.', null, null, 'garzetta') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cavaliere d''Italia', 'animale', 'raro', 25, false, 'foto', 'Nei pantani salmastri e nelle acque basse. Le zampe sproporzionate aiutano l''identificazione e complicano la dignità del soggetto.', null, null, 'cavaliere_d_italia') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Gruccione', 'animale', 'raro', 25, false, 'foto', 'Cercarlo nelle aree aperte e vicino alla macchia mediterranea. Coloratissimo, velocissimo e probabilmente consapevole di essere fotogenico.', null, null, 'gruccione') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Volpoca', 'animale', 'raro', 25, false, 'foto', 'Da cercare nei pantani e nelle lagune costiere. Un''anatra con l''aria di chi possiede già una casa al mare.', null, null, 'volpoca') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fenicottero rosa', 'animale', 'leggendario', 60, false, 'foto', 'Cercarlo nei pantani, soprattutto durante i periodi migratori. Se compare, il gruppo deve interrompere qualunque discussione e fotografare.', null, null, 'fenicottero_rosa') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Spatola', 'animale', 'leggendario', 60, false, 'foto', 'Nei pantani e nelle zone umide. Il becco a cucchiaio suggerisce abitudini alimentari raffinate e una certa arroganza posata.', null, null, 'spatola') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Tarabusino', 'animale', 'leggendario', 60, false, 'foto', 'Cercarlo tra canneti e vegetazione dei pantani. Piccolo, mimetico e specializzato nel non collaborare con il PachiDex.', null, null, 'tarabusino') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Occhione', 'animale', 'leggendario', 60, false, 'foto', 'Da cercare nelle dune e negli ambienti aperti, preferibilmente con pazienza e vista da rapace.', null, null, 'occhione') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Caretta caretta', 'animale', 'leggendario', 60, false, 'foto', 'Avvistabile in mare o presso le spiagge di nidificazione. Solo osservazione autorizzata: la tartaruga non è disponibile per il trasporto.', null, null, 'caretta_caretta') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Granchio fantasma', 'animale', 'raro', 25, false, 'foto', 'Cercarlo sulle spiagge sabbiose, soprattutto vicino alle tane. Corre lateralmente come se avesse un appuntamento molto importante.', null, null, 'granchio_fantasma') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Polpo', 'animale', 'raro', 25, false, 'foto', 'Da cercare tra scogli e fondali bassi, idealmente con maschera e boccaglio. Se vi guarda, probabilmente ha già valutato male la vostra mimetizzazione.', null, null, 'polpo') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Seppia', 'animale', 'raro', 25, false, 'foto', 'Cercarla nei fondali bassi e nelle zone rocciose. Può cambiare colore, strategia e probabilmente opinione sul fotografo.', null, null, 'seppia') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Granchio blu', 'animale', 'raro', 25, false, 'foto', 'Da cercare nelle acque basse e nelle lagune. Ospite alieno, non sempre invitato, con atteggiamento da boss portuale.', null, null, 'granchio_blu') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Biacco', 'animale', 'raro', 25, false, 'foto', 'Cercarlo lungo sentieri, muretti e margini della macchia. Di solito lo vedrete soltanto mentre fugge con largo anticipo.', null, null, 'biacco') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Lucertola', 'animale', 'comune', 10, false, 'foto', 'Praticamente ovunque ci siano pietre assolate. Comune, veloce e disponibile a restare immobile per circa mezzo secondo.', null, null, 'lucertola') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Rospo smeraldino siciliano', 'animale', 'raro', 25, false, 'foto', 'Cercarlo vicino a pozze temporanee, pantani e ambienti umidi. Il colore lo rende riconoscibile, ma non necessariamente intenzionato a collaborare.', null, null, 'rospo_smeraldino_siciliano') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Discoglosso dipinto', 'animale', 'leggendario', 60, false, 'foto', 'Da cercare nelle pozze e negli ambienti umidi dopo periodi favorevoli. Una creatura discreta con un nome che sembra uscito da un catalogo d''arte.', null, null, 'discoglosso_dipinto') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Coniglio selvatico', 'animale', 'raro', 25, false, 'foto', 'Cercarlo all''alba o al tramonto tra macchia e campagne. In caso di avvistamento, evitare movimenti bruschi e battute sulle carote.', null, null, 'coniglio_selvatico') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Volpe', 'animale', 'raro', 25, false, 'foto', 'Più probabile nelle campagne e ai margini della macchia, soprattutto nelle ore tranquille. Potrebbe osservare il gruppo prima che il gruppo osservi lei.', null, null, 'volpe') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Istrice', 'animale', 'leggendario', 60, false, 'foto', 'Cercarlo al crepuscolo o di notte nella macchia. Gli aculei sono un indizio valido, ma non sostituiscono la foto del legittimo proprietario.', null, null, 'istrice') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Upupa', 'animale', 'raro', 25, false, 'foto', 'Cercarla nelle campagne e nelle aree aperte. La cresta la rende inconfondibile, purché non decida di chiuderla proprio al momento dello scatto.', null, null, 'upupa') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Saltimpalo', 'animale', 'comune', 10, false, 'foto', 'Cercarlo su cespugli, recinzioni e pali nelle aree aperte. Ama posarsi in luoghi panoramici come un piccolo sorvegliante del territorio.', null, null, 'saltimpalo') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Torre Cabrera di Pozzallo', 'posto', 'comune', 10, false, 'foto_gps', 'Torre costiera severa e fotogenica, costruita quando la miglior tecnologia disponibile per avvistare problemi era stare molto in alto e guardare il mare.', 36.7284, 14.8461, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Spiaggia di Pietre Nere di Pozzallo', 'posto', 'comune', 10, false, 'foto_gps', 'Litorale urbano dal nome minaccioso e dall''aspetto balneare. La cattura è valida davanti alla spiaggia, non davanti al primo parcheggio con vista laterale.', 36.7274, 14.8518, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Caffè al Ciclope di Pachino', 'posto', 'comune', 10, true, 'foto_gps', 'Il bar più frequentato della vacanza', 36.715516, 15.090983, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Piazza Vittorio Emanuela a Pachino', 'posto', 'comune', 10, false, 'foto_gps', 'La piazza della città meno attraente del ragusano', 36.715195, 15.091362, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Scaccia', 'pietanza', 'comune', 10, true, 'foto', 'Preparazione stratificata in cui l''impasto viene arrotolato, farcito e cotto fino a raggiungere la leggendaria consistenza: croccante fuori, ustionante dentro e impossibile da mangiare senza assumere una posizione tattica.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Impanata siciliana', 'pietanza', 'raro', 25, true, 'foto', 'Una corazza di pasta ripiena che si presenta come prodotto da forno, ma manifesta evidenti caratteristiche da oggetto contundente commestibile.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Macco di fave', 'pietanza', 'raro', 25, false, 'foto', 'Crema ancestrale di legumi dalla consistenza strategica. Si narra che, dopo un piatto di macco, anche il cucchiaio acquisisca una temporanea percezione del destino.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Isola di Capo Passero', 'posto', 'leggendario', 60, false, 'foto_gps', 'Isola, mare aperto e ruderi militari: combinazione ufficialmente classificata come avventura. La cattura richiede di raggiungere davvero il punto panoramico corretto.', 36.684767, 15.144249, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Castello Maniace di Siracusa', 'posto', 'leggendario', 60, false, 'foto_gps', 'Fortezza sulla punta di Ortigia, posizionata in modo da ricordare a tutti che il panorama bello è spesso difeso da mura molto spesse.', 37.053693, 15.295145, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Necropoli di Pantalica', 'posto', 'leggendario', 60, false, 'foto_gps', 'Centinaia di tombe scavate nella roccia e un paesaggio da spedizione archeologica. Location da boss finale, possibilmente affrontata con scarpe adeguate.', 37.141384, 15.029993, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Basilica di San Giovanni Battista a Ragusa', 'posto', 'comune', 10, false, 'foto_gps', 'Chiesa monumentale di Ragusa Superiore, ideale per ricordare alla squadra che il barocco non ha mai incontrato una facciata che considerasse sufficientemente decorata.', 36.925822265066, 14.728807031752, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Giardini Iblei di Ragusa', 'posto', 'raro', 25, false, 'foto_gps', 'Spazio verde affacciato sul paesaggio ibleo, dove il gruppo può respirare, ammirare il panorama e fingere per qualche minuto di non avere una lista di catture da completare.', 36.9262383000877, 14.7482200654181, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Castello dei Conti di Modica', 'posto', 'leggendario', 60, false, 'foto_gps', 'Rocca, prigione, rovina e scenario da missione principale. La cattura è valida solo davanti alla pietra giusta, non davanti a una casa che le assomiglia vagamente.', 36.8620730403627, 14.7616414580042, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Duomo di San Giorgio di Modica', 'posto', 'leggendario', 60, false, 'foto_gps', 'Una cattedrale costruita in salita, perché evidentemente anche la religione doveva mettere alla prova i polpacci del visitatore.', 36.8640645025833, 14.7614200843277, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Chiesa rupestre di Santa Maria della Catena', 'posto', 'leggendario', 60, false, 'foto_gps', 'Luogo scavato nella roccia e nel tempo, con atmosfera da dungeon storico. La cattura richiede rispetto, attenzione e una torcia usata responsabilmente.', 36.7930007031306, 14.7083875155558, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Palazzo Beneventano di Scicli', 'posto', 'comune', 10, false, 'foto_gps', 'Edificio barocco dotato di decorazioni e mascheroni con l''espressione di chi ha appena scoperto che il gruppo non ha prenotato il ristorante.', 36.7932172246429, 14.7074855517256, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Antica Tonnara di Marzamemi', 'posto', 'comune', 10, false, 'foto_gps', 'Luogo in cui il tonno, la pesca e l''architettura hanno collaborato per secoli. La cattura è accessibile, ma il soggetto conserva un''innegabile autorità marina.', 36.7415436640606, 15.1188724741026, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Torre Sveva di Vendicari', 'posto', 'raro', 25, false, 'foto_gps', 'Torre costiera affacciata sulla riserva, costruita per osservare il mare e segnalare pericoli con la velocità tipica delle comunicazioni precedenti all''invenzione del telefono.', 36.8025231207393, 15.0994888979477, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Antica Tonnara di Vendicari', 'posto', 'raro', 25, false, 'foto_gps', 'Resti di una tonnara immersi tra mare, palude e vegetazione. La squadra raggiunge un luogo in cui il tonno ha avuto per secoli più importanza logistica di molti esseri umani.', 36.8030739893967, 15.0991522768773, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Capanno di osservazione del Pantano Roveto', 'posto', 'raro', 25, false, 'foto_gps', 'Punto panoramico per osservare la fauna della riserva. Il giocatore deve rimanere abbastanza fermo da sembrare parte dell''arredamento.', 36.7813246814611, 15.087622169111, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Antica Porta Reale di Noto', 'posto', 'comune', 10, false, 'foto_gps', 'Ingresso monumentale alla città barocca. Attraversarlo non garantisce bonus, ma conferisce al giocatore un temporaneo atteggiamento da nobile del Settecento.', 36.8902330880826, 15.0738363114449, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cattedrale di San Nicolò di Noto', 'posto', 'comune', 10, false, 'foto_gps', 'Facciata barocca di tale autorevolezza da far sembrare ogni fotografia automaticamente più importante di quanto sia realmente.', 36.8915909624371, 15.0707034826093, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Piazza Umberto I di Avola', 'posto', 'comune', 10, false, 'foto_gps', 'La piazza principale di Avola', 36.9099242710344, 15.1348707925835, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cudduruni', 'pietanza', 'raro', 25, false, 'foto', 'Parente rustico della scaccia, specializzato nel confondere il giocatore: sembra semplice, poi rivela strati, ripieno e una dignità gastronomica fuori scala.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Spiaggia di Calamosche', 'posto', 'raro', 25, false, 'foto_gps', 'Spiaggia incastonata tra pareti rocciose, raggiungibile dopo una camminata che il gruppo descriverà come facile soltanto dopo averla completata.', 36.8008, 15.0957, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Lolli con le fave', 'pietanza', 'leggendario', 60, false, 'foto', 'Pasta fresca e legumi in un incontro di enorme rilevanza storica. Catturarlo richiede coraggio, fame e la disponibilità ad accettare che il pranzo sia ormai diventato una missione principale.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pasta alla norma', 'pietanza', 'comune', 10, true, 'foto', 'Piatto apparentemente ordinario che combina morbidezza, sugo e formaggio con la precisione di una squadra Pokémon ben allenata.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pasta con le sarde', 'pietanza', 'raro', 25, false, 'foto', 'Preparazione marinaresca e aromatica che può essere consumata solo dopo aver accettato il principio secondo cui il pesce può tranquillamente convivere con ingredienti insospettabili.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Arancina', 'pietanza', 'comune', 10, true, 'foto', 'Sfera fritta ad alta densità morale. Il suo guscio dorato induce il giocatore a credere di poter mangiare una sola arancina, errore strategico quasi sempre fatale.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Panelle in panino', 'pietanza', 'comune', 10, true, 'foto', 'Panino dalla semplicità ingannevole: pochi elementi, massimo potere di sazietà e una probabilità elevata di lasciare tracce di fritto sulle mani per il resto della giornata.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pasta fritta siciliana', 'pietanza', 'comune', 10, true, 'foto', 'Avanzi trasformati in evento gastronomico. La sua cattura dimostra che nella cucina siciliana anche ciò che sembrava destinato alla dimenticanza può ottenere un''importante evoluzione.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Granita con brioche', 'pietanza', 'comune', 10, true, 'foto', 'Colazione, dessert e prova di coordinazione motoria riuniti in un''unica creatura. La brioche funge da supporto ufficiale, ma nessuno ha davvero capito tutte le regole del combattimento.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cannolo', 'pietanza', 'comune', 10, true, 'foto', 'Dolce di rara potenza, dotato di guscio croccante e ripieno strategico. Va catturato prima che la crema inizi a compromettere l''integrità strutturale dell''oggetto.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Rotolo', 'pietanza', 'leggendario', 60, false, 'foto', 'Puoi catturarlo, ma non potrai mai finirlo in una botta sola.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cioccolato di Modica', 'pietanza', 'comune', 10, false, 'foto', 'Tavoletta lavorata secondo una tecnica che lascia lo zucchero parzialmente riconoscibile. Non è un semplice dolce: è una dimostrazione geologica commestibile con denominazione e carattere propri.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('''Mpanatigghi modicani', 'pietanza', 'leggendario', 60, false, 'foto', 'Dolce ripieno di carne e cacao, nato per confondere i confini tra portata principale e dessert. Il giocatore che lo cattura ottiene il diritto di non fidarsi più dei menu apparentemente innocenti.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Paste di mandorla avolesi', 'pietanza', 'raro', 25, false, 'foto', 'Piccoli manufatti dolci dalla consistenza imprevedibile: morbidi, profumati e progettati per sparire dal vassoio prima che il giocatore possa completare la cattura.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Nucatoli netini', 'pietanza', 'raro', 25, false, 'foto', 'Biscotti ripieni e speziati che sembrano piccoli documenti d''archivio. Ogni morso conserva tracce di miele, frutta secca e antiche decisioni familiari sulla merenda.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cavàti sciclitani al sugo di maiale', 'pietanza', 'comune', 10, false, 'foto', 'Pasta fresca dalla forma irregolare, addestrata a trattenere il sugo con efficienza militare. Una cattura comune, ma con un potere saziante sorprendentemente elevato.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Teste di turco di Scicli', 'pietanza', 'leggendario', 60, false, 'foto', 'Dolce monumentale e ripieno che prende il nome da una battaglia. Il PachiDex lo classifica come creatura dolciaria da affrontare con rispetto e tovaglioli adeguati.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pasta alla matalotta siracusana', 'pietanza', 'comune', 10, false, 'foto', 'Pasta con brodo di pesce, nata dal nobile principio di non sprecare nulla. Un piatto umile che entra in campo con l''autorevolezza di un antico capitano di mare.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pasta con la salsa moresca', 'pietanza', 'leggendario', 60, false, 'foto', 'Pasta con bottarga e cannella: accostamento talmente inatteso da sembrare il risultato di un esperimento condotto durante una notte senza supervisione adulta.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cozze gratinate alla siracusana', 'pietanza', 'comune', 10, false, 'foto', 'Molluschi ricoperti e gratinati fino a diventare piccole corazze marine. La cattura è accessibile, ma il rischio di mangiarne troppe è considerato strutturalmente inevitabile.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Zuppa di pesce alla siracusana', 'pietanza', 'raro', 25, false, 'foto', 'Preparazione marinaresca in cui il brodo assume il controllo della situazione e ogni pesce aggiunge un nuovo capitolo alla saga della cena.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Tonno alla ghiotta di Marzamemi', 'pietanza', 'raro', 25, false, 'foto', 'Il tonno viene cucinato in una preparazione ricca e autorevole, come se la tonnara avesse deciso di concludere la giornata con un banchetto ufficiale.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Buzzonaglia di tonno con cipolla in agrodolce', 'pietanza', 'raro', 25, false, 'foto', 'Preparazione dal carattere marino intenso, ottenuta da una parte del tonno che non accetta ruoli secondari. La cipolla agrodolce prova a negoziare, ma il tonno conduce le trattative.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Frittura di paranza di Pozzallo', 'pietanza', 'comune', 10, false, 'foto', 'Piccolo esercito di pesci fritti, catturabile in gruppo e consumabile con la velocità di chi sa che ogni esemplare potrebbe fuggire attraverso una goccia di limone.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Ravioli di pesce alla maniera di Pozzallo', 'pietanza', 'raro', 25, false, 'foto', 'Pasta ripiena che nasconde il mare dentro un involucro apparentemente pacifico. La cattura richiede fotografia, appetito e un minimo di rispetto per la geometria del ripieno.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pane cunzato', 'pietanza', 'comune', 10, false, 'foto', 'Panino rurale e marinaro che dimostra come una merenda possa acquisire una notevole profondità narrativa se consumata con vista sul porto.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Granita alla mandorla di Avola', 'pietanza', 'raro', 25, false, 'foto', 'Colazione fredda e cremosa, capace di trasformare una mandorla in un evento di tale importanza da richiedere una brioche come testimone ufficiale.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Caponata di pesce', 'pietanza', 'comune', 10, false, 'foto', 'Versione marinara dell''agrodolce siciliano, capace di mettere pesce e ortaggi nella stessa squadra senza convocare un arbitro.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pastieri ragusani', 'pietanza', 'leggendario', 60, false, 'foto', 'Scrigni di pasta ripieni, tradizionalmente legati alla cucina delle feste. Sembrano innocui prodotti da forno, ma custodiscono una quantità di storia sufficiente a richiedere una missione dedicata.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Visitare una tonnara storica', 'attivita', 'raro', 25, false, 'foto', 'Il gruppo entra in un luogo dove per secoli il tonno ha incontrato l''organizzazione umana. Obbligatorio assumere per almeno trenta secondi un''espressione rispettosa e vagamente documentaristica.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Esplorare un borgo barocco', 'attivita', 'comune', 10, false, 'foto', 'Passeggiata tra facciate, balconi e scalinate progettate per dimostrare che anche una strada può avere ambizioni teatrali.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Contare almeno dieci mascheroni barocchi', 'attivita', 'raro', 25, false, 'foto', 'Missione di osservazione architettonica: individuare dieci facce di pietra e stabilire quale sembri giudicare peggio il gruppo.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Assistere a una processione o festa tradizionale', 'attivita', 'raro', 25, false, 'foto', 'Partecipazione rispettosa a una manifestazione della tradizione locale. La cattura non autorizza il gruppo a comportarsi come una troupe televisiva.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Imparare una parola in dialetto siciliano da un abitante', 'attivita', 'raro', 25, false, 'foto', 'Un membro della squadra apprende una parola siciliana e la ripete senza distruggerne completamente pronuncia, significato e dignità.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Farsi spiegare una ricetta tradizionale', 'attivita', 'raro', 25, false, 'foto', 'Un abitante del luogo illustra una ricetta autentica. La squadra ascolta con attenzione e non propone di sostituire ingredienti fondamentali con qualcosa trovato al supermercato.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fare una degustazione di cioccolato di Modica', 'attivita', 'raro', 25, false, 'foto', 'La squadra analizza il cioccolato con rigore quasi scientifico, distinguendo aromi, consistenze e il momento esatto in cui qualcuno chiede il secondo assaggio.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Raggiungere un belvedere degli Iblei', 'attivita', 'raro', 25, false, 'foto', 'Il gruppo conquista un punto panoramico e produce la fotografia ufficiale dell''impresa. È consentito restare senza fiato sia per il paesaggio sia per la salita.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Vedere il tramonto da un borgo sul mare', 'attivita', 'comune', 10, false, 'foto', 'La squadra assiste alla quotidiana dimostrazione di competenza cromatica del sole. Bonus morale se nessuno pronuncia la frase: ''Sembra un filtro''.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Visitare un''antica cava o necropoli', 'attivita', 'leggendario', 60, false, 'foto', 'Esplorazione di un luogo scavato nella pietra e nel tempo come Pantalica. La cattura richiede rispetto, attenzione e almeno un membro della squadra disposto a leggere il pannello informativo.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fare il bagno in una caletta raggiunta a piedi', 'attivita', 'raro', 25, false, 'foto', 'La squadra affronta un sentiero non completamente pianeggiante per ottenere il premio finale: acqua, panorama e la certezza di aver portato troppe cose inutili.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Comprare un souvenir artigianale non alimentare', 'attivita', 'comune', 10, false, 'foto', 'Acquisizione di un oggetto prodotto localmente e non scelto all''ultimo minuto in aeroporto. La cattura è più prestigiosa se il souvenir ha una funzione concreta.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Assistere a uno spettacolo di musica o teatro siciliano', 'attivita', 'raro', 25, false, 'foto', 'La squadra partecipa a un evento culturale e per tutta la durata mantiene un comportamento compatibile con la presenza di altri esseri umani.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Recitare una poesia siciliana in un luogo pubblico', 'attivita', 'leggendario', 60, false, 'foto', 'Performance letteraria di grande rischio sociale. La cattura è valida solo se il gruppo supera la fase iniziale in cui tutti fingono di non conoscersi.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Ordinare una pietanza usando il dialetto', 'attivita', 'raro', 25, false, 'foto', 'Il giocatore tenta di ordinare senza ricorrere all''italiano standard. La cattura è valida sia in caso di successo sia in caso di incomprensione totale, purché la pietanza arrivi davvero.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fare una foto di gruppo senza autoscatto', 'attivita', 'raro', 25, false, 'foto', 'La squadra deve convincere una persona estranea a fotografarla. La missione fallisce se il risultato mostra solo tre persone, un pollice e metà del cielo.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Riuscire a parcheggiare al primo tentativo', 'attivita', 'leggendario', 60, false, 'foto', 'Impresa automobilistica quasi mitologica. La cattura è valida soltanto se il veicolo è effettivamente dentro le righe e nessuno è dovuto scendere per fornire indicazioni manuali.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fare una passeggiata senza parlare di cibo', 'attivita', 'leggendario', 60, false, 'foto', 'La squadra tenta di trascorrere almeno trenta minuti senza nominare colazione, pranzo, cena, gelato, granita o rosticceria. Probabilità di successo: statisticamente trascurabile.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Prendere una multa', 'attivita', 'raro', 25, true, 'foto', 'Dicono che la Sicilia sia la terra di nessuno in cui lo Stato non arriva, ma a te è arrivato eccome.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fare un selfie con le Cicciarelle', 'attivita', 'leggendario', 60, true, 'foto', 'Riuscirai a catturare l’essenza gastronomica di questa vacanza?', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fare un selfie con Seb', 'attivita', 'raro', 25, true, 'foto', 'Ne varrà la pena?', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Giocare con le gemelle', 'attivita', 'raro', 25, true, 'foto', 'Arrivare al cuore dei daddies passando per la prole', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Educazione sessuo-affettiva con Greta', 'attivita', 'leggendario', 60, true, 'foto', 'Facciamole capire che non serve compiacere un uomo di mezza età per avere valore', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Isola delle Correnti', 'posto', 'raro', 25, false, 'foto_gps', 'Punto simbolico d''incontro tra mari e correnti. Il gruppo osserva l''acqua e cerca di capire quale mare stia effettivamente vincendo la discussione.', 36.646414, 15.07829, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Punta dell''Isola Centrale di Marzamemi', 'posto', 'comune', 10, false, 'foto', 'Nulla di speciale, è solo un po'' difficile da raggiungere', 36.733755, 15.123198, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Museo della Mandorla di Avola', 'posto', 'raro', 25, false, 'foto_gps', 'Avola è conosciuta per una cosa, e ovviamente hanno dovuto costruirci un museo attorno', 36.9098901405014, 15.1469721520815, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fonte Aretusa', 'posto', 'raro', 25, false, 'foto_gps', 'La Fonte Aretusa è il celebre stagno di Siracusa dove una ninfa, per sfuggire a un corteggiatore molesto, ha ben pensato di liquefarsi e diventare una pozzanghera popolata da pesci confusi.', 37.0573660678939, 15.2929281965059, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Caponata siciliana', 'pietanza', 'raro', 25, true, 'foto', 'Una complessa alleanza agrodolce tra ortaggi e condimenti, capace di far discutere sei amici per almeno venti minuti su quale sia la versione autentica.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Pesce spada alla messinese', 'pietanza', 'raro', 25, false, 'foto', 'Alcuni lo chiamano alla siciliana. È bono in ogni caso.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Vittoria alla serata giuochi', 'attivita', 'raro', 25, true, 'foto', 'Hai vinto più volte alla serata giuochi. Se sei Nick dovresti ricevere punti anche solo per esserci sopravvissuto, invece ahimé non sono previsti punti.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Fuga per sfiziosità', 'pietanza', 'raro', 25, true, 'foto', 'Sei sparita per andare a cercare il cazzo: ottimo.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Sessione di esercizi', 'attivita', 'comune', 10, true, 'foto', 'Complimenti, stai cercando (vanamente) di contrastare le varie granite e scacce che stai ingollando in questi giorni', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Assistere all''alba sul Mediterraneo', 'attivita', 'raro', 25, false, 'foto', 'Il gruppo si presenta davanti al mare prima che il sole abbia ufficialmente iniziato il proprio turno. Richiesto almeno un tentativo sincero di sembrare persone mattiniere.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Un fan ti riconosce', 'attivita', 'raro', 25, false, 'foto', 'Sì, sei bello e famoso. Smettila di rinfacciarcelo ad ogni passeggiata', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('1ª cosa da fare: selfie inaugurale', 'attivita', 'comune', 5, false, 'foto', 'Inziamo le danze con bel selfie con doppiomento!', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Aeroporto di Catania', 'posto', 'comune', 10, false, 'foto_gps', 'Siete arrivatu: dimostratelo!', 37.4705007407942, 15.0669869174041, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Aeroporto Fiumicino T1', 'posto', 'comune', 5, false, 'foto', 'Selfie prepartenza?', 41.7960650236631, 12.2542915481325, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Spiaggia di Marianelli', 'posto', 'raro', 25, false, 'foto_gps', 'La spiaggia dei ghei, ma in Sicilia e senza pallavolo', 36.833848616288, 15.1057364774049, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Acque palummi', 'posto', 'comune', 10, false, 'foto_gps', 'Molto di pù che una scogliera: incontri fortuiti, coreografie, spiaggine e zattere.', 36.695707, 15.130207, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Costaa dell''Ambra', 'posto', 'comune', 10, false, 'foto_gps', 'La spiaggia più schifata da BF, ma in realtà non è affatto male', 36.690944, 15.036879, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Carratois', 'posto', 'raro', 25, false, 'foto_gps', 'Playa Carratois è il punto in cui la Sicilia ha copiato i Caraibi: sabbia che non si sente, vento che ti spedisce su Marte col kitesurf e tramonti che fanno impallidire le Maldive.', 36.660936, 15.066253, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Bunker di Punta delle Formiche', 'posto', 'comune', 10, false, 'foto_gps', 'Mi serviva solo un riferimento per Punta delle Formiche, non ho idea di questo bunker a cosa sia servito', 36.6609784350407, 15.0554615993567, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Almost Concerie', 'posto', 'raro', 25, false, 'foto_gps', 'Un posto dove andremo sugli scogli. Non si sa perché proprio questo punto ma così dice BF', 36.671195, 15.052563, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Casa Pachino', 'posto', 'comune', 10, false, 'foto_gps', 'La base, gli headquarters, il nido: ahimè non c''è l''aria condizionata.', 36.6928768249281, 15.04655245417, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Spiaggia di Cittadella', 'posto', 'raro', 25, false, 'foto_gps', 'Una delle spiagge della riserva di Vendicari. Comincia a camminare', 36.7762774424293, 15.0951276719664, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Spiaggia di Eloro', 'posto', 'raro', 25, false, 'foto_gps', 'Una delle big three di Vendicari. Ahimè ci passerete pricipalmente per andare a Marianelli', 36.8500971933811, 15.1067584671136, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Cassata siciliana', 'pietanza', 'comune', 10, false, 'foto', 'Ricotta, pan di Spagna e una quantità di zucchero che non si discute.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('La quest di Mirko', 'attivita', 'leggendario', 60, false, 'foto', 'Assistere a MirkoTheBest che fa finalmente l''ordine che non è riuscito a fare l''anno scorso al ristorante "Nakè" di Noto', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Faro di Portopalo', 'posto', 'comune', 10, false, 'foto', 'Il faro vicino alla casa dei daddies. È anche l''unico', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Coreo', 'attivita', 'leggendario', 60, false, 'foto', 'Che vacanza sarebbe senza una coreografia?', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Capre di Rina e Gaetano', 'attivita', 'raro', 25, false, 'foto', 'Sono tutte femmine anche se hanno le corna.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Diarrea!', 'attivita', 'raro', 25, false, 'foto', 'Prima o poi doveva capitare. Siamo curiosi di vedere che foto farai', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Naturismo!', 'attivita', 'leggendario', 60, false, 'foto', 'Lo devo anche spiegare? Attenzione a non inquadrare i genitali!', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Tortora', 'animale', 'comune', 10, false, 'foto', 'Semplicetta tortorella che non vede il suo periglio \ per fuggir al crudo artiglio \ vola in grembo al cacciator', null, null, 'tortora') on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Ghiotta', 'pietanza', 'raro', 25, false, 'foto', 'Descritta da Elisabetta, quella con le lumache di terra pare essere bona in culo.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Febbre!', 'attivita', 'raro', 25, false, 'foto', 'Basta un''ostrica sbagliata. O qualcuno che ti lancia maledizioni.', null, null, null) on conflict do nothing;
insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values ('Avventura secondaria', 'animale', 'raro', 25, false, 'foto', 'Tu o una parte del gruppo decidete di perseguire la vostra quest per conto vostro, lontani dal filone mainstream della vacanza.', null, null, null) on conflict do nothing;

-- --- la vacanza -------------------------------------------------------------
-- 75 catture fra il 28 agosto e il primo settembre.

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @MirkoTheBest',
	       timestamptz '2026-08-28T08:46:25.533Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Fare una degustazione di cioccolato di Modica'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'MirkoTheBest';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T09:11:06.750Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Spiaggia di Eloro'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T10:36:11.556Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Giocare con le gemelle'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T11:38:15.157Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Tortora'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T14:42:35.422Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Tonno alla ghiotta di Marzamemi'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T17:12:36.813Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Spiaggia di Cittadella'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T17:30:35.800Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Upupa'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T18:01:39.049Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Folaga'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T18:18:41.038Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Zuppa di pesce alla siracusana'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T19:46:21.100Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Rotolo'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-28T22:20:58.537Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Airone cenerino'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T07:22:01.706Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Cassata siciliana'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T07:56:13.705Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Caponata di pesce'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T08:26:30.365Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Fare una passeggiata senza parlare di cibo'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T12:00:16.255Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Fare un selfie con Seb'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T12:26:09.334Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Gruccione'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T13:16:58.026Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Garzetta'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T14:11:58.333Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Airone cenerino'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @BF',
	       timestamptz '2026-08-29T14:18:27.888Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Pasta alla norma'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'BF';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T14:19:13.332Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Granchio blu'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Nicco',
	       timestamptz '2026-08-29T15:00:10.321Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Granchio blu'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Nicco';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @BF',
	       timestamptz '2026-08-29T15:02:11.089Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Nucatoli netini'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'BF';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T15:05:01.079Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Aeroporto di Catania'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T16:15:05.368Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Duomo di San Giorgio di Modica'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Aliona',
	       timestamptz '2026-08-29T16:15:19.612Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Caffè al Ciclope di Pachino'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Aliona';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-29T18:01:14.763Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Buzzonaglia di tonno con cipolla in agrodolce'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @MirkoTheBest',
	       timestamptz '2026-08-29T19:25:44.673Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Pasta fritta siciliana'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'MirkoTheBest';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Gu',
	       timestamptz '2026-08-29T19:31:19.275Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Tonno alla ghiotta di Marzamemi'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Gu';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Nicco',
	       timestamptz '2026-08-29T19:35:18.730Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Cioccolato di Modica'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Nicco';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T02:59:20.012Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Rospo smeraldino siciliano'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T03:04:21.951Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Cudduruni'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T03:05:45.636Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Ghiotta'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Nicco',
	       timestamptz '2026-08-30T05:40:37.938Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Febbre!'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Nicco';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T06:25:19.798Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Pasta alla matalotta siracusana'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T06:52:35.101Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Palazzo Beneventano di Scicli'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T08:01:06.348Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Educazione sessuo-affettiva con Greta'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T08:40:34.763Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Spatola'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T09:10:52.347Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Necropoli di Pantalica'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @MirkoTheBest',
	       timestamptz '2026-08-30T09:53:02.039Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Frittura di paranza di Pozzallo'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'MirkoTheBest';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @NickDeVita',
	       timestamptz '2026-08-30T12:26:06.659Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Farsi spiegare una ricetta tradizionale'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'NickDeVita';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @MirkoTheBest',
	       timestamptz '2026-08-30T14:05:41.917Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Granchio blu'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'MirkoTheBest';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T16:14:28.790Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Fuga per sfiziosità'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Aliona',
	       timestamptz '2026-08-30T18:22:38.253Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Cavàti sciclitani al sugo di maiale'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Aliona';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T18:45:28.606Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Cattedrale di San Nicolò di Noto'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T20:23:44.243Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Granchio fantasma'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @NickDeVita',
	       timestamptz '2026-08-30T22:29:19.941Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Assistere a uno spettacolo di musica o teatro siciliano'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'NickDeVita';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-30T22:58:37.579Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Seppia'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Nicco',
	       timestamptz '2026-08-30T23:52:02.789Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Coniglio selvatico'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Nicco';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T01:14:44.537Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Bunker di Punta delle Formiche'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T04:01:41.473Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Torre Sveva di Vendicari'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Nicco',
	       timestamptz '2026-08-31T04:29:03.043Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Arancina'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Nicco';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T04:46:48.967Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Fuga per sfiziosità'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Gu',
	       timestamptz '2026-08-31T06:44:39.046Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Imparare una parola in dialetto siciliano da un abitante'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Gu';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Nicco',
	       timestamptz '2026-08-31T08:23:11.002Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Almost Concerie'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Nicco';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T08:52:05.193Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Giardini Iblei di Ragusa'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Gu',
	       timestamptz '2026-08-31T10:02:45.874Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Fonte Aretusa'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Gu';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T10:07:42.445Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Pane cunzato'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T13:31:39.264Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Antica Tonnara di Vendicari'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T13:58:58.683Z', 'valido'
	from users u, items i
	where u.nome = 'BF' and i.nome = 'Naturismo!'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T15:08:46.646Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Pasta con la salsa moresca'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T17:05:24.711Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Saltimpalo'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T17:15:58.151Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Casa Pachino'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @Nicco',
	       timestamptz '2026-08-31T18:19:01.534Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Pasta fritta siciliana'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'Nicco';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T18:31:37.883Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = '1ª cosa da fare: selfie inaugurale'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T22:04:29.336Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Rospo smeraldino siciliano'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-08-31T22:39:25.247Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Fare una foto di gruppo senza autoscatto'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-09-01T00:39:40.992Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Coreo'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @BF',
	       timestamptz '2026-09-01T00:51:20.085Z', 'valido'
	from users u, items i
	where u.nome = 'Gu' and i.nome = 'Pasta alla matalotta siracusana'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'BF';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-09-01T04:44:20.368Z', 'valido'
	from users u, items i
	where u.nome = 'Aliona' and i.nome = 'Caffè al Ciclope di Pachino'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-09-01T05:09:40.352Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Fare una degustazione di cioccolato di Modica'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-09-01T08:47:55.250Z', 'valido'
	from users u, items i
	where u.nome = 'MirkoTheBest' and i.nome = 'Scaccia'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-09-01T11:29:36.167Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Naturismo!'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-09-01T15:22:40.321Z', 'valido'
	from users u, items i
	where u.nome = 'NickDeVita' and i.nome = 'Macco di fave'
	returning id
)
select id from c;

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', 'Con @NickDeVita',
	       timestamptz '2026-09-01T15:30:58.878Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Palazzo Beneventano di Scicli'
	returning id
)
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = 'NickDeVita';

with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', null,
	       timestamptz '2026-09-01T16:19:48.988Z', 'valido'
	from users u, items i
	where u.nome = 'Nicco' and i.nome = 'Spiaggia di Marianelli'
	returning id
)
select id from c;

-- --- like -------------------------------------------------------------------
insert into reactions (capture_id, user_id)
select c.id, u.id
from captures c
join users u on u.id <> c.user_id
where (extract(epoch from c.timestamp)::bigint + length(u.nome)) % 5 = 0
on conflict do nothing;

-- --- due scambi -------------------------------------------------------------
insert into transfers (from_user_id, to_user_id, importo, causale)
select a.id, b.id, 25, 'per la birra'
from users a, users b where a.nome = 'Gu' and b.nome = 'BF';

insert into transfers (from_user_id, to_user_id, importo, causale)
select a.id, b.id, 10, 'scommessa persa'
from users a, users b where a.nome = 'Nicco' and b.nome = 'Aliona';

-- --- una contestazione gia' chiusa, cosi' si vede una cattura invalidata ----
do $$
declare v_c uuid; v_chi uuid;
begin
	select c.id into v_c from captures c
	join users u on u.id = c.user_id
	where u.nome = 'MirkoTheBest' order by c.timestamp desc limit 1;
	select id into v_chi from users where nome = 'BF';
	if v_c is not null then
		perform apri_contestazione(v_c, v_chi, 'Questa foto non convince nessuno');
		-- gli altri votano contro: la maggioranza la invalida
		insert into votes (contest_id, user_id, voto)
		select co.id, u.id, 'non_valido'
		from contests co, users u
		where co.capture_id = v_c and u.nome in ('Nicco', 'Gu', 'Aliona')
		on conflict do nothing;
		perform risolvi_contestazione((select id from contests where capture_id = v_c));
	end if;
end $$;

-- --- i capitoli gia' meritati -----------------------------------------------
-- In produzione li sblocca il cron; qui il cron non gira, e senza questa
-- chiamata la barra direbbe "mancano 0 al prossimo capitolo" per sempre.
select sblocca_capitoli();

-- --- i premi della cerimonia ------------------------------------------------
-- Segnaposto per provare la premiazione in locale: quelli veri si scrivono
-- dal pannello.
insert into premi (numero, domanda, croquembouche) values
	(1, 'CHI HA CUCINATO DI PIÙ?', 40),
	(2, 'CHI HA FATTO LA FOTO PIÙ BELLA?', 40),
	(3, 'CHI SI È SVEGLIATO SEMPRE PER ULTIMO?', 40),
	(4, 'CHI SI È LAMENTATO DI PIÙ?', 40),
	(5, 'CHI HA GUIDATO DI PIÙ?', 40),
	(6, 'CHI HA DETTO LA COSA PIÙ SCEMA?', 40),
	(7, 'CHI CI HA TENUTI INSIEME?', 60)
on conflict (numero) do nothing;
