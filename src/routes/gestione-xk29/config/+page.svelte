<script lang="ts">
	import { onMount } from 'svelte';
	import { salvaConfig } from '$lib/db/admin';
	import { caricaConfig } from '$lib/db/dex';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	const CAMPI: { chiave: string; label: string; aiuto: string; gruppo: string }[] = [
		{
			chiave: 'costo_apertura_contestazione',
			label: 'Costo apertura contestazione',
			aiuto: 'Lo paga chi contesta, sempre, anche se ha ragione.',
			gruppo: 'Contestazioni'
		},
		{
			chiave: 'penalita_extra_contestazione',
			label: 'Penalita per chi perde',
			aiuto: 'In piu rispetto al costo fisso. La paga il contestato se la cattura cade, il contestante se regge.',
			gruppo: 'Contestazioni'
		},
		{
			chiave: 'durata_contestazione_ore',
			label: 'Ore prima della scadenza',
			aiuto: 'Senza maggioranza entro questo tempo, la cattura resta valida.',
			gruppo: 'Contestazioni'
		},
		{
			chiave: 'croq_comune',
			label: 'Comune',
			aiuto: '',
			gruppo: 'Valori di default per rarita'
		},
		{ chiave: 'croq_raro', label: 'Raro', aiuto: '', gruppo: 'Valori di default per rarita' },
		{
			chiave: 'croq_leggendario',
			label: 'Leggendario',
			aiuto: '',
			gruppo: 'Valori di default per rarita'
		},
		{
			chiave: 'raggio_gps_metri',
			label: 'Raggio checkpoint (metri)',
			aiuto: 'Quanto puoi stare lontano e prendere lo stesso il checkpoint. Sotto i 50 m il GPS del telefono comincia a fare i capricci.',
			gruppo: 'GPS'
		}
	];

	const gruppi = [...new Set(CAMPI.map((c) => c.gruppo))];

	let valori = $state<Record<string, number>>({});
	let originali = $state<Record<string, number>>({});
	let salvando = $state(false);
	let salvato = $state(false);
	let errore = $state<string | null>(null);

	const cambiati = $derived(
		Object.keys(valori).filter((k) => valori[k] !== originali[k])
	);

	onMount(async () => {
		try {
			originali = await caricaConfig();
			valori = { ...originali };
		} catch (e) {
			errore = messaggioErrore(e);
		}
	});

	async function salva() {
		salvando = true;
		errore = null;
		try {
			await salvaConfig(Object.fromEntries(cambiati.map((k) => [k, valori[k]])));
			originali = { ...valori };
			salvato = true;
			setTimeout(() => (salvato = false), 2500);
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			salvando = false;
		}
	}
</script>

<div class="stack">
	{#each gruppi as g (g)}
		<Finestra titolo={g} variante={g === 'Contestazioni' ? 'navy' : 'blue'}>
			<div class="campi">
				{#each CAMPI.filter((c) => c.gruppo === g) as c (c.chiave)}
					<div class="campo">
						<label class="field-label" for={c.chiave}>{c.label}</label>
						<input
							id={c.chiave}
							class="field t-num"
							type="number"
							min="0"
							bind:value={valori[c.chiave]}
						/>
						{#if c.aiuto}<p class="t-small t-muted">{c.aiuto}</p>{/if}
					</div>
				{/each}
			</div>
		</Finestra>
	{/each}

	<Finestra titolo="Nota" variante="orange" bottoni={false}>
		<p class="t-small">
			I valori di default per rarita' si applicano solo agli elementi nuovi: quelli gia' a
			database tengono il valore che hanno. Anche le contestazioni gia' aperte restano alle
			regole con cui sono nate.
		</p>
	</Finestra>

	{#if errore}<p class="errore t-small">{errore}</p>{/if}

	<div class="salva">
		<button class="btn btn--primary btn--lg" onclick={salva} disabled={!cambiati.length || salvando}>
			{salvando ? 'Salvo…' : cambiati.length ? `Salva ${cambiati.length} modifiche` : 'Niente da salvare'}
		</button>
		{#if salvato}<span class="ok t-label">Salvato</span>{/if}
	</div>
</div>

<style>
	.campi {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
		gap: var(--space-3);
	}

	.campo {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.salva {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		position: sticky;
		bottom: var(--space-3);
	}

	.ok {
		color: var(--green);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
