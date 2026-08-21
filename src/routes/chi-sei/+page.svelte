<script lang="ts">
	import { goto } from '$app/navigation';
	import { profilo } from '$lib/state/profilo.svelte';
	import Avatar from '$lib/components/Avatar.svelte';
	import Finestra from '$lib/components/Finestra.svelte';
	import type { User } from '$lib/types';

	function scegli(u: User) {
		profilo.scegli(u);
		void goto('/');
	}
</script>

<svelte:head><title>Chi sei? — Pachino Express</title></svelte:head>

<div class="scelta">
	<div class="logo">
		<img src="/icon-192.png" alt="" width="72" height="72" class="pixel" />
		<h1>Pachino Express</h1>
		<p class="t-small t-muted">Sei arrivato. Adesso dicci chi sei.</p>
	</div>

	<Finestra titolo="Chi sei?" variante="orange">
		{#if !profilo.pronto}
			<p class="t-label t-muted">Carico i profili…</p>
		{:else if profilo.errore}
			<p>Non riesco a leggere i profili.</p>
			<p class="t-small t-muted">{profilo.errore}</p>
		{:else}
			<ul class="lista">
				{#each profilo.utenti as u (u.id)}
					<li>
						<button class="riga" onclick={() => scegli(u)}>
							<Avatar utente={u} dimensione="lg" />
							<span class="grow nome">{u.nome}</span>
							{#if u.is_admin}<span class="badge">admin</span>{/if}
							<span class="freccia" aria-hidden="true">▸</span>
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</Finestra>

	<p class="nota t-small t-muted">
		Nessuna password: il telefono si ricorda la scelta. Se sbagli, tocca il tuo avatar in alto.
	</p>

	<button
		class="btn btn--sm rivedi"
		onclick={() => {
			localStorage.removeItem('pachidex:giro-fatto');
			void goto('/');
		}}
	>
		Rivedi come funziona
	</button>
</div>

<style>
	.scelta {
		padding: var(--space-4);
		padding-top: calc(var(--space-6) + env(safe-area-inset-top));
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		min-height: 100dvh;
		justify-content: center;
	}

	.logo {
		text-align: center;
	}

	.logo img {
		margin: 0 auto var(--space-2);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow);
	}

	.lista {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.riga {
		width: 100%;
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
		cursor: pointer;
		text-align: left;
	}

	.riga:active {
		transform: translate(3px, 3px);
		box-shadow: none;
	}

	.nome {
		font-size: 1.125rem;
		font-weight: 700;
	}

	.freccia {
		color: var(--navy-soft);
	}

	.nota {
		text-align: center;
	}

	.rivedi {
		align-self: center;
	}
</style>
