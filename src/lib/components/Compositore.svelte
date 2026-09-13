<script lang="ts">
	import { LIMITE, pubblica } from '$lib/db/oversharing';
	import { completaMenzione, estraiTaggati, menzioneInCorso } from '$lib/game/tag';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from './Avatar.svelte';
	import type { User } from '$lib/types';

	interface Props {
		onFatto?: () => void;
	}

	let { onFatto }: Props = $props();

	let testo = $state('');
	let inInvio = $state(false);
	let errore = $state<string | null>(null);

	const rimasti = $derived(LIMITE - testo.length);
	const pronto = $derived(testo.trim().length > 0 && rimasti >= 0 && !inInvio);

	/* --- @menzioni -------------------------------------------------------- */
	/**
	 * Le stesse della didascalia di una cattura, e per una ragione sola: se
	 * l'@ funzionasse in un posto e non nell'altro, l'unico modo per saperlo
	 * sarebbe provarci e vedere che non succede niente.
	 *
	 * Qui pero' non danno Croquembouche a nessuno — sono chiacchiere, non
	 * crediti. Fanno solo squillare il telefono di chi hai nominato, che e'
	 * tutto il motivo per cui si nomina qualcuno.
	 */
	let campo: HTMLTextAreaElement | undefined = $state();
	let cursore = $state(0);

	const menzione = $derived(menzioneInCorso(testo, cursore));

	const candidati = $derived.by(() => {
		if (!menzione) return [];
		const q = menzione.parziale.toLowerCase();
		return profilo.altri.filter((u) => u.nome.toLowerCase().startsWith(q)).slice(0, 5);
	});

	const nominati = $derived(estraiTaggati(testo, profilo.utenti, profilo.io?.id));

	function segnaCursore() {
		cursore = campo?.selectionStart ?? testo.length;
	}

	function scegli(u: User) {
		if (!menzione) return;
		const esito = completaMenzione(testo, menzione.inizio, cursore, u.nome);
		testo = esito.testo;
		cursore = esito.cursore;
		// Il cursore va rimesso a mano: il valore cambia sotto i piedi al campo.
		requestAnimationFrame(() => {
			campo?.focus();
			campo?.setSelectionRange(esito.cursore, esito.cursore);
		});
	}

	async function overshara() {
		if (!pronto) return;
		inInvio = true;
		errore = null;
		try {
			await pubblica(testo.trim());
			testo = '';
			cursore = 0;
			onFatto?.();
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			inInvio = false;
		}
	}
</script>

{#if profilo.io && !profilo.soloSguardo}
	<div class="comp">
		<div class="comp__riga">
			<Avatar utente={profilo.io} dimensione="sm" />
			<div class="grow campo">
				<textarea
					class="field"
					rows="2"
					maxlength={LIMITE + 40}
					enterkeyhint="done"
					bind:value={testo}
					bind:this={campo}
					oninput={segnaCursore}
					onclick={segnaCursore}
					onkeyup={segnaCursore}
					autocomplete="off"
					placeholder="attacca un treno"
					aria-label="attacca un treno"
				></textarea>

				{#if candidati.length}
					<ul class="menu">
						{#each candidati as u (u.id)}
							<li>
								<button type="button" class="menu__voce" onclick={() => scegli(u)}>
									<Avatar utente={u} dimensione="sm" />
									<span>{u.nome}</span>
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			</div>
		</div>

		{#if nominati.length}
			<p class="nominati t-small t-muted">
				Squilla il telefono a
				{#each nominati as u, i (u.id)}<strong>{u.nome}</strong>{i < nominati.length - 1
						? ', '
						: ''}{/each}. Niente Croquembouche: è solo per dirglielo.
			</p>
		{/if}

		<div class="comp__fondo">
			<!--
				Il contatore compare solo quando serve.
				Un numero che parte da 280 e scende a ogni lettera trasforma una
				battuta in un compito: sotto i quaranta rimasti diventa
				un'informazione, prima e' solo un occhio addosso.
			-->
			{#if rimasti <= 40}
				<span class="conta t-num t-small" class:conta--troppo={rimasti < 0}>{rimasti}</span>
			{/if}
			<span class="grow"></span>
			{#if errore}<span class="t-small errore">{errore}</span>{/if}
			<button class="btn btn--primary" onclick={overshara} disabled={!pronto}>
				{inInvio ? 'Esce…' : 'Overshara'}
			</button>
		</div>
	</div>
{/if}

<style>
	.comp {
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		box-shadow: var(--shadow-sm);
		padding: var(--space-2);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.comp__riga {
		display: flex;
		align-items: flex-start;
		gap: 6px;
	}

	.campo {
		position: relative;
	}

	.campo textarea {
		width: 100%;
		resize: none;
		min-height: 2.6rem;
	}

	/*
	 * Sotto il campo, non sopra.
	 *
	 * L'avevo aperto verso l'alto pensando alla tastiera del telefono, ma il
	 * compositore sta in cima al feed: verso l'alto il menu finiva sotto la
	 * barra dell'app, e si vedeva mezza riga. Sotto invece resta a un terzo
	 * dello schermo, cioe' ben sopra la tastiera.
	 */
	.menu {
		position: absolute;
		left: 0;
		right: 0;
		top: calc(100% + 2px);
		z-index: 5;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		box-shadow: var(--shadow-sm);
		max-height: 180px;
		overflow-y: auto;
	}

	.menu__voce {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		width: 100%;
		padding: 5px var(--space-2);
		background: transparent;
		border: 0;
		font: inherit;
		text-align: left;
		cursor: pointer;
	}

	.menu__voce:active {
		background: var(--cream);
	}

	.nominati {
		line-height: 1.3;
	}

	.comp__fondo {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.conta {
		color: var(--navy-soft);
		font-weight: 700;
	}

	.conta--troppo {
		color: var(--orange-dark);
	}

	.errore {
		color: var(--orange-dark);
	}
</style>
