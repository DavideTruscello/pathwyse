#!/usr/bin/env bash
# Esegue pathwyse su tutte le istanze di una cartella e raccoglie i risultati in
#     benchmark/result_intl.csv   (separatore ","  decimali con ".")
#     benchmark/result_it.csv     (separatore ";"  decimali con ",", per Excel in italiano)
# Ogni esecuzione aggiunge una riga a entrambi i file (che non vengono mai svuotati).
#
# Lo script crea una copia temporanea del file di configurazione con
#     output/benchmark = 1
# (e, se si passa un file dei seed, con il seed di ogni esecuzione).
# Il file di configurazione originale non viene mai modificato.
#
# Va lanciato dalla ROOT del progetto (dove ci sono pathwyse.set e bin/pathwyse).
#
# Uso:
#   ./run_benchmark.sh CARTELLA_ISTANZE [RIPETIZIONI] [PATTERN] [FILE_SEED]
#
#   CARTELLA_ISTANZE  obbligatoria. Le sottocartelle non vengono esplorate.
#   RIPETIZIONI       quante volte eseguire ogni istanza (per ogni seed). Default: 1
#   PATTERN           quali file della cartella usare. Default: * (tutti i file)
#   FILE_SEED         file con un seed per riga. Default: nessuno (si usa il seed
#                     scritto nel file di configurazione)
#
# Esempi:
#   ./run_benchmark.sh instances/more_instances/spprclib
#   ./run_benchmark.sh instances/more_instances/spprclib 1 '*.sppcc'
#   ./run_benchmark.sh instances/more_instances/spprclib 3 '*' seeds.txt
#
# Variabili d'ambiente opzionali: BIN      (default ./bin/pathwyse)
#                                 SETTINGS (default pathwyse.set)
#
set -euo pipefail

usage() {
    sed -n '14,27p' "$0" | sed 's/^# \{0,1\}//' >&2
}

if [ $# -lt 1 ] || [ -z "$1" ]; then
    echo "Errore: manca la cartella delle istanze." >&2
    echo >&2
    usage
    exit 1
fi

INSTANCE_DIR="$1"
RUNS="${2:-1}"
PATTERN="${3:-*}"
SEEDS_FILE="${4:-}"
BIN="${BIN:-./bin/pathwyse}"
SETTINGS="${SETTINGS:-pathwyse.set}"
OUTDIR="benchmark"
SEED_KEY="algo/default/graph_reduction/arcs/seed"
BENCH_KEY="output/benchmark"

if [ ! -x "$BIN" ]; then
    echo "Binario non trovato/eseguibile: $BIN" >&2
    echo "Lancia dalla root del progetto e assicurati di aver ricompilato." >&2
    exit 1
fi

if [ ! -f "$SETTINGS" ]; then
    echo "File di configurazione non trovato: $SETTINGS" >&2
    exit 1
fi

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "Cartella delle istanze non trovata: $INSTANCE_DIR" >&2
    exit 1
fi

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || [ "$RUNS" -lt 1 ]; then
    echo "Numero di ripetizioni non valido: '$RUNS'" >&2
    exit 1
fi

if ! compgen -G "$INSTANCE_DIR/$PATTERN" > /dev/null; then
    echo "Nessun file '$PATTERN' in '$INSTANCE_DIR'." >&2
    exit 1
fi

# Legge i seed (solo se e' stato passato un file): un intero per riga,
# righe vuote e commenti (#) ignorati
SEEDS=()
if [ -n "$SEEDS_FILE" ]; then
    if [ ! -f "$SEEDS_FILE" ]; then
        echo "File dei seed non trovato: $SEEDS_FILE" >&2
        exit 1
    fi
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1))
        value="${line%%#*}"
        value="$(echo "$value" | tr -d '\r' | xargs)"
        [ -z "$value" ] && continue
        if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
            echo "Seed non valido alla riga $n di $SEEDS_FILE: '$value'" >&2
            exit 1
        fi
        SEEDS+=("$value")
    done < "$SEEDS_FILE"
    if [ "${#SEEDS[@]}" -eq 0 ]; then
        echo "Nessun seed trovato in $SEEDS_FILE." >&2
        exit 1
    fi
    echo "Seed letti da $SEEDS_FILE: ${SEEDS[*]}"

    # Avvisa se la componente stocastica e' disattivata (in quel caso il seed non ha effetto)
    setting_value() {
        awk -v key="$1" '$1 == key && $2 == "=" { v = $3 } END { print v }' "$SETTINGS" | tr -d '\r'
    }
    [ "$(setting_value algo/default/graph_reduction/arcs/active)" = "0" ] &&
        echo "[avviso] arcs/active = 0: la riduzione degli archi e' spenta, il seed non ha effetto." >&2
    [ "$(setting_value algo/default/graph_reduction/arcs/is_deterministic)" = "1" ] &&
        echo "[avviso] is_deterministic = 1: selezione deterministica, il seed non ha effetto." >&2
    temp="$(setting_value algo/default/graph_reduction/arcs/temperature)"
    if [ -n "$temp" ] && awk -v t="$temp" 'BEGIN { exit !(t <= 0) }'; then
        echo "[avviso] temperature <= 0: selezione greedy, il seed non ha effetto." >&2
    fi
else
    echo "Nessun file dei seed: uso il seed scritto in $SETTINGS."
fi

mkdir -p "$OUTDIR"

# File di configurazione temporanei, rimossi anche in caso di interruzione
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Crea una copia di SETTINGS con output/benchmark = 1 e, se $2 non e' vuoto, il seed $2
make_settings() {   # $1 = file di destinazione, $2 = seed (opzionale)
    awk -v bkey="$BENCH_KEY" -v skey="$SEED_KEY" -v seed="$2" '
        { sub(/\r$/, "") }
        $1 == bkey { print bkey " = 1"; bfound = 1; next }
        seed != "" && $1 == skey { print skey " = " seed; sfound = 1; next }
        { print }
        END {
            if (!bfound) print bkey " = 1"
            if (seed != "" && !sfound) print skey " = " seed
        }
    ' "$SETTINGS" > "$1"
}

CONFIGS=()
if [ "${#SEEDS[@]}" -gt 0 ]; then
    for seed in "${SEEDS[@]}"; do
        make_settings "$TMP_DIR/pathwyse_seed_$seed.set" "$seed"
        CONFIGS+=("$TMP_DIR/pathwyse_seed_$seed.set")
    done
else
    make_settings "$TMP_DIR/pathwyse.set" ""
    CONFIGS+=("$TMP_DIR/pathwyse.set")
fi

count=0
for f in "$INSTANCE_DIR"/$PATTERN; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    count=$((count + 1))
    echo "[$count] $name"
    for k in "${!CONFIGS[@]}"; do
        if [ "${#SEEDS[@]}" -gt 0 ]; then
            echo "    seed ${SEEDS[$k]}  (x$RUNS)"
        else
            echo "    (x$RUNS)"
        fi
        for i in $(seq 1 "$RUNS"); do
            "$BIN" "$f" -param "${CONFIGS[$k]}" >/dev/null 2>&1 || echo "       [warn] run $i fallito per $name"
        done
    done
done

echo
echo "Fatto: $count istanze. Risultati in '$OUTDIR/result_intl.csv' e '$OUTDIR/result_it.csv'."
