#!/usr/bin/env bash
# Esegue pathwyse RUNS volte su ogni istanza di una cartella.
# I tempi finiscono in  benchmark_times/time_<istanza>.txt  (una riga per run).
#
# Va lanciato dalla ROOT del progetto (dove ci sono pathwyse.set e bin/pathwyse).
#
# Uso:
#   ./run_benchmark.sh [CARTELLA_ISTANZE] [NUMERO_RUN] [PATTERN]
# Esempi:
#   ./run_benchmark.sh instances 10
#   ./run_benchmark.sh instances/spprclib 10 '*.txt'
#
set -euo pipefail

INSTANCE_DIR="${1:-instances}"
RUNS="${2:-10}"
PATTERN="${3:-*.txt}"
BIN="${BIN:-./bin/pathwyse}"
OUTDIR="benchmark_times"

if [ ! -x "$BIN" ]; then
    echo "Binario non trovato/eseguibile: $BIN" >&2
    echo "Lancia dalla root del progetto e assicurati di aver ricompilato." >&2
    exit 1
fi

if ! compgen -G "$INSTANCE_DIR/$PATTERN" > /dev/null; then
    echo "Nessun file '$PATTERN' in '$INSTANCE_DIR'." >&2
    exit 1
fi

mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/time_*.txt   # batch pulito: non accodare a run precedenti

count=0
for f in "$INSTANCE_DIR"/$PATTERN; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    count=$((count + 1))
    echo "[$count] $name  (x$RUNS)"
    for i in $(seq 1 "$RUNS"); do
        "$BIN" "$f" >/dev/null 2>&1 || echo "   [warn] run $i fallito per $name"
    done
done

echo
echo "Fatto: $count istanze. Tempi in '$OUTDIR/'."
echo "Per le medie:  ./summarize.sh"
