-- ============================================================================
-- Pachino Express — v_saldi smette di scavalcare le RLS
--
-- Era rimasta l'unica vista senza security_invoker, quindi girava con i
-- diritti del proprietario e le RLS delle tabelle sotto non la riguardavano.
-- Con la chiave anon — che e' pubblica per progetto e sta nel bundle — si
-- leggevano nomi, id e movimenti di tutti i giocatori senza fare login.
--
-- Non l'avevo messa a suo tempo perche' la vista non l'aveva mai avuta e
-- cambiarla a vacanza in corso sarebbe stato un rischio gratuito. Adesso che
-- c'e' l'autenticazione quel ragionamento non vale piu': e' semplicemente una
-- falla.
--
-- Nessuno dei consumatori si rompe: chiudi_premio e' security definer, e
-- invia_croquembouche_interna si raggiunge solo dal guscio che e' definer
-- anche lui. v_classifica e' gia' invoker e continua a funzionare per chi e'
-- entrato.
-- ============================================================================

alter view v_saldi set (security_invoker = true);
