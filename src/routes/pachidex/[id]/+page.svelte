<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { caricaDex, catturePerItem } from '$lib/db/dex';
	import { etichettaCategoria, tempoRelativo } from '$lib/game/rules';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import Rarita from '$lib/components/Rarita.svelte';
	import type { Capture, User, VoceDex } from '$lib/types';

	const id = $derived(page.params.id);

	let voce = $state<VoceDex | null>(null);
	let catture = $state<(Capture & { autore: User })[]>([]);
	let stato = $state<'carico' | 'ok' | 'errore'>('carico');
	let errore = $state<string | null>(null);

	const mieQui = $derived(catture.filter((c) => c.user_id === profilo.io?.id));
	const scopritori = $derived([...new Map(catture.map((c) => [c.user_id, c.autore])).values()]);

	onMount(async () => {
		try {
			const [dex, cat] = await Promise.all([caricaDex(), catturePerItem(id as string)]);
			voce = dex.find((v) => v.item_id === id) ?? null;
			catture = cat;
			stato = 'ok';
		} catch (e) {
			errore = messaggioErrore(e);
			stato = 'errore';
		}
	});
</script>

<svelte:head><title>{voce?.nome ?? 'Elemento'} — PachiDex</title></svelte:head>

<div class="dettaglio stack">
	{#if stato === 'carico'}
		<div class="finta skeleton"></div>
	{:else if stato === 'errore' || !voce}
		<Finestra titolo="Non trovato" variante="navy" onChiudi={() => goto('/pachidex')}>
			<p class="t-small">{errore ?? 'Questo elemento non esiste piu.'}</p>
		</Finestra>
	{:else}
		<Finestra titolo={voce.nome} onChiudi={() => goto('/pachidex')} flush>
			{#if voce.prima_foto}
				<img class="grande" src={voce.prima_foto} alt={voce.nome} />
			{/if}
			<div class="pad stack">
				<div class="row">
					<Rarita rarita={voce.rarita} croquembouche={voce.croquembouche} />
					<span class="badge" style:background="var(--cat-{voce.categoria})" style:color="var(--paper)">
						{etichettaCategoria(voce.categoria)}
					</span>
					{#if voce.ripetibile}<span class="badge">ripetibile</span>{/if}
					{#if voce.validazione === 'auto_gps'}<span class="badge badge--gps">GPS</span>{/if}
				</div>

				{#if voce.note}
					<p class="note">{voce.note}</p>
				{/if}

				<p class="t-small t-muted">
					{#if mieQui.length}
						L'hai preso {mieQui.length}
						{mieQui.length === 1 ? 'volta' : 'volte'}.
					{:else}
						Tu non l'hai ancora preso.
					{/if}
				</p>
			</div>
		</Finestra>

		<Finestra titolo="Chi ce l'ha" variante="blue">
			{#if !catture.length}
				<p class="t-small t-muted">Nessuno, ancora. C'e' un primato da prendersi.</p>
			{:else}
				<div class="scopritori">
					{#each scopritori as u (u.id)}
						<div class="scopritore">
							<Avatar utente={u} />
							<span class="t-small">{u.nome}</span>
						</div>
					{/each}
				</div>

				<hr class="hr" />

				<ul class="storia">
					{#each catture as c (c.id)}
						<li class="riga">
							<img class="mini" src={c.foto_url} alt="" loading="lazy" />
							<span class="grow t-small">
								<strong>{c.autore.nome}</strong>
								{#if c.nota}<span class="t-muted"> — {c.nota}</span>{/if}
							</span>
							<span class="t-small t-muted">{tempoRelativo(c.timestamp)}</span>
						</li>
					{/each}
				</ul>
			{/if}
		</Finestra>
	{/if}
</div>

<style>
	.dettaglio {
		padding: var(--space-3);
	}

	.finta {
		height: 300px;
		border: var(--border) solid var(--navy);
	}

	.grande {
		width: 100%;
		aspect-ratio: 4 / 3;
		object-fit: cover;
		border-bottom: var(--border) solid var(--navy);
	}

	.note {
		background: var(--cream);
		border-left: var(--border) solid var(--navy);
		padding: var(--space-2);
		font-size: 0.9375rem;
	}

	.scopritori {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.scopritore {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
	}

	.storia {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.mini {
		width: 44px;
		height: 44px;
		object-fit: cover;
		border: var(--border-thin) solid var(--navy);
		flex-shrink: 0;
	}
</style>
