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
</script>

{#if aperto}
	<div
		class="velo"
		role="presentation"
		onclick={(e) => e.target === e.currentTarget && onChiudi()}
	>
		<div class="foglio" role="dialog" aria-modal="true" aria-label={titolo}>
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
		</div>
	</div>
{/if}

<style>
	.velo {
		position: fixed;
		inset: 0;
		z-index: 60;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		/* Retino a puntini invece di una sfocatura: costa niente e sta nello stile. */
		background: repeating-conic-gradient(
			rgba(22, 27, 61, 0.72) 0% 25%,
			rgba(22, 27, 61, 0.55) 0% 50%
		);
		background-size: 4px 4px;
	}

	.foglio {
		width: 100%;
		max-width: 640px;
		max-height: 88dvh;
		display: flex;
		flex-direction: column;
		background: var(--paper);
		border: var(--border) solid var(--navy);
		border-bottom: 0;
		animation: sali 160ms steps(4, end);
	}

	.foglio__corpo {
		overflow-y: auto;
		padding: var(--space-3);
		padding-bottom: calc(var(--space-3) + env(safe-area-inset-bottom));
	}

	@keyframes sali {
		from {
			transform: translateY(100%);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.foglio {
			animation: none;
		}
	}
</style>
