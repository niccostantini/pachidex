<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabase';
	import { caricaConfig } from '$lib/db/dex';
	import Finestra from '$lib/components/Finestra.svelte';

	let numeri = $state({ item: 0, attivi: 0, catture: 0, aperte: 0, scambi: 0 });
	let config = $state<Record<string, number>>({});
	let pronto = $state(false);

	onMount(async () => {
		const conta = async (tabella: string, filtro?: [string, string]) => {
			let q = supabase.from(tabella).select('*', { count: 'exact', head: true });
			if (filtro) q = q.eq(filtro[0], filtro[1]);
			const { count } = await q;
			return count ?? 0;
		};

		const [item, attivi, catture, aperte, scambi, cfg] = await Promise.all([
			conta('items'),
			conta('items', ['attivo', 'true']),
			conta('captures'),
			conta('contests', ['stato', 'aperta']),
			conta('transfers'),
			caricaConfig()
		]);

		numeri = { item, attivi, catture, aperte, scambi };
		config = cfg;
		pronto = true;
	});
</script>

<div class="stack">
	<Finestra titolo="Come va la vacanza" variante="navy">
		{#if !pronto}
			<p class="t-label t-muted">Conto…</p>
		{:else}
			<div class="numeri">
				<div class="n">
					<span class="n__v t-num">{numeri.attivi}</span>
					<span class="t-label">sfiziosita attive</span>
					{#if numeri.item !== numeri.attivi}
						<span class="t-small t-muted">{numeri.item - numeri.attivi} disattivate</span>
					{/if}
				</div>
				<div class="n">
					<span class="n__v t-num">{numeri.catture}</span>
					<span class="t-label">catture</span>
				</div>
				<div class="n" class:n--allarme={numeri.aperte > 0}>
					<span class="n__v t-num">{numeri.aperte}</span>
					<span class="t-label">contestazioni aperte</span>
				</div>
				<div class="n">
					<span class="n__v t-num">{numeri.scambi}</span>
					<span class="t-label">scambi</span>
				</div>
			</div>
		{/if}
	</Finestra>

	{#if pronto && !numeri.item}
		<Finestra titolo="Si comincia da qui" variante="orange">
			<p>Il PachiDex e' vuoto. Carica le sfiziosita' e la vacanza puo' partire.</p>
			<p class="t-small t-muted">
				Puoi importare un CSV in blocco oppure aggiungere gli elementi a mano, uno per uno.
			</p>
			<div class="cta">
				<a class="btn btn--primary" href="/gestione-xk29/import">Importa un CSV</a>
				<a class="btn" href="/gestione-xk29/item">Aggiungi a mano</a>
			</div>
		</Finestra>
	{/if}

	<Finestra titolo="Regole in vigore" variante="blue">
		{#if pronto}
			<ul class="regole t-small">
				<li>Aprire una contestazione costa <strong>✦ {config.costo_apertura_contestazione}</strong></li>
				<li>Chi perde la contestazione lascia altri <strong>✦ {config.penalita_extra_contestazione}</strong></li>
				<li>
					Valori di default: comune ✦ {config.croq_comune}, raro ✦ {config.croq_raro},
					leggendario ✦ {config.croq_leggendario}
				</li>
				<li>Checkpoint GPS validi entro <strong>{config.raggio_gps_metri} m</strong></li>
				<li>Una contestazione scade dopo <strong>{config.durata_contestazione_ore} ore</strong></li>
			</ul>
			<a class="btn btn--sm" href="/gestione-xk29/config">Cambia le regole</a>
		{/if}
	</Finestra>
</div>

<style>
	.numeri {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
		gap: var(--space-2);
	}

	.n {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: var(--space-3);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.n--allarme {
		background: var(--yellow);
	}

	.n__v {
		font-size: 2rem;
		font-weight: 700;
		line-height: 1;
	}

	.cta {
		display: flex;
		gap: var(--space-2);
		margin-top: var(--space-3);
		flex-wrap: wrap;
	}

	.regole {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-bottom: var(--space-3);
	}

	.regole li {
		padding-left: 14px;
		position: relative;
	}

	.regole li::before {
		content: '▪';
		position: absolute;
		left: 0;
		color: var(--orange);
	}
</style>
