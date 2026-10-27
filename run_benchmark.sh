#!/usr/bin/env bash
# Esegue pathwyse su ogni istanza di una cartella, una volta per ogni seed
# elencato in SEEDS_FILE (uno per riga), ripetendo ogni seed RUNS volte.
# Per ogni seed viene generata una copia temporanea di SETTINGS con la riga
#     algo/default/graph_reduction/arcs/seed = <seed>
# e passata al binario con -param: il file SETTINGS originale non viene toccato.
#
# Se SEEDS_FILE non esiste, ogni istanza viene eseguita RUNS volte con SETTINGS
# cosi' com'e' (comportamento precedente).
#
# I risultati vengono accodati a benchmark_times/time_<istanza>.txt nel formato
#     time,obj,tour_length,seed
# (la cartella non viene mai svuotata).
#
# Va lanciato dalla ROOT del progetto (dove ci sono pathwyse.set e bin/pathwyse).
#
# Uso:
#   ./run_benchmark.sh [CARTELLA_ISTANZE] [RUN_PER_SEED] [PATTERN] [FILE_SEED]
# Esempi:
#   ./run_benchmark.sh instances/more_instances/truscello_txts 1
#   ./run_benchmark.sh instances/spprclib 3 '*.sppcc' seeds.txt
# Variabili d'ambiente opzionali: BIN (default ./bin/pathwyse),
#                                 SETTINGS (default pathwyse.set)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE_DIR="${1:-instances}"
RUNS="${2:-10}"
PATTERN="${3:-*.txt}"
SEEDS_FILE="${4:-$SCRIPT_DIR/seeds.txt}"   # per default accanto allo script
BIN="${BIN:-./bin/pathwyse}"
SETTINGS="${SETTINGS:-pathwyse.set}"
OUTDIR="benchmark_times"
SEED_KEY="algo/default/graph_reduction/arcs/seed"

if [ ! -x "$BIN" ]; then
    echo "Binario non trovato/eseguibile: $BIN" >&2
    echo "Lancia dalla root del progetto e assicurati di aver ricompilato." >&2
    exit 1
fi

if [ ! -f "$SETTINGS" ]; then
    echo "File di configurazione non trovato: $SETTINGS" >&2
    exit 1
fi

if ! compgen -G "$INSTANCE_DIR/$PATTERN" > /dev/null; then
    echo "Nessun file '$PATTERN' in '$INSTANCE_DIR'." >&2
    exit 1
fi

# Legge i seed: un intero per riga, righe vuote e commenti (#) ignorati
SEEDS=()
if [ -f "$SEEDS_FILE" ]; then
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
else
    echo "File dei seed non trovato ($SEEDS_FILE): uso $SETTINGS cosi' com'e'."
fi

# Avvisa se la componente stocastica e' disattivata (in quel caso il seed non ha effetto)
setting_value() {
    awk -v key="$1" '$1 == key && $2 == "=" { v = $3 } END { print v }' "$SETTINGS" | tr -d '\r'
}
if [ "${#SEEDS[@]}" -gt 0 ]; then
    [ "$(setting_value algo/default/graph_reduction/arcs/active)" = "0" ] &&
        echo "[avviso] arcs/active = 0: la riduzione degli archi e' spenta, il seed non ha effetto." >&2
    [ "$(setting_value algo/default/graph_reduction/arcs/is_deterministic)" = "1" ] &&
        echo "[avviso] is_deterministic = 1: selezione deterministica, il seed non ha effetto." >&2
    temp="$(setting_value algo/default/graph_reduction/arcs/temperature)"
    if [ -n "$temp" ] && awk -v t="$temp" 'BEGIN { exit !(t <= 0) }'; then
        echo "[avviso] temperature <= 0: selezione greedy, il seed non ha effetto." >&2
    fi
fi

# Crea la cartella dei risultati solo se non esiste.
# I file gia' presenti vengono mantenuti: pathwyse accoda una riga per run
# a benchmark_times/time_<istanza>.txt, quindi i nuovi risultati si
# aggiungono a quelli delle esecuzioni precedenti.
mkdir -p "$OUTDIR"

# File di configurazione temporanei, rimossi anche in caso di interruzione
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for seed in ${SEEDS[@]+"${SEEDS[@]}"}; do
    awk -v key="$SEED_KEY" -v seed="$seed" '
        { sub(/\r$/, "") }
        $1 == key { print key " = " seed; found = 1; next }
        { print }
        END { if (!found) print key " = " seed }
    ' "$SETTINGS" > "$TMP_DIR/pathwyse_seed_$seed.set"
done

run_instance() {   # $1 = istanza, $2 = nome, $3 = file .set (vuoto = default)
    local i
    for i in $(seq 1 "$RUNS"); do
        if [ -n "$3" ]; then
            "$BIN" "$1" -param "$3" >/dev/null 2>&1 || echo "       [warn] run $i fallito per $2"
        else
            "$BIN" "$1" >/dev/null 2>&1 || echo "       [warn] run $i fallito per $2"
        fi
    done
}

count=0
for f in "$INSTANCE_DIR"/$PATTERN; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    count=$((count + 1))
    echo "[$count] $name"
    if [ "${#SEEDS[@]}" -gt 0 ]; then
        for seed in "${SEEDS[@]}"; do
            echo "    seed $seed  (x$RUNS)"
            run_instance "$f" "$name" "$TMP_DIR/pathwyse_seed_$seed.set"
        done
    else
        echo "    (x$RUNS)"
        run_instance "$f" "$name" ""
    fi
done

echo
echo "Fatto: $count istanze. Risultati in '$OUTDIR/'."
echo "Per le medie:  ./summarize.sh"
