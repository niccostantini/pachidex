<script lang="ts">
	import { profilo } from '$lib/state/profilo.svelte';
	import { segnaPresenza, type Presenza } from '$lib/db/presenze';
	import Foglio from './Foglio.svelte';

	/**
	 * "Ci sei anche oggi": il premio di chi torna.
	 *
	 * Si chiede una volta per apertura dell'app, appena si sa chi e' entrato.
	 * Il foglio compare solo quando il premio e' nuovo: chi riapre l'app tre
	 * volte in un pomeriggio non deve rivedere la stessa festa, e infatti il
	 * database risponde "nuova: false".
	 */
	let premio = $state<Presenza | null>(null);
	let chiesto = false;

	/** Domani si prende meno di oggi: vuol dire che la scala ricomincia. */
	const ricomincia = $derived(!!premio && premio.prossimo < premio.croquembouche);

	$effect(() => {
		// soloSguardo copre Admin e Spione: per loro il database non
		// risponderebbe niente comunque, ma cosi' non si chiede nemmeno.
		if (chiesto || !profilo.io || profilo.soloSguardo) return;
		chiesto = true;
		void (async () => {
			try {
				const p = await segnaPresenza();
				if (!p?.nuova) return;
				premio = p;
				// Il saldo in cima e' appena cambiato.
				await profilo.aggiornaSaldi();
			} catch {
				// Senza linea si riprova alla prossima apertura: un premio
				// mancato non deve fermare l'app.
			}
		})();
	});
</script>

{#if premio}
	<Foglio aperto titolo="Ci sei anche oggi" variante="green" onChiudi={() => (premio = null)}>
		<div class="presenza">
			<p class="giorni t-num">{premio.striscia}</p>
			<p class="t-label">
				{premio.striscia === 1 ? 'primo giorno' : 'giorni di fila'}
				{#if premio.giro > 1}<span class="t-muted"> · giro {premio.giro}</span>{/if}
			</p>

			<p class="vinti t-num">+{premio.croquembouche} ✦</p>

			<p class="t-small">
				{#if ricomincia}
					Sei in cima alla scala: domani ricomincia da <strong>{premio.prossimo} ✦</strong>
					e si risale.
				{:else}
					Torna domani e sono <strong>{premio.prossimo} ✦</strong>.
				{/if}
				Salti un giorno e si riparte dal primo.
			</p>

			<button class="btn btn--primary btn--lg btn--block" onclick={() => (premio = null)}>
				Va bene
			</button>
		</div>
	</Foglio>
{/if}

<style>
	.presenza {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2);
		text-align: center;
		padding: var(--space-3) var(--space-2);
	}

	.giorni {
		font-size: 3rem;
		line-height: 1;
		color: var(--navy);
	}

	.vinti {
		font-size: 1.5rem;
		color: var(--green);
		margin-top: var(--space-2);
	}

	.presenza :global(.btn) {
		margin-top: var(--space-3);
	}
</style>
