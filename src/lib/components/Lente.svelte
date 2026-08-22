<script lang="ts">
	/**
	 * Visore a schermo intero per una foto.
	 *
	 * Esiste per un motivo preciso: le foto stanno su un dominio diverso da
	 * quello dell'app, e un <a target="_blank"> verso un'altra origine fa
	 * uscire iOS dalla PWA installata, aprendo il browser interno con le
	 * barre di Safari. Guardare una foto non deve far sembrare che l'app sia
	 * finita.
	 */
	interface Props {
		src: string | null;
		alt?: string;
		onChiudi: () => void;
	}

	let { src, alt = '', onChiudi }: Props = $props();
</script>

{#if src}
	<div
		class="lente"
		role="dialog"
		aria-modal="true"
		aria-label={alt || 'Foto'}
		onclick={(e) => e.target === e.currentTarget && onChiudi()}
		onkeydown={(e) => e.key === 'Escape' && onChiudi()}
		tabindex="-1"
	>
		<div class="cornice">
			<header class="win__bar win__bar--navy">
				<span class="win__title">{alt}</span>
				<div class="win__btns">
					<button class="win__btn" data-action="chiudi" onclick={onChiudi} aria-label="Chiudi">
						×
					</button>
				</div>
			</header>
			<img {src} {alt} />
		</div>
	</div>
{/if}

<style>
	.lente {
		position: fixed;
		inset: 0;
		z-index: 90;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-3);
		padding-top: calc(var(--space-3) + env(safe-area-inset-top));
		padding-bottom: calc(var(--space-3) + env(safe-area-inset-bottom));
		background: repeating-conic-gradient(
			rgba(22, 27, 61, 0.92) 0% 25%,
			rgba(22, 27, 61, 0.8) 0% 50%
		);
		background-size: 4px 4px;
	}

	.cornice {
		display: flex;
		flex-direction: column;
		max-width: 100%;
		max-height: 100%;
		background: var(--paper);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow);
	}

	/* La foto intera, mai ritagliata: e' il motivo per cui la si sta aprendo. */
	.cornice img {
		display: block;
		max-width: 100%;
		min-height: 0;
		object-fit: contain;
		background: var(--cream);
	}
</style>
