<script lang="ts">
	import { onMount } from 'svelte';
	import { cambiaPassword, creaAccount, eliminaUtente, passwordACaso, salvaUtente } from '$lib/db/admin';
	import { annullaScambio, tuttiGliScambi } from '$lib/db/admin';
	import { profilo } from '$lib/state/profilo.svelte';
	import { tempoRelativo } from '$lib/game/rules';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import Foglio from '$lib/components/Foglio.svelte';
	import type { Transfer, User } from '$lib/types';

	type ScambioEsteso = Transfer & { mittente: { nome: string }; destinatario: { nome: string } };

	let modifica = $state<Partial<User> | null>(null);
	let salvando = $state(false);
	let erroreForm = $state<string | null>(null);
	let scambi = $state<ScambioEsteso[]>([]);
	let errore = $state<string | null>(null);

	const COLORI = ['#F0552B', '#2B5ED0', '#35B79A', '#8B5CF6', '#D93B32', '#C98A18', '#4A5578'];

	async function rileggi() {
		await profilo.carica();
		try {
			scambi = (await tuttiGliScambi()) as unknown as ScambioEsteso[];
		} catch (e) {
			errore = messaggioErrore(e);
		}
	}

	onMount(rileggi);

	async function salva() {
		if (!modifica?.nome?.trim()) {
			erroreForm = 'Il nome serve.';
			return;
		}
		salvando = true;
		erroreForm = null;
		try {
			await salvaUtente({ ...(modifica as User), nome: modifica.nome.trim() });
			modifica = null;
			await rileggi();
		} catch (e) {
			erroreForm = messaggioErrore(e);
		} finally {
			salvando = false;
		}
	}

	async function elimina(u: User) {
		if (!confirm(`Elimino ${u.nome}? Spariscono anche le sue catture e i suoi scambi.`)) return;
		try {
			await eliminaUtente(u.id);
			await rileggi();
		} catch (e) {
			errore = messaggioErrore(e);
		}
	}

	/* --- account nuovi ----------------------------------------------------- */
	let nuovo = $state({ nome: '', password: '', is_admin: false, sola_lettura: false, nascosto: false });
	let creando = $state(false);
	let esitoAccount = $state<{ testo: string; male: boolean } | null>(null);

	async function creaIlNuovo() {
		creando = true;
		esitoAccount = null;
		try {
			await creaAccount({ ...nuovo, nome: nuovo.nome.trim() });
			esitoAccount = { testo: `Account "${nuovo.nome.trim()}" creato.`, male: false };
			nuovo = { nome: '', password: '', is_admin: false, sola_lettura: false, nascosto: false };
			await rileggi();
		} catch (e) {
			esitoAccount = { testo: e instanceof Error ? e.message : String(e), male: true };
		} finally {
			creando = false;
		}
	}

	/* --- cambio password --------------------------------------------------- */
	// Aperta su un giocatore per volta: la password nuova resta visibile finche'
	// il riquadro e' aperto, cosi' la si puo' leggere a chi la deve usare.
	let cambioAperto = $state<string | null>(null);
	let nuovaPassword = $state('');
	let cambiando = $state(false);
	let esitoPassword = $state<{ testo: string; male: boolean } | null>(null);

	function apriCambio(id: string) {
		cambioAperto = cambioAperto === id ? null : id;
		nuovaPassword = '';
		esitoPassword = null;
	}

	async function confermaCambio(u: User) {
		cambiando = true;
		esitoPassword = null;
		try {
			await cambiaPassword(u.id, nuovaPassword);
			esitoPassword = {
				testo: `Password di ${u.nome} cambiata. Passagliela adesso: non si rilegge.`,
				male: false
			};
		} catch (e) {
			esitoPassword = { testo: e instanceof Error ? e.message : String(e), male: true };
		} finally {
			cambiando = false;
		}
	}
</script>

<div class="stack">
	<Finestra titolo="Nuovo account" variante="orange">
		<div class="stack">
			<p class="t-small">
				Nessuno si iscrive da solo: gli account li crei tu e la password la passi a
				voce. Si entra con il nome utente — l'email non esiste, la costruisce l'app.
			</p>

			<div class="campi-account">
				<label class="campo">
					<span class="t-label">Nome utente</span>
					<input class="field" bind:value={nuovo.nome} autocapitalize="words" />
				</label>
				<label class="campo">
					<span class="t-label">Password (almeno 8)</span>
					<input class="field" bind:value={nuovo.password} />
				</label>
			</div>

			<div class="spunte">
				<label><input type="checkbox" bind:checked={nuovo.is_admin} /> <span class="t-small">admin</span></label>
				<label>
					<input
						type="checkbox"
						bind:checked={nuovo.sola_lettura}
						onchange={() => (nuovo.nascosto = nuovo.sola_lettura)}
					/>
					<span class="t-small">solo lettura</span>
				</label>
				<label><input type="checkbox" bind:checked={nuovo.nascosto} /> <span class="t-small">fuori classifica</span></label>
			</div>

			{#if esitoAccount}
				<p class="t-small" class:esito--male={esitoAccount.male}>{esitoAccount.testo}</p>
			{/if}

			<button
				class="btn btn--primary"
				disabled={creando || nuovo.nome.trim().length < 2 || nuovo.password.length < 8}
				onclick={creaIlNuovo}
			>
				{creando ? 'Creo…' : 'Crea account'}
			</button>
		</div>
	</Finestra>

	<Finestra titolo="Giocatori" variante="navy">
		<ul class="lista">
			{#each profilo.utenti as u (u.id)}
				<li class="riga">
					<Avatar utente={u} dimensione="lg" />
					<div class="grow">
						<p class="nome">
							{u.nome}
							{#if u.is_admin}<span class="badge">admin</span>{/if}
						</p>
						<p class="t-small t-muted">✦ {profilo.saldoDi(u.id)}</p>
					</div>
					<div class="azioni">
						<button class="btn btn--sm" onclick={() => (modifica = { ...u })}>Modifica</button>
						<button
							class="btn btn--sm"
							class:btn--primary={cambioAperto === u.id}
							onclick={() => apriCambio(u.id)}
						>
							Password
						</button>
						<button class="btn btn--sm btn--danger" onclick={() => elimina(u)}>×</button>
					</div>
				</li>

				{#if cambioAperto === u.id}
					<li class="cambio">
						<input
							class="field grow"
							bind:value={nuovaPassword}
							placeholder="nuova password, almeno 8 caratteri"
							autocomplete="off"
							spellcheck="false"
						/>
						<button class="btn btn--sm" onclick={() => (nuovaPassword = passwordACaso())}>
							Generane una
						</button>
						<button
							class="btn btn--sm btn--ok"
							disabled={cambiando || nuovaPassword.length < 8}
							onclick={() => confermaCambio(u)}
						>
							{cambiando ? 'Cambio…' : 'Cambia'}
						</button>
						{#if esitoPassword}
							<p class="t-small esito" class:esito--male={esitoPassword.male}>
								{esitoPassword.testo}
							</p>
						{/if}
					</li>
				{/if}
			{/each}
		</ul>

		<button
			class="btn btn--primary"
			onclick={() => (modifica = { nome: '', colore: '#4A5578', is_admin: false })}
		>
			+ Aggiungi giocatore
		</button>

		<p class="t-small t-muted nota">
			Gli avatar non si caricano da qui: si lascia un PNG in src/assets/avatars/
			chiamato come il giocatore e compare da solo. Chi non ce l'ha mostra le
			iniziali sul colore scelto.
		</p>
	</Finestra>

	<Finestra titolo="Scambi di Croquembouche" variante="blue">
		{#if !scambi.length}
			<p class="t-small t-muted">Nessuno scambio, per ora.</p>
		{:else}
			<ul class="scambi">
				{#each scambi as s (s.id)}
					<li class="scambio" class:scambio--ko={s.annullato}>
						<span class="grow t-small">
							<strong>{s.mittente.nome}</strong> → <strong>{s.destinatario.nome}</strong>
							<span class="imp t-num">✦ {s.importo}</span>
							{#if s.causale}<span class="t-muted"> — {s.causale}</span>{/if}
						</span>
						<span class="t-small t-muted">{tempoRelativo(s.created_at)}</span>
						<button
							class="btn btn--sm"
							onclick={async () => {
								await annullaScambio(s.id, !s.annullato);
								await rileggi();
							}}
						>
							{s.annullato ? 'Ripristina' : 'Annulla'}
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</Finestra>

	{#if errore}<p class="errore t-small">{errore}</p>{/if}
</div>

<Foglio
	aperto={!!modifica}
	titolo={modifica?.id ? 'Modifica giocatore' : 'Nuovo giocatore'}
	onChiudi={() => (modifica = null)}
>
	{#if modifica}
		<div class="stack">
			<div class="field-row">
				<label class="field-label" for="u-nome">Nome</label>
				<input id="u-nome" class="field" bind:value={modifica.nome} />
			</div>

			<div>
				<p class="field-label">Colore (per le iniziali, se non ha un avatar)</p>
				<div class="colori">
					{#each COLORI as c (c)}
						<button
							class="colore"
							class:colore--on={modifica.colore === c}
							style:background={c}
							aria-label={c}
							onclick={() => modifica && (modifica.colore = c)}
						></button>
					{/each}
				</div>
			</div>

			<label class="check">
				<input type="checkbox" bind:checked={modifica.is_admin} />
				<span>Amministratore — vede questo pannello</span>
			</label>

			{#if erroreForm}<p class="errore t-small">{erroreForm}</p>{/if}

			<div class="due">
				<button class="btn" onclick={() => (modifica = null)}>Annulla</button>
				<button class="btn btn--primary" onclick={salva} disabled={salvando}>
					{salvando ? 'Salvo…' : 'Salva'}
				</button>
			</div>
		</div>
	{/if}
</Foglio>

<style>
	.cambio {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 6px;
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	.cambio .field {
		/* La password nuova si legge: serve poterla dettare a chi la usera'. */
		font-family: var(--font-mono, monospace);
		min-width: 220px;
	}

	.esito {
		flex-basis: 100%;
	}

	.esito--male {
		color: var(--red);
		font-weight: 700;
	}

	.campi-account {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: var(--space-2);
	}

	.campo {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.spunte {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.spunte label {
		display: flex;
		align-items: center;
		gap: 5px;
	}

	.esito--male {
		color: var(--red);
		font-weight: 700;
	}

	.lista {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin-bottom: var(--space-3);
	}

	.riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		flex-wrap: wrap;
	}

	.nome {
		font-weight: 700;
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.azioni {
		display: flex;
		gap: 4px;
	}

	.nota {
		margin-top: var(--space-3);
	}

	.scambi {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.scambio {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: 5px;
		border-bottom: 1px solid rgba(22, 27, 61, 0.15);
		flex-wrap: wrap;
	}

	.scambio--ko {
		opacity: 0.5;
		text-decoration: line-through;
	}

	.imp {
		background: var(--yellow);
		border: var(--border-thin) solid var(--navy);
		padding: 0 4px;
		font-weight: 700;
	}

	.colori {
		display: flex;
		gap: var(--space-2);
		flex-wrap: wrap;
	}

	.colore {
		width: 38px;
		height: 38px;
		border: var(--border) solid var(--navy);
		cursor: pointer;
	}

	.colore--on {
		box-shadow: 0 0 0 3px var(--yellow);
	}

	.check {
		display: flex;
		gap: var(--space-2);
		align-items: center;
		font-size: 0.875rem;
	}

	.check input {
		width: 20px;
		height: 20px;
		accent-color: var(--orange);
	}

	.due {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}
</style>
