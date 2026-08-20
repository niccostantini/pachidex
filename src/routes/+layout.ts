// SPA pura: tutto il data-access e' client-side verso Supabase.
// prerender:true + ssr:false e' il modo con cui SvelteKit costruisce una SPA
// come file statici invece che come funzioni serverless: adapter-vercel
// pubblica queste pagine come asset statici, e resta una funzione vera solo
// dove serve davvero (/api/upload-url, che deve firmare con una chiave
// segreta lato server).
export const ssr = false;
export const prerender = true;
export const trailingSlash = 'never';
