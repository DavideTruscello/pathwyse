#!/usr/bin/env bash
# =====================================================================================
# CAMPAGNA DI BENCHMARK
# =====================================================================================
#
# Esegue in sequenza, su tutte le istanze di una cartella, i 5 casi della campagna:
#
#   opt    ottimo vero          riduzione archi spenta (intera rete)
#   detP   deterministico       cutoff/k1/k2 = 0.2, is_deterministic = 1, join sulla sottorete
#   detF   deterministico       cutoff/k1/k2 = 0.2, is_deterministic = 1, join sull'intera rete
#   stoP   stocastico           cutoff/k1/k2 = 0.2, is_deterministic = 0, temperature = 0.5,
#                               join sulla sottorete, un seed diverso per ogni ripetizione
#   stoF   stocastico           come stoP, ma join sull'intera rete
#
# Ogni caso viene eseguito 10 volte per istanza. Nei casi stocastici la ripetizione r usa
# l'r-esimo seed del file dei seed (servono almeno 10 seed).
#
# Ordine: ripetizione 1 di tutte le istanze e di tutti i casi, poi ripetizione 2, e cosi' via.
# Se la campagna si interrompe, le ripetizioni gia' finite sono complete per tutti i casi.
#
# Lo script:
#   - ricompila il progetto (cartella build/) prima di partire;
#   - si mette da solo in background: si puo' chiudere il terminale o la sessione SSH;
#   - scrive i risultati in benchmark/result_it.csv e benchmark/result_intl.csv
#     e l'avanzamento in benchmark/campaign.log;
#   - se viene rilanciato dopo un'interruzione, riprende da dove si era fermato
#     (le esecuzioni gia' fatte sono elencate in benchmark/campaign_progress.txt);
#   - non modifica pathwyse.set: per ogni caso crea una copia temporanea con i parametri giusti.
#
# Limiti di tempo per ogni esecuzione:
#   - interno (algo/default/timelimit): 120 s. Il programma si ferma alla fine del giro di DSSR
#     in corso e scrive normalmente la sua riga;
#   - esterno: 300 s. Se il programma e' ancora in esecuzione viene interrotto e lo script
#     scrive al suo posto una riga con status = Killed.
#
# Va lanciato dalla ROOT del progetto.
#
# Uso:
#   ./run_campaign.sh FILE_SEED [CARTELLA_ISTANZE]
#
#   FILE_SEED         obbligatorio. Un seed per riga (righe vuote e commenti # ignorati).
#   CARTELLA_ISTANZE  default: instances/campaign
#
# Opzioni avanzate (variabili d'ambiente, servono soprattutto allo script di prova):
#   CAMPAIGN_REPS        ripetizioni per caso               (default 10)
#   CAMPAIGN_TIMELIMIT   limite interno in secondi          (default 120)
#   CAMPAIGN_TIMEOUT     limite esterno in secondi          (default 300)
#   CAMPAIGN_WORKDIR     cartella in cui creare benchmark/  (default: root del progetto)
#   CAMPAIGN_FOREGROUND  1 = non andare in background       (default 0)
#   CAMPAIGN_NO_BUILD    1 = non ricompilare                (default 0)
# =====================================================================================

if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

usage() {
    sed -n '/^# Uso:/,/^#   CARTELLA_ISTANZE/p' "$0" | sed 's/^# \{0,1\}//' >&2
}

die() {
    echo "Errore: $*" >&2
    exit 1
}

# ------------------------------------------------------------------ argomenti e impostazioni

if [ $# -lt 1 ] || [ -z "$1" ]; then
    echo "Errore: manca il file dei seed." >&2
    echo >&2
    usage
    exit 1
fi

ROOT="$(pwd)"
SEEDS_FILE="$1"
INSTANCE_DIR="${2:-instances/campaign}"

REPS="${CAMPAIGN_REPS:-10}"
TIMELIMIT="${CAMPAIGN_TIMELIMIT:-120}"
TIMEOUT_S="${CAMPAIGN_TIMEOUT:-300}"
WORKDIR="${CAMPAIGN_WORKDIR:-$ROOT}"
FOREGROUND="${CAMPAIGN_FOREGROUND:-0}"
NO_BUILD="${CAMPAIGN_NO_BUILD:-0}"

BIN="$ROOT/bin/pathwyse"
SETTINGS="$ROOT/pathwyse.set"

[ -f "$SETTINGS" ] || die "pathwyse.set non trovato: lancia lo script dalla root del progetto."
[ -f "$ROOT/CMakeLists.txt" ] || die "CMakeLists.txt non trovato: lancia lo script dalla root del progetto."
[ -d "$INSTANCE_DIR" ] || die "cartella delle istanze non trovata: $INSTANCE_DIR"
[ -f "$SEEDS_FILE" ] || die "file dei seed non trovato: $SEEDS_FILE"
command -v timeout > /dev/null || die "il comando 'timeout' non e' disponibile (pacchetto coreutils)."
[[ "$REPS" =~ ^[0-9]+$ ]] && [ "$REPS" -ge 1 ] || die "CAMPAIGN_REPS non valido: $REPS"
[[ "$TIMELIMIT" =~ ^[0-9]+$ ]] || die "CAMPAIGN_TIMELIMIT non valido: $TIMELIMIT"
[[ "$TIMEOUT_S" =~ ^[0-9]+$ ]] && [ "$TIMEOUT_S" -ge 1 ] || die "CAMPAIGN_TIMEOUT non valido: $TIMEOUT_S"

# Percorsi assoluti (lo script lavora in WORKDIR)
INSTANCE_DIR="$(cd "$INSTANCE_DIR" && pwd)"
SEEDS_FILE="$(cd "$(dirname "$SEEDS_FILE")" && pwd)/$(basename "$SEEDS_FILE")"
mkdir -p "$WORKDIR"
WORKDIR="$(cd "$WORKDIR" && pwd)"

OUTDIR="$WORKDIR/benchmark"
LOG="$OUTDIR/campaign.log"
PROGRESS="$OUTDIR/campaign_progress.txt"
CSV_INTL="$OUTDIR/result_intl.csv"
CSV_IT="$OUTDIR/result_it.csv"
HEADER="file,arcs_active,is_deterministic,full_network,cutoff,k1,k2,seed,temperature,status,obj,total_time,tour_length,dssr_iterations,datetime"

# Seed: un intero per riga, servono almeno REPS seed
SEEDS=()
n=0
while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    value="${line%%#*}"
    value="${value//$'\r'/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    [ -z "$value" ] && continue
    [[ "$value" =~ ^-?[0-9]+$ ]] || die "seed non valido alla riga $n di $SEEDS_FILE: '$value'"
    SEEDS+=("$value")
done < "$SEEDS_FILE"
[ "${#SEEDS[@]}" -ge "$REPS" ] || die "servono almeno $REPS seed in $SEEDS_FILE (trovati ${#SEEDS[@]})."

# Istanze: tutti i file della cartella (sottocartelle escluse), in ordine alfabetico
INSTANCES=()
for f in "$INSTANCE_DIR"/*; do
    [ -f "$f" ] && INSTANCES+=("$f")
done
[ "${#INSTANCES[@]}" -gt 0 ] || die "nessun file in $INSTANCE_DIR"

# ------------------------------------------------------------------ avvio in background

mkdir -p "$OUTDIR"

if [ "$FOREGROUND" != "1" ] && [ -z "${CAMPAIGN_CHILD:-}" ]; then
    if [ -f "$OUTDIR/campaign.pid" ] && kill -0 "$(cat "$OUTDIR/campaign.pid")" 2> /dev/null; then
        die "una campagna e' gia' in esecuzione (PID $(cat "$OUTDIR/campaign.pid")). Log: $LOG"
    fi
    CAMPAIGN_CHILD=1 nohup bash "$0" "$@" >> "$LOG" 2>&1 < /dev/null &
    echo $! > "$OUTDIR/campaign.pid"
    echo "Campagna avviata in background (PID $!)."
    echo "Si puo' chiudere il terminale. Per seguire l'avanzamento:"
    echo "    tail -f $LOG"
    echo "Per fermarla:"
    echo "    kill $!"
    exit 0
fi

# ------------------------------------------------------------------ compilazione

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

if grep -q 'add_compile_options(-O0' "$ROOT/src/CMakeLists.txt"; then
    die "src/CMakeLists.txt compila ancora senza ottimizzazioni (-O0): i tempi non sarebbero attendibili."
fi

if [ "$NO_BUILD" != "1" ]; then
    log "Compilazione..."
    mkdir -p "$ROOT/build"
    ( cd "$ROOT/build" && cmake .. > /dev/null && make -j"$(nproc 2> /dev/null || echo 2)" pathwyse > /dev/null ) \
        || die "compilazione fallita."
    log "Compilazione completata."
fi
[ -x "$BIN" ] || die "eseguibile non trovato: $BIN"

# ------------------------------------------------------------------ casi della campagna

#        nome  arcs_active  is_deterministic  full_network  stocastico
CASES=( "opt   0 1 0 0"
        "detP  1 1 0 0"
        "detF  1 1 1 0"
        "stoP  1 0 0 1"
        "stoF  1 0 1 1" )

CUTOFF="0.2"
K1="0.2"
K2="0.2"
TEMPERATURE="0.5"
DET_SEED="0"            # seed scritto nei casi non stocastici (non ha effetto)

TMP_DIR="$(mktemp -d)"
CHILD_PID=""
trap 'rm -rf "$TMP_DIR"' EXIT
# Se la campagna viene fermata (kill, Ctrl+C) termina anche l'esecuzione in corso
trap '[ -n "$CHILD_PID" ] && kill "$CHILD_PID" 2> /dev/null; log "Campagna interrotta."; rm -f "$OUTDIR/campaign.pid"; exit 1' TERM INT

# Copia di pathwyse.set con i parametri forzati ($1 = destinazione, poi coppie chiave valore)
make_settings() {
    local dest="$1"
    shift
    awk -v pairs="$*" '
        BEGIN {
            n = split(pairs, a, " ")
            for (i = 1; i < n; i += 2) { val[a[i]] = a[i + 1]; order[++k] = a[i] }
        }
        { sub(/\r$/, "") }
        ($1 in val) { print $1 " = " val[$1]; done[$1] = 1; next }
        { print }
        END { for (i = 1; i <= k; i++) if (!(order[i] in done)) print order[i] " = " val[order[i]] }
    ' "$SETTINGS" > "$dest"
}

settings_for() {    # $1 = arcs_active  $2 = is_deterministic  $3 = full_network  $4 = seed
    local dest="$TMP_DIR/case_$1_$2_$3_$4.set"
    if [ ! -f "$dest" ]; then
        make_settings "$dest" \
            verbosity 0 \
            output/benchmark 1 \
            algo/default/timelimit "$TIMELIMIT" \
            algo/default/join/type ordered \
            algo/requested_solutions 1 \
            algo/default/join/full_network "$3" \
            algo/default/graph_reduction/nodes/active 0 \
            algo/default/graph_reduction/arcs/active "$1" \
            algo/default/graph_reduction/arcs/is_deterministic "$2" \
            algo/default/graph_reduction/arcs/cutoff "$CUTOFF" \
            algo/default/graph_reduction/arcs/k1 "$K1" \
            algo/default/graph_reduction/arcs/k2 "$K2" \
            algo/default/graph_reduction/arcs/temperature "$TEMPERATURE" \
            algo/default/graph_reduction/arcs/seed "$4"
    fi
    echo "$dest"
}

# Riga scritta dallo script quando il programma non ne scrive una (interrotto o errore)
append_script_row() {   # $1 file  $2 active  $3 det  $4 full  $5 seed  $6 status  $7 tempo
    local now
    now="$(date '+%Y-%m-%d %H:%M:%S')"
    if [ ! -f "$CSV_INTL" ]; then echo "$HEADER" > "$CSV_INTL"; fi
    if [ ! -f "$CSV_IT" ]; then echo "${HEADER//,/;}" > "$CSV_IT"; fi
    echo "$1,$2,$3,$4,$CUTOFF,$K1,$K2,$5,$TEMPERATURE,$6,,$7,,,$now" >> "$CSV_INTL"
    echo "$1;$2;$3;$4;${CUTOFF/./,};${K1/./,};${K2/./,};$5;${TEMPERATURE/./,};$6;;${7/./,};;;$now" >> "$CSV_IT"
}

# ------------------------------------------------------------------ esecuzione

cd "$WORKDIR"
touch "$PROGRESS"

if [ -f "$CSV_INTL" ] && [ "$(head -n 1 "$CSV_INTL" | tr -d '\r')" != "$HEADER" ]; then
    die "$CSV_INTL ha colonne diverse da quelle attuali: cancellalo o rinominalo."
fi

TOTAL=$(( REPS * ${#INSTANCES[@]} * ${#CASES[@]} ))
DONE_BEFORE=$(grep -c . "$PROGRESS" || true)

log "Inizio campagna"
log "  istanze:      ${#INSTANCES[@]} (da $INSTANCE_DIR)"
log "  ripetizioni:  $REPS per caso"
log "  casi:         opt detP detF stoP stoF"
log "  limiti:       interno ${TIMELIMIT} s, esterno ${TIMEOUT_S} s"
log "  esecuzioni:   $TOTAL in totale, $DONE_BEFORE gia' fatte"
log "  risultati:    $CSV_IT e $CSV_INTL"

count=0
start_all=$(date +%s)

for (( r = 1; r <= REPS; r++ )); do
    stoch_seed="${SEEDS[$((r - 1))]}"
    for inst in "${INSTANCES[@]}"; do
        name="$(basename "$inst")"
        for c in "${CASES[@]}"; do
            read -r cname active det full stoch <<< "$c"
            count=$((count + 1))
            key="rep=$r|case=$cname|file=$name"

            if grep -qxF "$key" "$PROGRESS"; then
                continue
            fi

            if [ "$stoch" = "1" ]; then seed="$stoch_seed"; else seed="$DET_SEED"; fi
            set_file="$(settings_for "$active" "$det" "$full" "$seed")"

            t0=$(date +%s.%N)
            rc=0
            timeout --kill-after=10 "$TIMEOUT_S" "$BIN" "$inst" -param "$set_file" > /dev/null 2>&1 &
            CHILD_PID=$!
            wait "$CHILD_PID" || rc=$?
            CHILD_PID=""
            t1=$(date +%s.%N)
            elapsed=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.2f", b - a }')

            if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
                append_script_row "$name" "$active" "$det" "$full" "$seed" "Killed" "$elapsed"
                outcome="INTERROTTO dopo ${TIMEOUT_S} s"
            elif [ "$rc" -ne 0 ]; then
                append_script_row "$name" "$active" "$det" "$full" "$seed" "Error" "$elapsed"
                outcome="ERRORE (codice $rc)"
            else
                outcome="ok"
            fi

            echo "$key" >> "$PROGRESS"
            log "[$count/$TOTAL] rep $r  $cname  $name  ${elapsed} s  $outcome"
        done
    done
    log "Ripetizione $r di $REPS completata."
done

end_all=$(date +%s)
log "Campagna terminata in $(( (end_all - start_all) / 60 )) minuti."
log "Risultati: $CSV_IT e $CSV_INTL"
rm -f "$OUTDIR/campaign.pid"
