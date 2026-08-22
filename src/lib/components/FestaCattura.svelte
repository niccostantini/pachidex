<script lang="ts">
	import { etichettaRarita } from '$lib/game/rules';
	import type { VoceDex } from '$lib/types';

	/**
	 * La festa dopo una cattura.
	 *
	 * Esiste perche' era l'unico momento muto dell'app: scatti, scegli,
	 * tocchi Cattura e ti ritrovi nel feed senza che sia successo niente.
	 * E' il gesto piu' ripetuto della vacanza — qualche centinaio di volte in
	 * dieci giorni — e non dava mai soddisfazione.
	 *
	 * Non sa se e' un primato: quello lo stabilisce il server dopo l'upload,
	 * e si vede nel feed. Qui si celebra cio' che si sa gia' con certezza.
	 */
	interface Props {
		voce: VoceDex | null;
		onFine: () => void;
	}

	let { voce, onFine }: Props = $props();

	let fase = $state<'chiuso' | 'aperto'>('chiuso');
	let contatore = $state(0);

	const leggendario = $derived(voce?.rarita === 'leggendario');

	$effect(() => {
		if (!voce) {
			fase = 'chiuso';
			contatore = 0;
			return;
		}

		const tempi: ReturnType<typeof setTimeout>[] = [];
		// Il blocco rimbalza, poi si apre: la stessa sequenza di quando ci
		// sbatti sotto in un gioco a piattaforme.
		tempi.push(setTimeout(() => (fase = 'aperto'), 340));

		// I Croquembouche salgono contando invece di comparire: e' la parte
		// che si guarda volentieri.
		const passi = 14;
		const meta = voce.croquembouche / passi;
		for (let i = 1; i <= passi; i++) {
			tempi.push(setTimeout(() => (contatore = Math.round(meta * i)), 420 + i * 45));
		}

		// Chiusura da sola: nessuno vuole toccare un pulsante dopo ogni foto.
		tempi.push(setTimeout(onFine, leggendario ? 3200 : 2400));

		return () => tempi.forEach(clearTimeout);
	});
</script>

{#if voce}
	<div
		class="festa"
		role="dialog"
		aria-modal="true"
		aria-label="Cattura riuscita: {voce.nome}"
		onclick={onFine}
		onkeydown={(e) => e.key === 'Escape' && onFine()}
		tabindex="-1"
	>
		<div class="scena">
			<div class="blocco-wrap">
				{#if fase === 'aperto'}
					<!-- Raggi che partono dal blocco. Sono rettangoli, non una
					     sfocatura: il pixel non conosce il bagliore. -->
					{#each [0, 45, 90, 135, 180, 225, 270, 315] as ang (ang)}
						<span class="raggio" style:--ang="{ang}deg"></span>
					{/each}
				{/if}

				<div
					class="qblock blocco"
					class:blocco--bump={fase === 'chiuso'}
					class:blocco--aperto={fase === 'aperto'}
					style:--rarity="var(--rarity-{voce.rarita})"
				>
					<span class="qblock__mark">{fase === 'aperto' ? '✦' : '?'}</span>
				</div>
			</div>

			{#if fase === 'aperto'}
				<div class="carta" class:carta--holo={leggendario}>
					<p class="nome">{voce.nome}</p>
					<p class="rarita" style:color="var(--rarity-{voce.rarita})">
						{etichettaRarita(voce.rarita)}
					</p>
					<div class="premio">
						<p class="valore t-num">+{contatore} ✦</p>
						{#if leggendario}
							<p class="urlo t-label">Un leggendario!</p>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	.festa {
		position: fixed;
		inset: 0;
		z-index: 95;
		display: grid;
		place-items: center;
		padding: var(--space-4);
		background: repeating-conic-gradient(
			rgba(22, 27, 61, 0.93) 0% 25%,
			rgba(22, 27, 61, 0.82) 0% 50%
		);
		background-size: 4px 4px;
		cursor: pointer;
	}

	.scena {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
	}

	.blocco-wrap {
		position: relative;
		display: grid;
		place-items: center;
	}

	.blocco {
		width: 96px;
		height: 96px;
		cursor: default;
	}

	.blocco--bump {
		animation: bump 340ms steps(1, end);
	}

	.blocco--aperto {
		animation: apre 260ms steps(3, end);
	}

	@keyframes apre {
		0% {
			transform: scale(0.7);
		}
		100% {
			transform: scale(1);
		}
	}

	.raggio {
		position: absolute;
		width: 6px;
		height: 34px;
		background: var(--yellow);
		border: 2px solid var(--navy);
		transform: rotate(var(--ang)) translateY(-78px);
		transform-origin: center center;
		animation: raggia 500ms steps(4, end) forwards;
	}

	@keyframes raggia {
		from {
			transform: rotate(var(--ang)) translateY(-48px) scaleY(0.3);
			opacity: 1;
		}
		to {
			transform: rotate(var(--ang)) translateY(-92px) scaleY(1);
			opacity: 0;
		}
	}

	.carta {
		background: var(--paper);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow);
		padding: var(--space-3) var(--space-4);
		text-align: center;
		min-width: 220px;
		animation: sali 200ms steps(3, end);
	}

	@keyframes sali {
		from {
			transform: translateY(14px);
			opacity: 0;
		}
	}

	.nome {
		font-size: 1.25rem;
		font-weight: 700;
		line-height: 1.15;
	}

	.rarita {
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.1em;
		margin-top: 2px;
	}

	/* Il numero e il grido stanno in riga apposta: affiancati sono piu'
	   compatti e piu' squillanti che impilati. */
	.premio {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-wrap: wrap;
		gap: var(--space-2);
		margin-top: var(--space-2);
	}

	.valore {
		font-size: 2rem;
		font-weight: 700;
		color: var(--orange-dark);
		line-height: 1.1;
	}

	.urlo {
		color: var(--navy);
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		padding: 2px 8px;
	}

	@media (prefers-reduced-motion: reduce) {
		.blocco--bump,
		.blocco--aperto,
		.carta,
		.raggio {
			animation: none;
		}
		.raggio {
			display: none;
		}
	}
</style>
