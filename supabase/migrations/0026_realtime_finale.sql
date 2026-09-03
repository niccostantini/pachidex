-- ============================================================================
-- Pachino Express — la premiazione entra nel realtime
--
-- Le tabelle della cerimonia non erano nella publication supabase_realtime,
-- quindi i telefoni non ricevevano nessun cambiamento: la riga "finale"
-- avanzava sul database e gli schermi restavano fermi sul podio. Una
-- cerimonia sincronizzata in cui nessuno vede l'avanzamento non e' una
-- cerimonia.
--
-- Trovato in locale prima di usarla sul serio: in produzione si sarebbe visto
-- la sera del 6 settembre, con sei persone davanti.
-- ============================================================================

alter publication supabase_realtime add table finale;
alter publication supabase_realtime add table premi;
alter publication supabase_realtime add table premi_voti;
alter publication supabase_realtime add table premi_esiti;
