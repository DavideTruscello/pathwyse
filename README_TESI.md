# PathWyse – guida per la tesi (branch `tesi-dev`)

Questa guida spiega come configurare `pathwyse.set`, come usare il file dei seed e come lanciare i benchmark.
Per i parametri originali di PathWyse non legati alla tesi, la documentazione completa (in inglese) è in
[documentation/tutorials/PARAMETERS.md](documentation/tutorials/PARAMETERS.md).

## Indice

1. [Il file pathwyse.set](#1-il-file-pathwyseset)
2. [Parametri della riduzione degli archi](#2-parametri-della-riduzione-degli-archi)
3. [Parametri del join e del pool](#3-parametri-del-join-e-del-pool)
4. [Parametro del benchmark](#4-parametro-del-benchmark)
5. [Altri parametri utili](#5-altri-parametri-utili)
6. [Il file dei seed](#6-il-file-dei-seed)
7. [Lanciare i benchmark](#7-lanciare-i-benchmark)
8. [I file dei risultati](#8-i-file-dei-risultati)
9. [Esempi di configurazione](#9-esempi-di-configurazione)

---

## 1. Il file pathwyse.set

Il programma legge le impostazioni dal file `pathwyse.set` presente nella cartella da cui viene lanciato.
Si può usare un altro file con l'opzione `-param`:

```
./bin/pathwyse instances/toy.txt -param altro_file.set
```

Regole del formato:

- una impostazione per riga, nella forma `nome = valore`;
- **gli spazi intorno all'uguale sono obbligatori**: `nome=valore` non viene letto e sfasa anche la lettura delle righe successive;
- i nomi distinguono maiuscole e minuscole;
- **niente commenti** nel file (per lo stesso motivo: le parole in più sfasano la lettura);
- un nome scritto male viene **ignorato in silenzio**: il programma usa il valore di default senza avvisare;
- se una riga manca, vale il valore di default scritto nel codice (indicato nelle tabelle sotto), che può essere
  diverso dal valore presente oggi in `pathwyse.set`.

---

## 2. Parametri della riduzione degli archi

La riduzione viene applicata una sola volta, prima di avviare l'algoritmo. Ogni arco riceve un punteggio,
gli archi vengono ordinati e se ne tiene solo una parte. **Punteggio più basso = arco migliore.**

Punteggio dell'arco (i, j):

```
costo dell'arco normalizzato
+ k1 * consumo medio di risorse normalizzato
+ k2 * (premio di i + premio di j) normalizzato
```

Il costo dell'arco ha sempre peso 1; k1 e k2 decidono quanto contano risorse e premi dei nodi.
Gli archi che escono dall'origine e quelli che entrano nella destinazione vengono sempre mantenuti.

| Parametro | Valori | Default | Significato |
|---|---|---|---|
| `algo/default/graph_reduction/arcs/active` | 0, 1 | 0 | Accende (1) o spegne (0) la riduzione. |
| `algo/default/graph_reduction/arcs/cutoff` | tra 0 e 1 | 1.0 | Frazione di archi da **tenere** (0.2 = si tiene il 20%, si toglie l'80%). |
| `algo/default/graph_reduction/arcs/k1` | ≥ 0 | 0 | Peso del consumo di risorse. Più è alto, più sono penalizzati gli archi che consumano molto. |
| `algo/default/graph_reduction/arcs/k2` | numero | 0 | Peso dei premi dei nodi. Con premi negativi, più è alto, più sono favoriti gli archi verso nodi con premi grandi. |
| `algo/default/graph_reduction/arcs/is_deterministic` | 0, 1 | 0 | 1 = si tengono gli archi con punteggio migliore. 0 = ibrida: metà sono i migliori, l'altra metà è estratta a caso tra i rimanenti, favorendo quelli con punteggio migliore. |
| `algo/default/graph_reduction/arcs/temperature` | numero | 0.2 | Solo con `is_deterministic = 0`. Valori piccoli: si estraggono quasi sempre i migliori. Valori grandi: estrazione più uniforme. 0 o negativo: nessuna casualità. |
| `algo/default/graph_reduction/arcs/seed` | intero | 0 | Solo con `is_deterministic = 0`. Stesso seed = stessa riduzione. Seed negativo = seed diverso a ogni esecuzione. |

Nota: con la riduzione attiva, "Optimal" nell'output significa **ottimo sulla sottorete ridotta**, non ottimo
dell'istanza originale.

---

## 3. Parametri del join e del pool

Il join collega un mezzo cammino "avanti" (dall'origine) e uno "indietro" (dalla destinazione) tramite un arco.

| Parametro | Valori | Default | Significato |
|---|---|---|---|
| `algo/default/join/type` | `naive`, `classic`, `ordered`, `kordered` | `ordered` | `ordered` tiene solo la combinazione migliore (è il più efficiente). `kordered` tiene le K migliori, con K = `algo/requested_solutions`. |
| `algo/default/join/full_network` | 0, 1 | 0 | 0 = il join usa solo gli archi rimasti dopo la riduzione. 1 = può collegare le due metà anche tramite archi tolti. Senza riduzione 0 e 1 danno lo stesso risultato. |
| `algo/requested_solutions` | intero ≥ 1 | 1 | K per `kordered`. Se è maggiore di 1 accende anche il pool delle super-ottime, che raccoglie i cammini di tutti i giri di DSSR e alla fine stampa un riepilogo. |

Le quattro combinazioni principali:

| | solo la migliore (`ordered`) | K migliori + pool (`kordered`) |
|---|---|---|
| **sottorete** (`full_network = 0`) | join corretto sulla sola sottorete | K soluzioni sulla sottorete |
| **intera rete** (`full_network = 1`) | comportamento del vecchio `ordered` di `tesi-dev` | K soluzioni sull'intera rete |

---

## 4. Parametro del benchmark

| Parametro | Valori | Default | Significato |
|---|---|---|---|
| `output/benchmark` | 0, 1 | 0 | Se 1, ogni esecuzione aggiunge una riga ai file `benchmark/result_intl.csv` e `benchmark/result_it.csv` (vedi [sezione 8](#8-i-file-dei-risultati)). |

Di solito non serve cambiarlo a mano: gli script di benchmark lo impostano a 1 da soli (vedi [sezione 7](#7-lanciare-i-benchmark)).
Lo si può mettere a 1 in `pathwyse.set` per salvare anche le esecuzioni lanciate manualmente.

La scrittura dei risultati è fatta dall'eseguibile `pathwyse` (`src/standalone/main.cpp`), non dalla libreria:
usando PathWyse dal wrapper Python non viene scritto nulla.

---

## 5. Altri parametri utili

Parametri originali di PathWyse che servono spesso durante i test. Per tutti gli altri vedi
[PARAMETERS.md](documentation/tutorials/PARAMETERS.md).

| Parametro | Valori | Default | Significato |
|---|---|---|---|
| `verbosity` | da -1 a 4 | 2 | Quantità di testo stampato. -1 = niente, 1 = mostra anche il cammino, 2 = anche il consumo di risorse. |
| `algo/default/timelimit` | secondi | 0 | Tempo massimo dell'algoritmo; 0 = nessun limite. Viene controllato solo **alla fine di ogni giro di DSSR**, quindi può essere superato anche di molto. |
| `algo/default/dssr` | `off`, `standard`, `restricted` | `standard` | Tipo di rilassamento DSSR. |
| `algo/default/ng` | `off`, `standard`, `restricted` | `off` | Rilassamento ng-route. |
| `problem/memory_threshold` | intero | 10000 | Sopra questo numero di nodi PathWyse usa strutture "compresse" per il grafo. Mettendolo a 1 si forza la modalità compressa anche su istanze piccole (utile per i test). |
| `algo/default/graph_reduction/nodes/active` | 0, 1 | 0 | Riduzione dinamica dei nodi (non usata per la tesi). |

---

## 6. Il file dei seed

Serve solo per la **riduzione ibrida** (`is_deterministic = 0`): permette di ripetere ogni istanza con più seed
diversi in un'unica esecuzione dello script di benchmark.

Formato:

- un seed per riga (numero intero, anche negativo);
- le righe vuote vengono ignorate;
- tutto quello che segue `#` è un commento.

Esempio (`seeds.txt`, già presente nel repository):

```
0
1
10
100   # questo è un commento
```

Il file dei seed è **facoltativo**: se non viene passato allo script, si usa il seed scritto in `pathwyse.set`.

Lo script avvisa se il seed non ha effetto, cioè se:

- `arcs/active = 0` (riduzione spenta);
- `arcs/is_deterministic = 1` (selezione deterministica);
- `arcs/temperature <= 0` (nessuna casualità).

---

## 7. Lanciare i benchmark

Gli script vanno lanciati dalla **root del progetto** (dove ci sono `pathwyse.set` e la cartella `bin`), dopo aver
compilato.

Per ogni esecuzione lo script crea una **copia temporanea** di `pathwyse.set` con `output/benchmark = 1` (e, se
c'è un file dei seed, con il seed di quell'esecuzione). Il vostro `pathwyse.set` non viene mai modificato.
Tutte le altre impostazioni sono quelle di `pathwyse.set`.

### Linux / macOS (`run_benchmark.sh`)

```
./run_benchmark.sh CARTELLA_ISTANZE [RIPETIZIONI] [PATTERN] [FILE_SEED]
```

| Argomento | Obbligatorio | Default | Significato |
|---|---|---|---|
| `CARTELLA_ISTANZE` | sì | – | Cartella con le istanze. Le sottocartelle non vengono esplorate. |
| `RIPETIZIONI` | no | 1 | Quante volte eseguire ogni istanza (per ogni seed). |
| `PATTERN` | no | `*` | Quali file usare (tutti i file della cartella per default). Mettere tra apici: `'*.sppcc'`. |
| `FILE_SEED` | no | nessuno | File dei seed. |

Gli argomenti sono posizionali: per passare il file dei seed bisogna indicare anche ripetizioni e pattern.

Requisiti e note per Linux:

- serve `bash` (qualsiasi versione recente). Se lo script viene lanciato con `sh run_benchmark.sh`, si rilancia
  da solo con bash;
- lo script deve essere eseguibile. Se `./run_benchmark.sh` dà "Permission denied", usare
  `bash run_benchmark.sh ...` oppure `chmod +x run_benchmark.sh`;
- il file `.gitattributes` del repository forza la fine riga Linux (LF) per gli script `.sh`, anche se vengono
  modificati su Windows: con la fine riga di Windows (CRLF) bash non riesce a eseguirli;
- `pathwyse.set` e il file dei seed possono avere indifferentemente fine riga Linux o Windows;
- percorsi con spazi sono supportati (vanno messi tra virgolette).

Variabili d'ambiente facoltative: `BIN` (default `./bin/pathwyse`) e `SETTINGS` (default `pathwyse.set`):

```
SETTINGS=prova.set ./run_benchmark.sh instances/more_instances/spprclib
```

Esempi:

```
./run_benchmark.sh instances/more_instances/spprclib
./run_benchmark.sh instances/more_instances/spprclib 1 '*.sppcc'
./run_benchmark.sh instances/more_instances/spprclib 3 '*' seeds.txt
```

### Windows (`run_benchmark.ps1`)

```
.\run_benchmark.ps1 -InstanceDir CARTELLA [-Runs N] [-Pattern P] [-SeedsFile F] [-Settings S]
```

Stessi significati e default della versione Linux (`-Settings` vale `pathwyse.set` per default). Si possono usare
anche in forma posizionale, nello stesso ordine.

Esempi:

```
.\run_benchmark.ps1 instances\more_instances\spprclib
.\run_benchmark.ps1 instances\more_instances\spprclib 1 *.sppcc
.\run_benchmark.ps1 -InstanceDir instances\more_instances\spprclib -Runs 3 -SeedsFile seeds.txt
```

Se PowerShell blocca l'esecuzione degli script, si può lanciare con:

```
powershell -ExecutionPolicy Bypass -File .\run_benchmark.ps1 instances\more_instances\spprclib
```

### Campagna completa

Per la campagna di benchmark con i 5 casi (ottimo vero, deterministico e stocastico, con join sulla sottorete e
sull'intera rete) ci sono due script dedicati, `run_campaign.sh` e `test_campaign.sh`, descritti in
[CAMPAGNA.md](CAMPAGNA.md).

---

## 8. I file dei risultati

Ogni esecuzione con `output/benchmark = 1` aggiunge una riga a **due file con lo stesso contenuto**, nella
cartella `benchmark/` (creata nella cartella da cui si lancia il programma):

| File | Separatore | Decimali | Adatto a |
|---|---|---|---|
| `benchmark/result_it.csv` | `;` | virgola (`0,2`) | Excel con impostazioni italiane |
| `benchmark/result_intl.csv` | `,` | punto (`0.2`) | Excel in inglese, Python, R |

- La riga di intestazione viene scritta solo quando il file viene creato.
- I file non vengono mai svuotati: le nuove esecuzioni si aggiungono in fondo. Per ripartire da zero basta
  cancellarli o rinominarli.
- Se in futuro cambiano le colonne, conviene cancellare i vecchi file per non mescolare formati diversi.
  Gli script di benchmark avvisano se trovano file con colonne diverse da quelle attuali.
- Un'esecuzione interrotta dall'esterno (Ctrl+C, chiusura del terminale) non scrive nessuna riga.
  Un'esecuzione fermata dal `timelimit` interno invece scrive normalmente.
- La cartella `benchmark/` è esclusa da git (`.gitignore`).

### Colonne

| Colonna | Significato |
|---|---|
| `file` | Nome del file dell'istanza, con estensione, senza cartelle. |
| `arcs_active` | Valore di `arcs/active` (0/1). |
| `is_deterministic` | Valore di `arcs/is_deterministic` (0/1). |
| `full_network` | Valore di `join/full_network` (0 = join sulla sottorete, 1 = sull'intera rete). |
| `cutoff` | Valore di `arcs/cutoff`. |
| `k1` | Valore di `arcs/k1`. |
| `k2` | Valore di `arcs/k2`. |
| `seed` | Valore di `arcs/seed`. Scritto sempre, anche quando non ha effetto. |
| `temperature` | Valore di `arcs/temperature`. Scritto sempre, anche quando non ha effetto. |
| `status` | Stato della soluzione migliore: `Optimal`, `Feasible`, `Superoptimal` (con cicli), `Infeasible`, `Unknown`, oppure `NoSolution` se non è stata trovata nessuna soluzione. |
| `obj` | Valore obiettivo della soluzione migliore (vuoto se `NoSolution`). |
| `total_time` | Tempo in secondi: algoritmo **più** riduzione degli archi. |
| `tour_length` | Numero di nodi del cammino trovato (vuoto se `NoSolution`). |
| `dssr_iterations` | Numero di giri di DSSR eseguiti, **compreso l'ultimo**. 1 = la prima soluzione era già senza cicli. |
| `datetime` | Data e ora locali di fine esecuzione, nel formato `AAAA-MM-GG hh:mm:ss` (es. `2026-11-24 07:42:04`). Excel lo riconosce come data/ora sia con impostazioni italiane sia internazionali. |

I valori dei parametri sono quelli effettivamente letti dal programma durante l'esecuzione (quindi quelli della
copia temporanea creata dallo script).

### Statistiche

Le statistiche (medie, minimi, massimi, ecc.) si calcolano direttamente in Excel, per esempio con una tabella
pivot su `result_it.csv` raggruppando per `file` e per i parametri che interessano.

---

## 9. Esempi di configurazione

Nessuna riduzione (rete completa, risultato esatto):

```
algo/default/graph_reduction/arcs/active = 0
algo/default/join/type = ordered
algo/requested_solutions = 1
```

Riduzione deterministica al 20%, join solo sulla sottorete:

```
algo/default/graph_reduction/arcs/active = 1
algo/default/graph_reduction/arcs/is_deterministic = 1
algo/default/graph_reduction/arcs/cutoff = 0.2
algo/default/graph_reduction/arcs/k1 = 0.2
algo/default/graph_reduction/arcs/k2 = 0.2
algo/default/join/type = ordered
algo/default/join/full_network = 0
algo/requested_solutions = 1
```

Come sopra, ma con il join sull'intera rete:

```
algo/default/graph_reduction/arcs/active = 1
algo/default/graph_reduction/arcs/is_deterministic = 1
algo/default/graph_reduction/arcs/cutoff = 0.2
algo/default/graph_reduction/arcs/k1 = 0.2
algo/default/graph_reduction/arcs/k2 = 0.2
algo/default/join/type = ordered
algo/default/join/full_network = 1
algo/requested_solutions = 1
```

Riduzione ibrida con più seed (lanciare lo script con `seeds.txt`):

```
algo/default/graph_reduction/arcs/active = 1
algo/default/graph_reduction/arcs/is_deterministic = 0
algo/default/graph_reduction/arcs/cutoff = 0.2
algo/default/graph_reduction/arcs/k1 = 0.2
algo/default/graph_reduction/arcs/k2 = 0.2
algo/default/graph_reduction/arcs/temperature = 0.5
algo/default/join/type = ordered
algo/default/join/full_network = 0
```

```
./run_benchmark.sh instances/more_instances/spprclib 1 '*' seeds.txt
```
