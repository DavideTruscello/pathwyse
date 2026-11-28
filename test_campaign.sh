#!/usr/bin/env bash
# =====================================================================================
# PROVA VELOCE DELLA CAMPAGNA DI BENCHMARK (2-3 minuti)
# =====================================================================================
#
# Esegue run_campaign.sh in versione ridotta e controlla che tutto funzioni:
#   - 3 istanze del repository: toy.txt, A-n54-k7-149 (veloce) e M-n200-k17-12 (lenta,
#     serve a verificare l'interruzione dopo il limite esterno);
#   - 2 ripetizioni invece di 10, con i primi 2 seed del file dei seed;
#   - limite esterno di 4 secondi invece di 300.
#
# I risultati della prova vengono scritti in una cartella temporanea: la cartella benchmark/
# del progetto (con i risultati veri) non viene toccata.
#
# Alla fine stampa PROVA SUPERATA oppure l'elenco dei problemi trovati.
#
# Va lanciato dalla ROOT del progetto.
#
# Uso:
#   ./test_campaign.sh FILE_SEED
#
#   FILE_SEED   lo stesso file dei seed che si usera' per la campagna vera.
# =====================================================================================

if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -uo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
    echo "Errore: manca il file dei seed." >&2
    echo "Uso: ./test_campaign.sh FILE_SEED" >&2
    exit 1
fi

ROOT="$(pwd)"
SEEDS_FILE="$1"
CAMPAIGN="$ROOT/run_campaign.sh"

[ -f "$CAMPAIGN" ] || { echo "Errore: run_campaign.sh non trovato: lancia dalla root del progetto." >&2; exit 1; }
[ -f "$SEEDS_FILE" ] || { echo "Errore: file dei seed non trovato: $SEEDS_FILE" >&2; exit 1; }

REPS=2
TEST_INSTANCES=(
    "instances/toy.txt"
    "instances/more_instances/spprclib/A-n54-k7-149.sppcc"
    "instances/more_instances/spprclib/M-n200-k17-12.sppcc"
)
SLOW_INSTANCE="M-n200-k17-12.sppcc"
HEADER="file,arcs_active,is_deterministic,full_network,cutoff,k1,k2,seed,temperature,status,obj,total_time,tour_length,dssr_iterations,datetime"

ERRORS=()
fail() { ERRORS+=("$*"); }

TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pathwyse_test_campaign.XXXXXX")"
mkdir -p "$TEST_DIR/instances"
for f in "${TEST_INSTANCES[@]}"; do
    [ -f "$ROOT/$f" ] || { echo "Errore: istanza di prova non trovata: $f" >&2; exit 1; }
    cp "$ROOT/$f" "$TEST_DIR/instances/"
done

# Controllo del file dei seed: la campagna vera ne richiede almeno 10
n_seeds=$(sed 's/#.*//' "$SEEDS_FILE" | tr -d '\r' | grep -cE '^[[:space:]]*-?[0-9]+[[:space:]]*$' || true)
if [ "$n_seeds" -lt 10 ]; then
    fail "il file dei seed contiene $n_seeds seed: la campagna vera ne richiede almeno 10"
fi
SEED1=$(sed 's/#.*//' "$SEEDS_FILE" | tr -d '\r' | grep -E '^[[:space:]]*-?[0-9]+[[:space:]]*$' | sed -n 1p | tr -d '[:space:]')
SEED2=$(sed 's/#.*//' "$SEEDS_FILE" | tr -d '\r' | grep -E '^[[:space:]]*-?[0-9]+[[:space:]]*$' | sed -n 2p | tr -d '[:space:]')

echo "=== 1. Esecuzione della campagna di prova (compilazione inclusa)"
echo "    cartella della prova: $TEST_DIR"
echo

run_test_campaign() {
    CAMPAIGN_REPS=$REPS CAMPAIGN_TIMEOUT=4 CAMPAIGN_TIMELIMIT=120 \
    CAMPAIGN_WORKDIR="$TEST_DIR" CAMPAIGN_FOREGROUND=1 CAMPAIGN_NO_BUILD="$1" \
        bash "$CAMPAIGN" "$SEEDS_FILE" "$TEST_DIR/instances"
}

if ! run_test_campaign 0; then
    echo
    echo "PROVA FALLITA: run_campaign.sh si e' fermato con un errore (vedi sopra)."
    exit 1
fi

INTL="$TEST_DIR/benchmark/result_intl.csv"
IT="$TEST_DIR/benchmark/result_it.csv"

echo
echo "=== 2. Controllo dei risultati"

[ -f "$INTL" ] || fail "result_intl.csv non creato"
[ -f "$IT" ] || fail "result_it.csv non creato"

if [ -f "$INTL" ] && [ -f "$IT" ]; then

    # Intestazioni
    [ "$(head -n 1 "$INTL")" = "$HEADER" ] || fail "intestazione di result_intl.csv errata"
    [ "$(head -n 1 "$IT")" = "${HEADER//,/;}" ] || fail "intestazione di result_it.csv errata"

    # Numero di righe: ripetizioni x istanze x 5 casi
    expected=$(( REPS * ${#TEST_INSTANCES[@]} * 5 ))
    rows=$(( $(wc -l < "$INTL") - 1 ))
    rows_it=$(( $(wc -l < "$IT") - 1 ))
    [ "$rows" -eq "$expected" ] || fail "result_intl.csv: $rows righe invece di $expected"
    [ "$rows_it" -eq "$expected" ] || fail "result_it.csv: $rows_it righe invece di $expected"

    # I due file devono avere lo stesso contenuto (cambiano solo separatori e decimali)
    if ! diff -q <(tail -n +2 "$IT" | sed 's/,/./g; s/;/,/g') <(tail -n +2 "$INTL") > /dev/null; then
        fail "result_it.csv e result_intl.csv non hanno lo stesso contenuto"
    fi

    # Controlli riga per riga su result_intl.csv
    problems=$(awk -F',' -v reps="$REPS" -v s1="$SEED1" -v s2="$SEED2" -v slow="$SLOW_INSTANCE" '
        NR == 1 { next }
        {
            if (NF != 15) { print "riga " NR ": " NF " colonne invece di 15"; next }
            c = "?"
            if ($2 == 0)                         c = "opt"
            else if ($3 == 1 && $4 == 0)         c = "detP"
            else if ($3 == 1 && $4 == 1)         c = "detF"
            else if ($3 == 0 && $4 == 0)         c = "stoP"
            else if ($3 == 0 && $4 == 1)         c = "stoF"
            count[c]++
            if ($5 != "0.2" || $6 != "0.2" || $7 != "0.2") print "riga " NR ": cutoff/k1/k2 diversi da 0.2"
            if ($9 != "0.5") print "riga " NR ": temperature diversa da 0.5"
            if ((c == "stoP" || c == "stoF") && $8 != s1 && $8 != s2) print "riga " NR ": seed " $8 " non tra i primi due del file"
            if ($15 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/) print "riga " NR ": datetime non valido (" $15 ")"
            if ($10 != "Killed" && $10 != "Optimal" && $10 != "Feasible" && $10 != "Superoptimal" && $10 != "NoSolution")
                print "riga " NR ": status inatteso " $10
            # Valori noti: con la riduzione e il join sulla sottorete toy.txt peggiora
            if ($1 == "toy.txt" && c == "opt"  && $11 != "-10435") print "riga " NR ": toy.txt opt obj " $11 " invece di -10435"
            if ($1 == "toy.txt" && c == "detP" && $11 != "121565") print "riga " NR ": toy.txt detP obj " $11 " invece di 121565"
            if ($1 == "toy.txt" && c == "detF" && $11 != "-10435") print "riga " NR ": toy.txt detF obj " $11 " invece di -10435"
            if ($1 == "A-n54-k7-149.sppcc" && c == "opt" && $11 != "-12492") print "riga " NR ": A-n54 opt obj " $11 " invece di -12492"
            if ($1 == slow && c == "opt" && $10 == "Killed") killed++
        }
        END {
            split("opt detP detF stoP stoF", names, " ")
            for (i = 1; i <= 5; i++)
                if (count[names[i]] != reps * 3) print "caso " names[i] ": " count[names[i]] + 0 " righe invece di " reps * 3
            if (count["?"] > 0) print count["?"] " righe con combinazione di parametri sconosciuta"
            if (killed != reps) print slow " (opt): " killed + 0 " righe Killed invece di " reps " (interruzione dopo il limite esterno non verificata)"
        }
    ' "$INTL")
    while IFS= read -r p; do
        [ -n "$p" ] && fail "$p"
    done <<< "$problems"
fi

echo
echo "=== 3. Ripresa: rilancio della stessa campagna (non deve aggiungere righe)"
before=$(wc -l < "$INTL" 2> /dev/null || echo 0)
if ! run_test_campaign 1 > /dev/null 2>&1; then
    fail "il rilancio della campagna si e' fermato con un errore"
fi
after=$(wc -l < "$INTL" 2> /dev/null || echo 0)
[ "$before" -eq "$after" ] || fail "il rilancio ha aggiunto $((after - before)) righe: la ripresa non funziona"

echo
echo "=== Esito"
if [ "${#ERRORS[@]}" -eq 0 ]; then
    echo "PROVA SUPERATA: si puo' lanciare la campagna vera con"
    echo "    ./run_campaign.sh $SEEDS_FILE"
    rm -rf "$TEST_DIR"
    exit 0
else
    echo "PROVA FALLITA. Problemi trovati:"
    for e in "${ERRORS[@]}"; do
        echo "  - $e"
    done
    echo
    echo "I file della prova sono in: $TEST_DIR"
    exit 1
fi
