<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		aperto: boolean;
		titolo: string;
		variante?: 'orange' | 'blue' | 'navy' | 'green';
		onChiudi: () => void;
		children: Snippet;
	}

	let { aperto, titolo, variante = 'orange', onChiudi, children }: Props = $props();

	/**
	 * E' un <dialog> nativo aperto con showModal(), non un div sovrapposto.
	 *
	 * Il motivo e' concreto: la campanella delle notifiche vive dentro
	 * l'intestazione, che essendo sticky con uno z-index crea un contesto di
	 * impilamento. Un foglio costruito con position:fixed resta prigioniero di
	 * quel contesto e finisce SOTTO la taskbar, per quanto alto sia il suo
	 * z-index. Il top layer del dialog non ha questo problema, e in piu' porta
	 * in dote il fuoco che non scappa dietro.
	 *
	 * Il dialog esiste solo mentre e' aperto, e showModal() parte al montaggio.
	 * Tenerlo sempre nel DOM e pilotarlo con un effetto sembrava piu' semplice,
	 * ma bastava una chiusura che non aggiornava lo stato per lasciare i due
	 * disallineati: il foglio chiuso, la variabile ancora a true, e da quel
	 * momento il pulsante non riapriva piu' niente. Montandolo e smontandolo
	 * quello stato intermedio non puo' esistere.
	 */
	function apriModale(node: HTMLDialogElement) {
		node.showModal();
	}

	/** Il click sullo sfondo arriva al dialog stesso, non ai figli. */
	function suClick(e: MouseEvent) {
		if (e.target === e.currentTarget) onChiudi();
	}
</script>

{#if aperto}
	<dialog
		use:apriModale
		class="foglio"
		oncancel={(e) => {
			// Esc: si annulla la chiusura nativa e si passa dallo stato, cosi'
			// la strada per chiudere e' sempre e solo una.
			e.preventDefault();
			onChiudi();
		}}
		onclick={suClick}
		aria-label={titolo}
	>
		<header class="win__bar win__bar--{variante}">
			<span class="win__title">{titolo}</span>
			<div class="win__btns">
				<span class="win__btn" aria-hidden="true">–</span>
				<button class="win__btn" data-action="chiudi" onclick={onChiudi} aria-label="Chiudi">
					×
				</button>
			</div>
		</header>
		<div class="foglio__corpo">
			{@render children()}
		</div>
	</dialog>
{/if}

<style>
	.foglio {
		/* Il dialog nasce centrato e con stili suoi: qui si azzera tutto e lo si
		   incolla in basso, come una tendina. */
		margin: auto auto 0;
		padding: 0;
		width: 100%;
		max-width: 640px;
		max-height: 88dvh;
		background: var(--paper);
		color: var(--navy);
		border: var(--border) solid var(--navy);
		border-bottom: 0;
		overflow: visible;
	}

	.foglio[open] {
		display: flex;
		flex-direction: column;
		/* Solo opacita': l'entrata NON deve spostare il foglio. Con una
		   translate, un'animazione che non parte — scheda in background, tab
		   sospesa dal sistema — lo lascerebbe fuori schermo per sempre. */
		animation: comparsa 120ms steps(3, end);
	}

	.foglio::backdrop {
		/* Retino a puntini invece di una sfocatura: costa niente e sta nello stile. */
		background: repeating-conic-gradient(
			rgba(22, 27, 61, 0.72) 0% 25%,
			rgba(22, 27, 61, 0.55) 0% 50%
		);
		background-size: 4px 4px;
	}

	.foglio__corpo {
		overflow-y: auto;
		padding: var(--space-3);
		/* Il backdrop del dialog copre anche la taskbar, quindi non serve
		   lasciarle spazio: basta stare fuori dalla tacca in basso. */
		padding-bottom: calc(var(--space-3) + env(safe-area-inset-bottom));
	}

	@keyframes comparsa {
		from {
			opacity: 0;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.foglio[open] {
			animation: none;
		}
	}
</style>
