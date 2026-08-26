<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { caricaDex, caricaConfig, mieCatture, type MiaVoce } from '$lib/db/dex';
	import { checkpointVicini, formattaDistanza, posizioneAttuale, type Posizione } from '$lib/game/geo';
	import { comprimiFoto, anteprima } from '$lib/game/image';
	import { CATEGORIE, etichettaCategoria } from '$lib/game/rules';
	import { profilo } from '$lib/state/profilo.svelte';
	import { coda } from '$lib/state/coda.svelte';
	import { messaggioErrore } from '$lib/supabase';
	import Finestra from '$lib/components/Finestra.svelte';
	import Rarita from '$lib/components/Rarita.svelte';
	import FestaCattura from '$lib/components/FestaCattura.svelte';
	import { riferimentoDi } from '$lib/riferimenti';
	import { completaMenzione, estraiTaggati, menzioneInCorso } from '$lib/game/tag';
	import Avatar from '$lib/components/Avatar.svelte';
	import type { User, VoceDex } from '$lib/types';

	let voci = $state<VoceDex[]>([]);
	let mie = $state<Map<string, MiaVoce>>(new Map());
	let config = $state<Record<string, number>>({});
	let pos = $state<Posizione | null>(null);
	let erroreGps = $state<string | null>(null);
	let caricamento = $state(true);

	let scelta = $state<VoceDex | null>(null);
	/**
	 * true appena il giocatore mette bocca sulla scelta: la cambia, la azzera,
	 * ne prende un'altra dall'elenco o da un checkpoint li' accanto.
	 *
	 * Da quel momento il GPS non tocca piu' niente. Senza questo flag il
	 * pulsante Cambia sembrava rotto: azzerava la scelta, l'effetto qui sotto
	 * ripartiva — legge scelta, quindi si riattiva appena torna null — e
	 * rimetteva il checkpoint un istante dopo. Chi aveva visto una folaga
	 * standosene dentro il raggio di Marianelli non riusciva a registrarla.
	 */
	let sceltaMia = $state(false);
	let cerca = $state('');
	let nota = $state('');
	let file = $state<File | null>(null);
	let urlAnteprima = $state<string | null>(null);
	/**
	 * Da dove arriva la foto. Serve perche' i checkpoint vanno fotografati sul
	 * posto: l'attributo capture apre la fotocamera ma non lascia traccia di
	 * cio' che e' successo, quindi la provenienza la si ricorda qui.
	 */
	let origine = $state<'fotocamera' | 'galleria' | null>(null);
	let inInvio = $state(false);
	let errore = $state<string | null>(null);
	/** L'elemento appena catturato, mostrato dalla festa prima di tornare al feed. */
	let festeggia = $state<VoceDex | null>(null);
	/** Si arriva qui dalla fine del giro guidato: c'e' un rito da compiere. */
	const benvenuto = $derived(page.url.searchParams.get('benvenuto') === '1');

	const raggio = $derived(config.raggio_gps_metri ?? 100);

	// La foto di riferimento dell'elemento scelto, se ne ha una.
	const riferimento = $derived(riferimentoDi(scelta?.riferimento));

	/** I posti si fotografano sul momento: niente galleria. */
	const soloFotocamera = $derived(scelta?.validazione === 'foto_gps');

	/**
	 * La foto si puo' scegliere prima dell'elemento, e un checkpoint vicino si
	 * preseleziona da solo: puo' quindi capitare di ritrovarsi un posto con
	 * una foto presa dalla galleria. Qui si intercetta.
	 */
	const fotoNonAmmessa = $derived(soloFotocamera && origine === 'galleria');

	const vicini = $derived(pos ? checkpointVicini(voci, pos, raggio) : []);
	const dentroRaggio = $derived(vicini.filter((v) => v.dentro));

	/** Un item non ripetibile gia' preso non si ripropone. */
	function giaPresa(v: VoceDex) {
		return !v.ripetibile && mie.has(v.item_id);
	}

	const risultati = $derived.by(() => {
		const q = cerca.trim().toLowerCase();
		return voci
			.filter((v) => v.validazione === 'foto')
			.filter((v) => !q || v.nome.toLowerCase().includes(q))
			.sort((a, b) => {
				const ga = giaPresa(a) ? 1 : 0;
				const gb = giaPresa(b) ? 1 : 0;
				return ga - gb || a.nome.localeCompare(b.nome);
			})
			.slice(0, 40);
	});

	onMount(async () => {
		try {
			const [d, c] = await Promise.all([caricaDex(), caricaConfig()]);
			voci = d;
			config = c;
			if (profilo.io) mie = await mieCatture(profilo.io.id);
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			caricamento = false;
		}

		try {
			pos = await posizioneAttuale();
		} catch (e) {
			erroreGps = e instanceof Error ? e.message : String(e);
		}
	});

	// Un checkpoint a portata si preseleziona da solo: e' il caso piu' comune
	// ed evita di far cercare a mano una cosa che il telefono gia' sa.
	// Il selfie di benvenuto ha la precedenza: e' il motivo per cui si e' qui.
	$effect(() => {
		if (sceltaMia || scelta) return;
		if (benvenuto) {
			const rito = voci.find((v) => /inaugurale/i.test(v.nome));
			if (rito) {
				scelta = rito;
				return;
			}
		}
		if (dentroRaggio.length) scelta = dentroRaggio[0].voce;
	});

	/** Il GPS suggerisce, il giocatore decide: passa tutto di qui. */
	function scegli(v: VoceDex | null) {
		scelta = v;
		cerca = '';
		sceltaMia = true;
	}

	function scegliFoto(e: Event, da: 'fotocamera' | 'galleria') {
		const input = e.currentTarget as HTMLInputElement;
		const f = input.files?.[0];
		if (!f) return;
		file = f;
		origine = da;
		if (urlAnteprima) URL.revokeObjectURL(urlAnteprima);
		urlAnteprima = anteprima(f);
		// Il campo si svuota: riscegliendo lo stesso file l'evento change
		// non scatterebbe una seconda volta.
		input.value = '';
	}

	/* --- @menzioni nella didascalia --------------------------------------- */
	let campoNota: HTMLInputElement | undefined = $state();
	let cursore = $state(0);

	const menzione = $derived(menzioneInCorso(nota, cursore));

	const candidati = $derived.by(() => {
		if (!menzione) return [];
		const q = menzione.parziale.toLowerCase();
		return profilo.altri.filter((u) => u.nome.toLowerCase().startsWith(q)).slice(0, 5);
	});

	const taggati = $derived(estraiTaggati(nota, profilo.utenti, profilo.io?.id));

	function segnaCursore() {
		cursore = campoNota?.selectionStart ?? nota.length;
	}

	function scegliMenzione(u: User) {
		if (!menzione) return;
		const esito = completaMenzione(nota, menzione.inizio, cursore, u.nome);
		nota = esito.testo;
		cursore = esito.cursore;
		// Il cursore va rimesso a mano: il valore cambia sotto i piedi al campo.
		requestAnimationFrame(() => {
			campoNota?.focus();
			campoNota?.setSelectionRange(esito.cursore, esito.cursore);
		});
	}

	async function pubblica() {
		if (!scelta || !file || !profilo.io || fotoNonAmmessa) return;
		inInvio = true;
		errore = null;
		try {
			const pronta = await comprimiFoto(file);
			await coda.accoda({
				userId: profilo.io.id,
				itemId: scelta.item_id,
				nomeItem: scelta.nome,
				blob: pronta.blob,
				estensione: pronta.estensione,
				nota: nota.trim() || null,
				taggati: taggati.map((u) => u.id),
				lat: pos?.lat ?? null,
				lng: pos?.lng ?? null
			});
			// Prima la festa, poi il feed. L'accodamento e' gia' avvenuto: se la
			// rete manca la coda ci pensa comunque, quindi si puo' festeggiare
			// senza aspettare l'upload.
			festeggia = scelta;
		} catch (e) {
			errore = messaggioErrore(e);
		} finally {
			inInvio = false;
		}
	}
</script>

<svelte:head><title>Cattura — Pachino Express</title></svelte:head>

<div class="cattura stack">
	{#if benvenuto}
		<div class="rito">
			<p class="rito__titolo">Si comincia da qui</p>
			<p class="t-small">
				La prima cosa da fare è un <strong>selfie inaugurale</strong>. È già
				selezionato: scatta e sei dentro.
			</p>
		</div>
	{/if}

	<Finestra titolo="Nuova cattura" onChiudi={() => goto('/')}>
		<div class="stack">
			<!-- 1. La foto -->
			{#if urlAnteprima}
				<div class="foto">
					<img class="photo" src={urlAnteprima} alt="Anteprima" />
					<span class="foto__da t-label">
						{origine === 'galleria' ? 'dalla galleria' : 'scattata ora'}
					</span>
				</div>
				<div class="rifai">
					<label class="btn btn--sm grow">
						Riscatta
						<input
							type="file"
							accept="image/*"
							capture="environment"
							onchange={(e) => scegliFoto(e, 'fotocamera')}
							class="visually-hidden"
						/>
					</label>
					{#if !soloFotocamera}
						<label class="btn btn--sm grow">
							Dalla galleria
							<input
								type="file"
								accept="image/*"
								onchange={(e) => scegliFoto(e, 'galleria')}
								class="visually-hidden"
							/>
						</label>
					{/if}
				</div>
			{:else}
				<div class="prendi">
					<label class="scatta">
						<span class="scatta__icona" aria-hidden="true">◉</span>
						<span class="t-label">Scatta ora</span>
						<input
							type="file"
							accept="image/*"
							capture="environment"
							onchange={(e) => scegliFoto(e, 'fotocamera')}
							class="visually-hidden"
						/>
					</label>

					{#if !soloFotocamera}
						<!-- Un animale non aspetta che apri l'app: capita di averlo gia'
						     fotografato con la fotocamera di sistema. -->
						<label class="scatta scatta--galleria">
							<span class="scatta__icona" aria-hidden="true">▤</span>
							<span class="t-label">Dalla galleria</span>
							<input
								type="file"
								accept="image/*"
								onchange={(e) => scegliFoto(e, 'galleria')}
								class="visually-hidden"
							/>
						</label>
					{/if}
				</div>
			{/if}

			{#if fotoNonAmmessa}
				<p class="blocco t-small">
					Questa foto viene dalla galleria, ma <strong>{scelta?.nome}</strong> è un
					checkpoint: va fotografato sul posto. Riscatta per continuare.
				</p>
			{:else if soloFotocamera && !urlAnteprima}
				<p class="t-small t-muted">
					I checkpoint si fotografano sul momento: qui la galleria non vale.
				</p>
			{/if}

			<!-- 2. Cosa hai catturato -->
			{#if caricamento}
				<p class="t-label t-muted">Carico gli elementi…</p>
			{:else if scelta}
				<div class="scelta">
					{#if riferimento}
						<img class="scelta__rif" src={riferimento} alt="Com'e' fatto: {scelta.nome}" />
					{/if}
					<div class="grow">
						<p class="t-label t-muted">{etichettaCategoria(scelta.categoria)}</p>
						<p class="scelta__nome">{scelta.nome}</p>
						<Rarita rarita={scelta.rarita} croquembouche={scelta.croquembouche} />
					</div>
					<button class="btn btn--sm" onclick={() => scegli(null)}> Cambia </button>
				</div>

				{#if scelta.note}
					<p class="indizio t-small">{scelta.note}</p>
				{/if}

				{#if scelta.validazione === 'foto_gps'}
					<p class="gps-ok t-small">
						Checkpoint: il GPS conferma che sei qui, ma la foto serve lo stesso — e
						resta contestabile come tutte le altre.
					</p>
				{/if}
			{:else}
				<div class="field-row">
					<label class="field-label" for="cerca">Cosa hai catturato?</label>
					<input
						id="cerca"
						class="field"
						type="search"
						enterkeyhint="search"
						autocapitalize="none"
						bind:value={cerca}
						placeholder="Cerca fra le sfiziosita'…"
					/>
				</div>

				{#if !voci.length}
					<p class="t-small t-muted">
						Il PachiDex e' ancora vuoto. Deve caricarlo l'admin dal pannello.
					</p>
				{:else}
					<ul class="risultati">
						{#each risultati as v (v.item_id)}
							<li>
								<button
									class="risultato"
									disabled={giaPresa(v)}
									onclick={() => scegli(v)}
								>
									<span class="cat" style:background="var(--cat-{v.categoria})">
										{CATEGORIE.find((c) => c.valore === v.categoria)?.icona}
									</span>
									<span class="grow">
										{v.nome}
										{#if giaPresa(v)}<span class="t-small t-muted"> — gia' preso</span>{/if}
									</span>
									<Rarita rarita={v.rarita} croquembouche={v.croquembouche} />
								</button>
							</li>
						{/each}
					</ul>
				{/if}
			{/if}

			<!-- 3. Due parole, e chi c'era -->
			<div class="field-row composer">
				<label class="field-label" for="nota">
					Didascalia — scrivi @ per dare i punti anche a chi era con te
				</label>
				<input
					id="nota"
					class="field"
					bind:value={nota}
					bind:this={campoNota}
					oninput={segnaCursore}
					onclick={segnaCursore}
					onkeyup={segnaCursore}
					maxlength="180"
					autocomplete="off"
					autocorrect="off"
					enterkeyhint="done"
					placeholder="Granita con @..."
				/>

				{#if candidati.length}
					<ul class="menu">
						{#each candidati as u (u.id)}
							<li>
								<button type="button" class="menu__voce" onclick={() => scegliMenzione(u)}>
									<Avatar utente={u} dimensione="sm" />
									<span>{u.nome}</span>
								</button>
							</li>
						{/each}
					</ul>
				{/if}

				{#if taggati.length}
					<p class="taggati t-small">
						Vale anche per
						{#each taggati as u, i (u.id)}<strong>{u.nome}</strong>{i <
							taggati.length - 1
							? ', '
							: ''}{/each}
						— stessi Croquembouche, stesso sblocco nel PachiDex.
					</p>
				{/if}
			</div>

			{#if errore}
				<p class="errore t-small">{errore}</p>
			{/if}

			<button
				class="btn btn--primary btn--lg btn--block"
				disabled={!scelta || !file || inInvio || fotoNonAmmessa}
				onclick={pubblica}
			>
				{inInvio ? 'Pubblico…' : 'Cattura'}
			</button>

			{#if !coda.online}
				<p class="t-small t-muted">
					Sei offline: la cattura resta in coda e parte da sola appena torna la rete.
				</p>
			{/if}
		</div>
	</Finestra>

	<!-- Checkpoint intorno -->
	<Finestra titolo="Checkpoint intorno a te" variante="blue">
		{#if erroreGps}
			<p class="t-small t-muted">{erroreGps}</p>
			<p class="t-small t-muted">Senza posizione puoi comunque catturare tutto il resto.</p>
		{:else if !pos}
			<p class="t-label t-muted">Cerco il satellite…</p>
		{:else if !vicini.length}
			<p class="t-small t-muted">Nessun checkpoint GPS caricato.</p>
		{:else}
			<ul class="vicini">
				{#each vicini.slice(0, 5) as v (v.voce.item_id)}
					<li class="vicino" class:vicino--dentro={v.dentro}>
						<span class="grow">{v.voce.nome}</span>
						<span class="t-num t-small">{formattaDistanza(v.distanza)}</span>
						{#if v.dentro}
							<button class="btn btn--sm btn--ok" onclick={() => scegli(v.voce)}>
								Sei qui
							</button>
						{/if}
					</li>
				{/each}
			</ul>
			<p class="t-small t-muted">
				Serve stare entro {raggio} m. Precisione attuale: ±{Math.round(pos.precisione)} m.
			</p>
		{/if}
	</Finestra>
</div>

<FestaCattura voce={festeggia} onFine={() => goto('/')} />

<style>
	.cattura {
		padding: var(--space-3);
	}

	/* Il saluto di benvenuto, che arriva dalla fine del giro guidato. */
	.rito {
		background: var(--yellow);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow-sm);
		padding: var(--space-3);
		animation: entra-rito 280ms steps(4, end);
	}

	.rito__titolo {
		font-size: 1.0625rem;
		font-weight: 700;
		margin-bottom: 4px;
	}

	@keyframes entra-rito {
		from {
			transform: translateY(-12px);
			opacity: 0;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.rito {
			animation: none;
		}
	}

	.scatta {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		min-height: 180px;
		padding: var(--space-4);
		background: var(--cream);
		border: var(--border) dashed var(--navy);
		cursor: pointer;
		position: relative;
	}

	/* Due scelte affiancate quando la galleria e' ammessa, una sola per i
	   checkpoint: la griglia si adatta da sola al numero di figli. */
	.prendi {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
		gap: var(--space-2);
	}

	.scatta--galleria {
		background: var(--paper);
	}

	.foto {
		position: relative;
		line-height: 0;
	}

	/* Da dove viene la foto, scritto sopra: sull'ultima cattura di giornata
	   uno non se lo ricorda piu'. */
	.foto__da {
		position: absolute;
		left: var(--space-2);
		bottom: var(--space-2);
		background: var(--navy);
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		padding: 2px 6px;
		line-height: 1.4;
	}

	.rifai {
		display: flex;
		gap: var(--space-2);
	}

	.blocco {
		background: rgba(217, 59, 50, 0.14);
		border: var(--border-thin) solid var(--red);
		padding: var(--space-2);
	}

	.scatta__icona {
		font-size: 2.5rem;
		line-height: 1;
	}


	.scelta {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		background: var(--cream);
		border: var(--border) solid var(--navy);
		padding: var(--space-2);
	}

	.scelta__nome {
		font-size: 1.125rem;
		font-weight: 700;
	}

	/* Piccola apposta: conferma che stai fotografando la cosa giusta, non
	   ruba spazio all'anteprima del tuo scatto. `contain` e non `cover`
	   perche' su una foto verticale il ritaglio quadrato mangia la testa
	   dell'animale, che e' esattamente cio' che si sta confrontando. */
	.scelta__rif {
		width: 64px;
		height: 64px;
		object-fit: contain;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		flex-shrink: 0;
	}

	.indizio {
		background: var(--cream);
		border-left: var(--border) solid var(--navy);
		padding: 5px var(--space-2);
	}

	.gps-ok {
		background: rgba(53, 183, 154, 0.22);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
	}

	.risultati {
		max-height: 42dvh;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 4px;
		border: var(--border-thin) solid rgba(22, 27, 61, 0.25);
		padding: 4px;
	}

	.risultato {
		width: 100%;
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: 6px;
		background: var(--paper);
		border: var(--border-thin) solid var(--navy);
		text-align: left;
		cursor: pointer;
		font-size: 0.9375rem;
	}

	.risultato:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.risultato:active:not(:disabled) {
		background: var(--cream);
	}

	.cat {
		width: 22px;
		height: 22px;
		display: grid;
		place-items: center;
		color: var(--paper);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.75rem;
		flex-shrink: 0;
	}

	.vicini {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-bottom: var(--space-2);
	}

	.vicino {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: 5px var(--space-2);
		background: var(--cream);
		border: var(--border-thin) solid var(--navy);
		font-size: 0.9375rem;
	}

	.vicino--dentro {
		background: rgba(53, 183, 154, 0.28);
	}

	.errore {
		color: var(--red);
		font-weight: 700;
	}

	.composer {
		position: relative;
	}

	/* Il menu galleggia sopra il resto del modulo, come in ogni composer. */
	.menu {
		position: absolute;
		left: 0;
		right: 0;
		z-index: 20;
		background: var(--paper);
		border: var(--border) solid var(--navy);
		box-shadow: var(--shadow);
		max-height: 44dvh;
		overflow-y: auto;
	}

	.menu__voce {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		width: 100%;
		padding: 6px var(--space-2);
		background: transparent;
		border: 0;
		border-bottom: var(--border-thin) solid rgba(22, 27, 61, 0.15);
		text-align: left;
		cursor: pointer;
		font-weight: 700;
	}

	.menu__voce:active {
		background: var(--orange);
		color: var(--paper);
	}

	.taggati {
		margin-top: var(--space-2);
		background: rgba(53, 183, 154, 0.2);
		border: var(--border-thin) solid var(--navy);
		padding: var(--space-2);
	}
</style>
