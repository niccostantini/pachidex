<script lang="ts">
	import { TITOLI, type VoceTitolo } from '$lib/db/titoli';
	import { profilo } from '$lib/state/profilo.svelte';
	import Avatar from './Avatar.svelte';

	interface Props {
		titoli: VoceTitolo[];
	}

	let { titoli }: Props = $props();

	/**
	 * Un titolo puo' essere di piu' di una persona.
	 *
	 * A sette pietanze pari non c'e' niente da soffiare a nessuno: ci sei gia'
	 * anche tu. Prima la bacheca ne mostrava una sola — quella arrivata prima —
	 * e poi la premiazione dava la coccarda a tutte e due: due settimane a
	 * leggere una cosa e l'ultimo giorno un'altra. La sfida resta uguale, chi
	 * e' a sei ne cattura una ed entra: e adesso entrarci si vede.
	 */
	const perTitolo = $derived.by(() => {
		const m = new Map<string, VoceTitolo[]>();
		for (const t of titoli) m.set(t.titolo, [...(m.get(t.titolo) ?? []), t]);
		return m;
	});

	const chiDi = (voci: VoceTitolo[]) =>
		voci.map((v) => profilo.utenti.find((u) => u.id === v.user_id)).filter((u) => u !== undefined);

	/** «Nina», «Ciccio e Nina», «Ciccio, Nina e Turi». */
	function elenca(nomi: string[]) {
		if (nomi.length <= 1) return nomi[0] ?? '';
		return `${nomi.slice(0, -1).join(', ')} e ${nomi[nomi.length - 1]}`;
	}
</script>

<ul class="bacheca">
	{#each TITOLI as t (t.titolo)}
		{@const vinto = perTitolo.get(t.titolo) ?? []}
		{@const chi = chiDi(vinto)}
		{@const mio = chi.some((u) => u.id === profilo.io?.id)}
		<li class="riga" class:riga--mia={mio}>
			<div class="grow">
				<p class="titolo">{t.nome}</p>
				<p class="come t-small t-muted">{t.come}</p>
			</div>

			{#if chi.length}
				<div class="chi">
					<div class="facce">
						{#each chi as u (u.id)}
							<Avatar utente={u} dimensione="sm" />
						{/each}
					</div>
					<div class="chi__testo">
						<span class="chi__nome t-small">{elenca(chi.map((u) => u.nome))}</span>
						<span class="chi__conta t-num t-small">{t.unita(vinto[0].conteggio)}</span>
						{#if chi.length > 1}
							<span class="pari t-label">a pari merito</span>
						{/if}
					</div>
				</div>
			{:else}
				<!-- Nessuna l'ha ancora preso: si dice, perche' un titolo libero
				     e' un invito e vale piu' di una riga vuota. -->
				<span class="palio t-label">in palio</span>
			{/if}
		</li>
	{/each}
</ul>

<style>
	.bacheca {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.riga {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
	}

	/* Il tuo si vede: e' quello che ti possono soffiare. */
	.riga--mia {
		background: var(--yellow);
		box-shadow: var(--shadow-sm);
	}

	.titolo {
		font-weight: 700;
		line-height: 1.15;
	}

	.come {
		margin-top: 1px;
	}

	.chi {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-shrink: 0;
	}

	/*
	 * Le facce si sovrappongono di un paio di pixel invece di allinearsi: tre
	 * avatar in fila su un telefono mangiano tutta la riga e spingono il nome
	 * del titolo a capo. Sovrapposte restano un gruppetto, che e' anche cio'
	 * che vogliono dire.
	 */
	.facce {
		display: flex;
		flex-shrink: 0;
	}

	.facce > :global(* + *) {
		margin-left: -6px;
	}

	.chi__testo {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		line-height: 1.2;
	}

	.chi__nome {
		font-weight: 700;
		text-align: right;
	}

	.chi__conta {
		color: var(--orange-dark);
		font-weight: 700;
	}

	.pari {
		color: var(--navy-soft);
	}

	.palio {
		flex-shrink: 0;
		color: var(--navy);
		background: var(--paper);
		border: var(--border-thin) dashed var(--navy);
		padding: 3px 7px;
	}
</style>
