<script lang="ts">
	import { goto } from '$app/navigation';
	import { profilo } from '$lib/state/profilo.svelte';
	import Finestra from '$lib/components/Finestra.svelte';

	let nome = $state('');
	let password = $state('');
	let inCorso = $state(false);
	let errore = $state<string | null>(null);

	const pronto = $derived(nome.trim().length > 1 && password.length > 0);

	async function entra(e: Event) {
		e.preventDefault();
		if (!pronto || inCorso) return;
		inCorso = true;
		errore = null;
		errore = await profilo.entra(nome, password);
		inCorso = false;
		if (!errore) await goto('/');
	}
</script>

<svelte:head><title>Entra — Pachino Express</title></svelte:head>

<div class="ingresso">
	<div class="logo">
		<img src="/icon-192.png" alt="" width="72" height="72" class="pixel" />
		<h1>Pachino Express</h1>
	</div>

	<Finestra titolo="Entra" variante="orange">
		<form class="stack" onsubmit={entra}>
			<label class="campo">
				<span class="t-label">Nome utente</span>
				<input
					class="field"
					bind:value={nome}
					autocomplete="username"
					autocapitalize="none"
					autocorrect="off"
					spellcheck="false"
					enterkeyhint="next"
					required
				/>
			</label>

			<label class="campo">
				<span class="t-label">Password</span>
				<input
					class="field"
					type="password"
					bind:value={password}
					autocomplete="current-password"
					enterkeyhint="go"
					required
				/>
			</label>

			{#if errore}
				<p class="errore t-small">{errore}</p>
			{/if}

			<button class="btn btn--primary btn--lg btn--block" type="submit" disabled={!pronto || inCorso}>
				{inCorso ? 'Entro…' : 'Entra'}
			</button>
		</form>
	</Finestra>

	<p class="nota t-small t-muted">
		Non ci si iscrive da soli: gli account li crea chi tiene il gioco. Se hai perso
		la password, chiedila a lui.
	</p>
</div>

<style>
	.ingresso {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4);
		max-width: 380px;
		margin: 0 auto;
		min-height: 80dvh;
		justify-content: center;
	}

	.logo {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2);
		text-align: center;
	}

	h1 {
		font-size: 1.375rem;
	}

	.campo {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.errore {
		background: var(--red);
		color: var(--paper);
		padding: var(--space-2);
	}

	.nota {
		text-align: center;
	}
</style>
