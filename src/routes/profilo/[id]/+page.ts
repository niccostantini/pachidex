// Come per la scheda di un elemento: l'id esiste solo a runtime, quindi la
// pagina non e' prerenderizzabile. La serve il fallback SPA — che offline
// funziona lo stesso, perche' il service worker ripiega sul guscio della home
// e il router disegna il profilo da li'.
export const prerender = false;
