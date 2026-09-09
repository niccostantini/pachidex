<script lang="ts">
	import { onMount } from 'svelte';
	import {
		accendiNotifiche,
		impostaNotifiche,
		statoNotifiche,
		type StatoNotifiche
	} from '$lib/db/admin';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';

	let stato = $state<StatoNotifiche | null>(null);
	let caricando = $state(true);
	let errore = $state<string | null>(null);
	let esito = $state<string | null>(null);

	let appUrl = $state('');
	let segreto = $state('');
	let salvando = $state(false);

	async function rileggi() {
		errore = null;
		try {
			stato = await statoNotifiche();
			appUrl = stato.app_url ?? '';
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricando = false;
		}
	}

	async function agisci(fn: () => Promise<unknown>, detto: string) {
		salvando = true;
		errore = null;
		esito = null;
		try {
			await fn();
			esito = detto;
			// Il segreto sparisce dal campo appena salvato: non si rilegge, e
			// lasciarlo li' darebbe l'impressione che si possa ritrovare.
			segreto = '';
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			salvando = false;
		}
	}

	onMount(rileggi);
</script>

<div class="stack">
	<Finestra titolo="Notifiche" variante="navy">
		<div class="stack">
			{#if caricando}
				<p class="t-label t-muted">Guardo come sta messa…</p>
			{:else if stato}
				<div class="stato">
					<span class="pastiglia" class:pastiglia--ok={stato.configurate}>
						{stato.configurate ? 'configurate' : 'da configurare'}
					</span>
					<span class="pastiglia" class:pastiglia--ok={stato.lavori_accesi}>
						{stato.lavori_accesi ? 'lavori accesi' : 'lavori spenti'}
					</span>
					<span class="pastiglia" class:pastiglia--ok={stato.dispositivi > 0}>
						{stato.dispositivi}
						{stato.dispositivi === 1 ? 'dispositivo' : 'dispositivi'}
					</span>
				</div>

				{#if stato.dispositivi === 0}
					<p class="t-small t-muted">
						Nessuno ha ancora attivato le notifiche dal proprio telefono. Finché la
						lista è vuota non parte niente, per quanto tutto il resto sia a posto.
						Su iPhone funzionano solo con l'app aggiunta alla schermata Home.
					</p>
				{/if}
			{/if}

			{#if errore}<p class="riga-errore t-small">{errore}</p>{/if}
			{#if esito}<p class="riga-ok t-small">{esito}</p>{/if}
		</div>
	</Finestra>

	<Finestra titolo="Come si chiamano" variante="blue">
		<div class="stack">
			<p class="t-small">
				Le notifiche a orario partono dal database, che chiama l'app da fuori: gli
				servono l'indirizzo dove trovarla e un segreto per farsi riconoscere.
			</p>

			<label class="campo">
				<span class="t-label">Indirizzo dell'app</span>
				<input class="field" bind:value={appUrl} placeholder="https://esempio.vercel.app" />
			</label>

			<label class="campo">
				<span class="t-label">Segreto condiviso</span>
				<input
					class="field"
					bind:value={segreto}
					placeholder={stato?.cron_secret_impostato ? 'impostato — scrivi qui per cambiarlo' : 'non ancora impostato'}
					autocomplete="off"
					spellcheck="false"
				/>
			</label>

			<p class="t-small t-muted">
				Il segreto dev'essere <strong>identico</strong> a <code>CRON_SECRET</code> fra le
				variabili d'ambiente su Vercel: se i due non coincidono l'app rifiuta le chiamate
				e le notifiche a orario non arrivano mai. Qui non si rilegge: lasciando il campo
				vuoto resta quello di prima.
			</p>

			<button
				class="btn btn--primary"
				disabled={salvando || !appUrl.trim()}
				onclick={() => agisci(() => impostaNotifiche(appUrl, segreto), 'Configurazione salvata.')}
			>
				{salvando ? 'Salvo…' : 'Salva'}
			</button>
		</div>
	</Finestra>

	<Finestra titolo="Lavori a orario" variante="orange">
		<div class="stack">
			<ul class="lavori t-small">
				<li><strong>Podio serale</strong> — alle 22:30, chi è in testa</li>
				<li><strong>Promemoria di voto</strong> — ogni quarto d'ora, sulle contestazioni aperte</li>
			</ul>

			<p class="t-small t-muted">
				Si spengono insieme. La chiusura delle contestazioni scadute resta accesa
				comunque: è solo database, non disturba nessuno e serve al gioco anche a
				notifiche spente.
			</p>

			{#if stato}
				<button
					class="btn"
					class:btn--danger={stato.lavori_accesi}
					class:btn--ok={!stato.lavori_accesi}
					disabled={salvando}
					onclick={() =>
						agisci(
							() => accendiNotifiche(!stato!.lavori_accesi),
							stato!.lavori_accesi ? 'Lavori spenti.' : 'Lavori accesi.'
						)}
				>
					{stato.lavori_accesi ? 'Spegni' : 'Accendi'}
				</button>
			{/if}
		</div>
	</Finestra>
</div>

<style>
	.stato {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.pastiglia {
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		padding: 3px 8px;
		background: var(--cream);
		color: var(--navy);
		border: var(--border-thin) solid var(--navy);
	}

	.pastiglia--ok {
		background: var(--green);
		color: var(--paper);
	}

	.campo {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.lavori {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.riga-errore {
		background: var(--red);
		color: var(--paper);
		padding: var(--space-2);
	}

	.riga-ok {
		background: var(--green);
		color: var(--paper);
		padding: var(--space-2);
	}
</style>
