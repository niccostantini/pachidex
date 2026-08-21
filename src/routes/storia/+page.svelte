<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { caricaStoria, type StatoStoria } from '$lib/db/storia';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let storia = $state<StatoStoria | null>(null);
	let errore = $state<string | null>(null);

	onMount(async () => {
		try {
			storia = await caricaStoria();
		} catch (e) {
			errore = messaggioErrore(e);
		}
	});

	const quando = (iso: string | null) =>
		iso ? new Date(iso).toLocaleDateString('it-IT', { day: 'numeric', month: 'long' }) : '';
</script>

<svelte:head><title>La storia — Pachino Express</title></svelte:head>

<div class="st stack">
	<Finestra titolo="Puntini piccini picciò" variante="navy" onChiudi={() => goto('/')}>
		{#if errore}
			<p class="t-small errore">{errore}</p>
		{:else if !storia}
			<p class="t-label t-muted">Conto i puntini…</p>
		{:else}
			<div class="totale">
				<span class="totale__n t-num">{storia.punti}</span>
				<span class="t-label">puntini raccolti insieme</span>
			</div>

			<p class="t-small t-muted spiega">
				Ogni cattura del gruppo riempie la barra di quanto vale. Si perdono solo con le
				contestazioni, e un capitolo gia' sbloccato resta sbloccato anche se la barra
				scende.
			</p>
		{/if}
	</Finestra>

	{#if storia}
		<ol class="capitoli">
			{#each storia.capitoli as c (c.numero)}
				{@const prossimo = storia.prossimo?.numero === c.numero}
				<li class="cap" class:cap--sbloccato={c.sbloccato} class:cap--prossimo={prossimo}>
					<div class="cap__numero t-num">{c.numero}</div>

					<div class="grow">
						{#if c.sbloccato}
							<p class="cap__titolo">{c.titolo ?? `Capitolo ${c.numero}`}</p>
							<p class="t-small t-muted">
								Sbloccato il {quando(c.sbloccato_at)}
							</p>
						{:else}
							<p class="cap__titolo cap__titolo--muto">Capitolo {c.numero}</p>
							{#if prossimo}
								<p class="t-small">
									Mancano <strong>{storia.mancano}</strong> puntini
								</p>
								<div class="mini">
									<div class="mini__riempi" style:width="{storia.avanzamento * 100}%"></div>
								</div>
							{:else}
								<p class="t-small t-muted">a {c.soglia} puntini</p>
							{/if}
						{/if}
					</div>

					<span class="cap__stato" aria-hidden="true">{c.sbloccato ? '✓' : '?'}</span>
				</li>
			{/each}
		</ol>

		<p class="chiusa t-small t-muted">
			I capitoli si sbloccano da soli. Quando ce li facciamo leggere è un altro discorso.
		</p>
	{/if}
</div>

<style>
	.st {
		padding: var(--space-3);
	}

	.totale {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
		padding: var(--space-3);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.totale__n {
		font-size: 2.5rem;
		font-weight: 700;
		line-height: 1;
		color: var(--orange-dark);
	}

	.spiega {
		margin-top: var(--space-2);
	}

	.capitoli {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.cap {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2);
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		opacity: 0.62;
	}

	.cap--sbloccato {
		opacity: 1;
		background: var(--paper);
		border-width: var(--border);
	}

	.cap--prossimo {
		opacity: 1;
		background: var(--cream);
		border-width: var(--border);
		box-shadow: 0 0 0 3px var(--yellow);
	}

	.cap__numero {
		width: 34px;
		height: 34px;
		display: grid;
		place-items: center;
		flex-shrink: 0;
		font-weight: 700;
		font-size: 1.125rem;
		background: var(--navy);
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
	}

	.cap--sbloccato .cap__numero {
		background: var(--yellow);
		color: var(--navy);
	}

	.cap__titolo {
		font-weight: 700;
		font-size: 1rem;
	}

	.cap__titolo--muto {
		color: var(--navy-soft);
	}

	.cap__stato {
		font-size: 1.25rem;
		font-weight: 700;
		color: var(--navy-soft);
	}

	.cap--sbloccato .cap__stato {
		color: var(--green);
	}

	.mini {
		height: 7px;
		background: var(--paper);
		border: 1px solid var(--navy);
		margin-top: 4px;
	}

	.mini__riempi {
		height: 100%;
		background: var(--orange);
	}

	.chiusa {
		text-align: center;
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
