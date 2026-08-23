<script lang="ts">
	import { onMount } from 'svelte';
	import { notifiche } from '$lib/state/notifiche.svelte';
	import { profilo } from '$lib/state/profilo.svelte';
	import Foglio from './Foglio.svelte';
	import Icona from './Icona.svelte';

	let aperto = $state(false);

	onMount(() => {
		void notifiche.init();
	});

	// Cambiando giocatore sullo stesso telefono, le notifiche devono seguire
	// chi lo sta usando adesso.
	$effect(() => {
		if (profilo.io) void notifiche.riassegna(profilo.io.id);
	});
</script>

<button
	class="campanella"
	class:campanella--spenta={!notifiche.attive}
	onclick={() => (aperto = true)}
	aria-label="Notifiche"
	data-giro="campanella"
>
	<Icona nome="campana" dimensione={15} colore="var(--paper)" sfondo="var(--orange)" />
</button>

<Foglio {aperto} titolo="Notifiche" variante="navy" onChiudi={() => (aperto = false)}>
	<div class="stack">
		{#if notifiche.stato === 'serve_installazione'}
			<div class="avviso">
				<p><strong>Prima devi installare l'app.</strong></p>
				<p class="t-small">
					Su iPhone le notifiche arrivano solo se Pachino Express sta sulla schermata
					Home: in Safari come scheda normale il sistema non le prevede proprio.
				</p>
				<p class="t-small t-muted">
					Tocca il tasto Condividi in basso, poi <strong>Aggiungi a schermata Home</strong>.
					Riapri l'app da li' e torna qui.
				</p>
			</div>
		{:else if notifiche.stato === 'non_supportato'}
			<p class="t-small">Questo browser non sa gestire le notifiche push.</p>
		{:else if notifiche.stato === 'rifiutate'}
			<div class="avviso">
				<p><strong>Le notifiche sono bloccate.</strong></p>
				<p class="t-small">
					Il permesso e' stato negato, e il browser non lo richiede una seconda volta:
					va riattivato dalle impostazioni del sito.
				</p>
			</div>
		{:else if notifiche.attive}
			<p class="ok"><strong>Notifiche attive su questo dispositivo.</strong></p>
			<ul class="elenco t-small">
				<li>Quando qualcuno cattura qualcosa</li>
				<li>Quando ti taggano in una foto</li>
				<li>Quando ti contestano, e come va a finire</li>
				<li>Quando c'e' da votare una contestazione</li>
				<li>Quando ricevi Croquembouche</li>
				<li>Quando qualcuno ti supera in classifica</li>
				<li>Ogni sera alle 22:30, il podio</li>
			</ul>
			<button class="btn" onclick={() => notifiche.disattiva()} disabled={notifiche.inCorso}>
				Disattiva
			</button>
		{:else}
			<p class="t-small">
				Le catture degli altri, le contestazioni da votare, gli scambi in arrivo e il
				podio della sera. Il permesso lo chiede il telefono, non io.
			</p>
			<button
				class="btn btn--primary btn--lg btn--block"
				onclick={() => profilo.io && notifiche.attiva(profilo.io.id)}
				disabled={notifiche.inCorso || !profilo.io}
			>
				{notifiche.inCorso ? 'Attivo…' : 'Attiva le notifiche'}
			</button>
		{/if}

		{#if notifiche.errore}
			<p class="t-small errore">{notifiche.errore}</p>
		{/if}
	</div>
</Foglio>

<style>
	.campanella {
		display: grid;
		place-items: center;
		width: 26px;
		height: 26px;
		background: var(--orange);
		border: var(--border-thin) solid var(--navy);
		cursor: pointer;
		-webkit-tap-highlight-color: transparent;
	}

	/* Spenta finche' non sono attive: si vede a colpo d'occhio che manca. */
	/**
	 * Spenta non basta: pulsa piano finche' non le si attiva. Senza notifiche
	 * meta' del gioco non arriva — contestazioni da votare, capitoli sbloccati
	 * — e restare in silenzio significa che nessuno se ne accorge.
	 */
	.campanella--spenta {
		opacity: 0.5;
		animation: chiama 2.6s steps(2, end) infinite;
	}

	@keyframes chiama {
		0%, 70% {
			opacity: 0.5;
			transform: none;
		}
		78% {
			opacity: 1;
			transform: rotate(-8deg);
		}
		86% {
			opacity: 1;
			transform: rotate(8deg);
		}
		94% {
			opacity: 1;
			transform: none;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.campanella--spenta {
			animation: none;
		}
	}

	.avviso {
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-3);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.ok {
		color: var(--green);
	}

	.elenco {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.elenco li {
		padding-left: 14px;
		position: relative;
	}

	.elenco li::before {
		content: '▪';
		position: absolute;
		left: 0;
		color: var(--orange);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
