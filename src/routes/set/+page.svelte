<script lang="ts">
	import { onMount } from 'svelte';
	import { caricaSet, vincolo, type SetConStato } from '$lib/db/set';
	import { caricaDex, mieCatture, type MiaVoce } from '$lib/db/dex';
	import type { VoceDex } from '$lib/types';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let sets = $state<SetConStato[]>([]);
	let voci = $state<VoceDex[]>([]);
	let mie = $state<Map<string, MiaVoce>>(new Map());
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);

	const chiusi = $derived(sets.filter((s) => s.completo).length);

	/**
	 * Un requisito "tutte le X" da solo non dice niente: "Tutte le spiagge 0/1"
	 * non fa capire ne' quante sono ne' quali mancano. Qui si apre nei singoli
	 * elementi, con la spunta su quelli presi — come fanno gli altri set.
	 *
	 * Il PachiDex e i crediti sono gia' in cache: non costa una query in piu'.
	 */
	function elementiDi(parola: string) {
		const q = parola.toLowerCase();
		return voci
			.filter((v) => v.nome.toLowerCase().includes(q))
			.map((v) => ({ nome: v.nome, fatto: mie.has(v.item_id) }));
	}

	/**
	 * I set legati a una giornata tengono i numeri del database, che sa fare
	 * l'incrocio fra i giorni; gli altri contano gli elementi aperti, cosi' la
	 * barra dice la stessa cosa delle spunte sotto.
	 */
	function progresso(s: SetConStato): { fatti: number; totale: number } {
		if (s.stesso_giorno || s.giorno) return { fatti: s.fatti, totale: s.totale };
		let fatti = 0;
		let totale = 0;
		for (const r of s.requisiti) {
			if (r.tipo === 'tutte_parola' && r.valore) {
				const el = elementiDi(r.valore);
				totale += el.length;
				fatti += el.filter((e) => e.fatto).length;
			} else {
				totale += 1;
				fatti += r.fatto ? 1 : 0;
			}
		}
		return { fatti, totale };
	}

	onMount(async () => {
		try {
			sets = await caricaSet(profilo.io?.id ?? null);
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
			return;
		}

		// Servono solo ad aprire i requisiti "tutte le X": se non arrivano, quei
		// requisiti restano su una riga sola e il resto della pagina funziona.
		try {
			voci = await caricaDex();
			if (profilo.io) mie = await mieCatture(profilo.io.id);
		} catch {
			voci = [];
		}
	});
</script>

<svelte:head><title>I set — Pachino Express</title></svelte:head>

<div class="set stack">
	<div class="testa">
		<h1>I set</h1>
		<p class="t-label t-muted">{chiusi} / {sets.length} completati</p>
	</div>

	<p class="spiega t-small t-muted">
		Gruppi di sfiziosità che valgono un premio doppio: i Croquembouche vanno a te,
		i puntini alla barra della storia, che è di tutti. Vale anche quello che hai
		sbloccato facendoti taggare.
	</p>

	{#if stato === 'carico'}
		<p class="t-label t-muted">Carico…</p>
	{:else if stato === 'errore'}
		<p class="t-small">{errore}</p>
	{:else}
		{#each sets as s (s.id)}
			{@const p = progresso(s)}
			<Finestra titolo={s.nome} variante={s.completo ? 'green' : 'blue'}>
				<div class="stack">
					{#if s.descrizione}
						<p class="t-small">{s.descrizione}</p>
					{/if}

					<div class="pista" aria-label="{p.fatti} su {p.totale}">
						<div
							class="pista__riempi"
							class:pista__riempi--fatto={s.completo}
							style:width="{(p.fatti / Math.max(p.totale, 1)) * 100}%"
						></div>
						<span class="pista__conta t-num">{p.fatti}/{p.totale}</span>
					</div>

					<ul class="requisiti">
						{#each s.requisiti as r (r.id)}
							{#if r.tipo === 'tutte_parola' && r.valore && elementiDi(r.valore).length}
								{#each elementiDi(r.valore) as e (e.nome)}
									<li class="req" class:req--fatto={e.fatto}>
										<span class="segno" aria-hidden="true">{e.fatto ? '✓' : '·'}</span>
										<span class="grow">{e.nome}</span>
									</li>
								{/each}
							{:else}
								<li class="req" class:req--fatto={r.fatto}>
									<span class="segno" aria-hidden="true">{r.fatto ? '✓' : '·'}</span>
									<span class="grow">{r.etichetta}</span>
								</li>
							{/if}
						{/each}
					</ul>

					<div class="fondo">
						<span class="premio t-label">{s.croquembouche} ✦ · {s.punti_storia} puntini</span>
						{#if vincolo(s)}
							<span class="vincolo t-label">{vincolo(s)}</span>
						{/if}
					</div>

					{#if s.completo}
						<p class="fatto t-label">Set completato</p>
					{/if}
				</div>
			</Finestra>
		{/each}
	{/if}
</div>

<style>
	.set {
		padding: var(--space-3);
	}

	.testa {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: var(--space-2);
	}

	.pista {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: flex-end;
		height: 18px;
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		overflow: hidden;
	}

	.pista__riempi {
		position: absolute;
		inset: 0 auto 0 0;
		/* A scatti, come tutto il resto: il pixel non conosce la transizione morbida. */
		transition: width 700ms steps(10, end);
		background: repeating-linear-gradient(
			90deg,
			var(--orange) 0 6px,
			var(--orange-dark) 6px 12px
		);
	}

	.pista__riempi--fatto {
		background: var(--green);
	}

	.pista__conta {
		position: relative;
		font-size: 0.6875rem;
		font-weight: 700;
		padding-right: 6px;
		color: var(--navy);
	}

	.requisiti {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.req {
		display: flex;
		align-items: baseline;
		gap: 7px;
		font-size: 0.875rem;
		color: var(--navy);
		opacity: 0.55;
	}

	.req--fatto {
		opacity: 1;
		font-weight: 700;
	}

	.segno {
		width: 12px;
		flex-shrink: 0;
		text-align: center;
		color: var(--orange-dark);
	}

	.fondo {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
		align-items: center;
	}

	.premio {
		background: var(--navy);
		color: var(--yellow);
		padding: 3px 7px;
	}

	.vincolo {
		background: var(--paper);
		border: var(--border-thin) dashed var(--navy);
		padding: 2px 6px;
	}

	.fatto {
		color: var(--paper);
		background: var(--green);
		border: var(--border-thin) solid var(--navy);
		padding: 3px 7px;
		align-self: flex-start;
	}

	@media (prefers-reduced-motion: reduce) {
		.pista__riempi {
			transition: none;
		}
	}
</style>
