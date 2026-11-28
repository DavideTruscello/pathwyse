# Campagna di benchmark – istruzioni per Linux

Questa guida spiega come lanciare la campagna di benchmark su una macchina Linux.
Basta lanciarla una volta: gira da sola in background (circa 2 ore per 118 istanze, a seconda della macchina) e alla fine i risultati sono nei file CSV.

## Cosa fa la campagna

Su ogni istanza della cartella `instances/campaign` esegue 5 casi, 10 volte ciascuno:

| Caso | Riduzione archi | Selezione | Join | Ripetizioni |
|---|---|---|---|---|
| `opt` – ottimo vero | spenta (intera rete) | – | – | 10 |
| `detP` – deterministico | cutoff, k1, k2 = 0.2 | deterministica | sottorete | 10 |
| `detF` – deterministico, full join | cutoff, k1, k2 = 0.2 | deterministica | intera rete | 10 |
| `stoP` – stocastico | cutoff, k1, k2 = 0.2, temperature = 0.5 | ibrida | sottorete | 10, una per seed |
| `stoF` – stocastico, full join | cutoff, k1, k2 = 0.2, temperature = 0.5 | ibrida | intera rete | 10, una per seed |

L'ordine è: ripetizione 1 di tutte le istanze e di tutti i casi, poi ripetizione 2, e così via.
Se la campagna dovesse interrompersi, le ripetizioni già finite sono complete per tutti i casi.

Limiti di tempo per ogni singola esecuzione:

- **interno, 120 s**: il programma si ferma da solo e scrive normalmente la sua riga;
- **esterno, 300 s**: se il programma è ancora in esecuzione viene interrotto, e lo script scrive al suo
  posto una riga con `status = Killed`.

Con le istanze scelte non dovrebbero scattare mai: sono solo una protezione.

I parametri vengono impostati dallo script per ogni caso: **non serve modificare `pathwyse.set`**.

## Cosa serve

- il repository aggiornato (branch `tesi-dev`);
- `cmake`, `make` e un compilatore C++ (g++ 10 o successivo);
- il file dei seed con **almeno 10 seed** (uno per riga), per esempio `seeds_campaign.txt` nella root del progetto;
- la cartella `instances/campaign` con le istanze della campagna.

## Passo 1 – Prova veloce (2-3 minuti)

Dalla root del progetto (la cartella che contiene `pathwyse.set`):

```
./test_campaign.sh seeds_campaign.txt
```

La prova compila il progetto, esegue una versione ridotta della campagna su 3 istanze e controlla da sola i
risultati. Deve terminare con:

```
PROVA SUPERATA: si puo' lanciare la campagna vera con
    ./run_campaign.sh seeds_campaign.txt
```

Se termina con `PROVA FALLITA`, stampa l'elenco dei problemi: in quel caso non lanciare la campagna e
inviare l'output.

La prova scrive in una cartella temporanea e non tocca la cartella `benchmark/` del progetto.

## Passo 2 – Campagna vera

```
./run_campaign.sh seeds_campaign.txt
```

Lo script compila il progetto, si mette in background e restituisce subito il controllo, con un messaggio
simile a:

```
Campagna avviata in background (PID 12345).
Si puo' chiudere il terminale. Per seguire l'avanzamento:
    tail -f benchmark/campaign.log
Per fermarla:
    kill 12345
```

**Si può chiudere il terminale o la sessione SSH**: la campagna continua.

Durante la campagna la macchina dovrebbe restare il più possibile libera: altri programmi pesanti falsano i
tempi.

## Seguire l'avanzamento

```
tail -f benchmark/campaign.log
```

(`Ctrl+C` chiude solo la visualizzazione, non la campagna.)

Ogni riga del log corrisponde a un'esecuzione:

```
[2026-11-24 10:15:02] [37/5900] rep 1  detF  B-n68-k9-65.sppcc  0.61 s  ok
```

## Al termine

Nel log compare:

```
Campagna terminata in ... minuti.
```

I risultati da recuperare sono:

- `benchmark/result_it.csv` – per Excel con impostazioni italiane (separatore `;`, decimali con la virgola);
- `benchmark/result_intl.csv` – formato internazionale (separatore `,`, decimali con il punto);
- `benchmark/campaign.log` – utile per controllare eventuali esecuzioni interrotte o errori.

Il significato delle colonne è spiegato in `README_TESI.md`, sezione 8. Lo script può aggiungere due valori di
`status` oltre a quelli del programma:

- `Killed`: esecuzione interrotta dopo 300 s;
- `Error`: il programma è terminato con un errore.

In questi due casi `obj`, `tour_length` e `dssr_iterations` restano vuoti.

## Se qualcosa va storto

**La macchina si è spenta o la campagna è stata fermata.** Rilanciare lo stesso comando:

```
./run_campaign.sh seeds_campaign.txt
```

Riprende da dove si era fermata: le esecuzioni già fatte sono elencate in `benchmark/campaign_progress.txt`
e vengono saltate. Un'esecuzione interrotta a metà viene rifatta.

**Fermare la campagna.** Usare il comando `kill` indicato all'avvio. Se non si ha più il PID:

```
kill $(cat benchmark/campaign.pid)
```

**Ricominciare da zero.** Rinominare o cancellare la cartella `benchmark/` (dopo aver salvato eventuali
risultati utili) e rilanciare.

**"Permission denied" lanciando gli script.** Usare `bash run_campaign.sh ...` e `bash test_campaign.sh ...`,
oppure renderli eseguibili una volta con:

```
chmod +x run_campaign.sh test_campaign.sh run_benchmark.sh
```

**"una campagna e' gia' in esecuzione".** Una campagna sta ancora girando: seguirla con `tail -f
benchmark/campaign.log` oppure fermarla con `kill` prima di lanciarne un'altra.

**Errore sui CSV con colonne diverse.** Nella cartella `benchmark/` ci sono file di una versione precedente:
rinominarli o cancellarli.
