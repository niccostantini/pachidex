/**
 * Se la premiazione e' in corso, in un posto solo.
 *
 * Lo sanno in due: il layout, che ci porta tutti i telefoni quando comincia,
 * e la sala della cerimonia, che ci sta dentro. Finche' se lo chiedevano
 * ognuno per conto suo potevano rispondere diverso per qualche millisecondo —
 * e quando la cerimonia veniva annullata succedeva davvero: la sala usciva,
 * il layout la rispingeva dentro, la sala usciva di nuovo. Tre navigazioni in
 * venti millisecondi, che si vedono.
 *
 * Adesso chi scopre la novita' la scrive qui, e l'altro la legge subito.
 */
class StatoCerimonia {
	/** true mentre esiste una premiazione aperta. */
	inCorso = $state(false);
}

export const cerimonia = new StatoCerimonia();
