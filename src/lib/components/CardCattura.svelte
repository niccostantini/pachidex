<script lang="ts">
	import { tempoRelativo } from '$lib/game/rules';
	import { spezzaMenzioni } from '$lib/game/tag';
	import { profilo } from '$lib/state/profilo.svelte';
	import { alternaLike } from '$lib/db/feed';
	import Avatar from './Avatar.svelte';
	import Scatto from './Scatto.svelte';
	import Icona from './Icona.svelte';
	import Rarita from './Rarita.svelte';
	import Lente from './Lente.svelte';
	import type { PostCattura } from '$lib/types';

	interface Props {
		post: PostCattura;
		onContesta?: (post: PostCattura) => void;
		compatta?: boolean;
	}

	let { post, onContesta, compatta = false }: Props = $props();

	/**
	 * Il like si vede subito, ma la verita' resta quella del server: si tiene
	 * solo lo scarto fra i due. Quando il realtime porta il conteggio
	 * aggiornato lo scarto si azzera da solo, senza doverlo risincronizzare.
	 */
	let ottimistico = $state<{ id: string; mio: boolean } | null>(null);

	/** La foto si apre dentro l'app: un link a un'altra origine farebbe
	    uscire iOS dalla PWA e comparire le barre di Safari. */
	let ingrandita = $state(false);

	const mioLike = $derived(
		ottimistico?.id === post.id ? ottimistico.mio : post.ho_messo_like
	);
	const likes = $derived(
		post.likes + (mioLike === post.ho_messo_like ? 0 : mioLike ? 1 : -1)
	);

	const mia = $derived(post.user_id === profilo.io?.id);
	// Anche i posti si contestano: il GPS dimostra che c'eri, non che la foto
	// valga qualcosa. Essere a Vendicari e fotografarsi il pollice non e'
	// catturare Vendicari.
	const contestabile = $derived(
		!compatta && !mia && post.stato === 'valido' && !!profilo.io
	);
	const handle = $derived('@' + post.autore.nome.toLowerCase());

	async function like() {
		if (!profilo.io) return;
		const prima = mioLike;
		ottimistico = { id: post.id, mio: !prima };
		try {
			await alternaLike(post.id, profilo.io.id, prima);
		} catch {
			ottimistico = null;
		}
	}
</script>

<article
	class="post"
	class:post--invalidata={post.stato === 'invalidato'}
	class:holo={post.item.rarita === 'leggendario' && post.stato !== 'invalidato'}
>
	<div class="post__testa">
		<Avatar utente={post.autore} />
		<div class="grow">
			<div class="post__chi">
				<strong>{post.autore.nome}</strong>
				<span class="t-small t-muted">{handle}</span>
				<span class="t-small t-muted">·</span>
				<span class="t-small t-muted">{tempoRelativo(post.timestamp)}</span>
			</div>
			<div class="post__cosa t-small">
				{#if post.stato === 'invalidato'}
					<s>ha catturato</s>
				{:else}
					ha catturato
				{/if}
				<a href="/pachidex/{post.item_id}"><strong>{post.item.nome}</strong></a>
			</div>
		</div>
	</div>

	<div class="post__meta">
		<Rarita rarita={post.item.rarita} croquembouche={post.item.croquembouche} />
		{#if post.item.validazione === 'foto_gps'}
			<span class="badge badge--gps">GPS ✓</span>
		{/if}
		{#if post.item.ripetibile}
			<span class="badge">ripetibile</span>
		{/if}
		{#if post.stato === 'invalidato'}
			<span class="badge badge--ko">invalidata</span>
		{:else if post.stato === 'in_contestazione'}
			<span class="badge badge--warn">sotto contestazione</span>
		{/if}
	</div>

	<button class="post__foto" onclick={() => (ingrandita = true)} aria-label="Ingrandisci la foto">
		<Scatto src={post.foto_url} alt={post.item.nome} />
		{#if post.primato && post.stato !== 'invalidato'}
			<!-- Primo del gruppo a trovarlo: un primato si vede una volta sola,
			     tanto vale che si veda bene. -->
			<span class="primo">Primo!</span>
		{/if}
	</button>

	{#if post.nota}
		<p class="post__nota">
			{#each spezzaMenzioni(post.nota, profilo.utenti) as pezzo, i (i)}
				{#if pezzo.utente}
					<span class="menzione">{pezzo.testo}</span>
				{:else}{pezzo.testo}{/if}
			{/each}
		</p>
	{/if}

	{#if post.taggati.length}
		<!-- Chi altro prende i Croquembouche di questa foto. -->
		<div class="post__taggati">
			<span class="t-label t-muted">Vale anche per</span>
			{#each post.taggati as u (u.id)}
				<span class="tag">
					<Avatar utente={u} dimensione="sm" />
					<span>{u.nome}</span>
				</span>
			{/each}
		</div>
	{/if}

	{#if !compatta}
		<div class="post__azioni">
			<button class="azione" class:azione--on={mioLike} onclick={like} disabled={!profilo.io}>
				<!-- Niente "sfondo": serve solo a ritagliare i buchi, e questa
				     scritta non ne ha. Il colore lo eredita dal pulsante, che
				     diventa bianco su rosso quando il like e' tuo. -->
				<Icona nome="chic" dimensione={15} />
				<span class="t-num">{likes}</span>
			</button>

			{#if contestabile && onContesta}
				<button class="azione azione--contesta" onclick={() => onContesta(post)}>
					<Icona nome="alert" dimensione={14} sfondo="var(--paper)" />
					Contesta
				</button>
			{/if}
		</div>
	{/if}
</article>

<Lente
	src={ingrandita ? post.foto_url : null}
	alt={post.item.nome}
	onChiudi={() => (ingrandita = false)}
/>

<style>
	.post {
		background: var(--paper);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
		padding: var(--space-2);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.post--invalidata {
		opacity: 0.62;
	}

	.post__testa {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
	}

	.post__chi {
		display: flex;
		align-items: baseline;
		gap: 5px;
		flex-wrap: wrap;
		line-height: 1.2;
	}

	.post__cosa a {
		color: inherit;
	}

	.post__meta {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}

	.post__foto {
		display: block;
		line-height: 0;
		position: relative;
		width: 100%;
		padding: 0;
		border: 0;
		background: none;
		cursor: pointer;
	}

	.primo {
		position: absolute;
		top: 8px;
		left: 8px;
		padding: 3px 8px;
		background: var(--yellow);
		color: var(--navy);
		border: var(--border) solid var(--navy);
		box-shadow: 3px 3px 0 rgba(22, 27, 61, 0.5);
		font-size: 0.8125rem;
		font-weight: 700;
		line-height: 1.2;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		/* Storto come un timbro vero, che e' quello che e'. */
		transform: rotate(-6deg);
	}

	.post__nota {
		font-size: 0.9375rem;
	}

	.menzione {
		font-weight: 700;
		color: var(--blue);
	}

	.post__taggati {
		display: flex;
		align-items: center;
		gap: 5px;
		flex-wrap: wrap;
	}

	.tag {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 2px 5px 2px 2px;
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		font-weight: 700;
	}

	.post__azioni {
		display: flex;
		gap: var(--space-2);
		border-top: var(--border-thin) solid rgba(22, 27, 61, 0.18);
		padding-top: var(--space-2);
	}

	.azione {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		padding: 4px 9px;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		cursor: pointer;
		-webkit-tap-highlight-color: transparent;
	}

	.azione:active {
		background: var(--cream);
	}

	.azione--on {
		background: var(--red);
		color: var(--paper);
	}

	.azione--contesta {
		margin-left: auto;
		background: var(--yellow);
	}

	:global(.badge--gps) {
		background: var(--green);
		color: var(--paper);
	}

	:global(.badge--ko) {
		background: var(--red);
		color: var(--paper);
	}

	:global(.badge--warn) {
		background: var(--yellow);
		color: var(--navy);
	}
</style>
