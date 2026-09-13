<script lang="ts">
	import { LIMITE, pubblica } from '$lib/db/oversharing';
	import { profilo } from '$lib/state/profilo.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Avatar from './Avatar.svelte';

	interface Props {
		onFatto?: () => void;
	}

	let { onFatto }: Props = $props();

	let testo = $state('');
	let inInvio = $state(false);
	let errore = $state<string | null>(null);

	const rimasti = $derived(LIMITE - testo.length);
	const pronto = $derived(testo.trim().length > 0 && rimasti >= 0 && !inInvio);

	async function overshara() {
		if (!pronto) return;
		inInvio = true;
		errore = null;
		try {
			await pubblica(testo.trim());
			testo = '';
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
			<textarea
				class="field grow"
				rows="2"
				maxlength={LIMITE + 40}
				enterkeyhint="done"
				bind:value={testo}
				placeholder="attacca un treno"
				aria-label="attacca un treno"
			></textarea>
		</div>

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

	.comp__riga textarea {
		resize: none;
		min-height: 2.6rem;
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
