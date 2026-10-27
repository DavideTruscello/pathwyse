#!/usr/bin/env bash
# Riassume i file benchmark_times/time_*.txt (righe time,obj,tour_length,seed).
#
# 1) Per ogni istanza: numero di run, media, min, max e deviazione standard
#    (campionaria) del tempo, su tutte le righe. Tabella ordinata per media,
#    scritta anche in FILE_CSV.
# 2) Per ogni coppia (istanza, seed): le stesse statistiche sul tempo, piu'
#    obiettivo migliore (minimo) e medio. Scritta in FILE_CSV_SEED.
#    Le righe senza colonna seed (formato precedente) finiscono sotto seed "n/a".
#
# Uso:
#   ./summarize.sh [CARTELLA_TEMPI] [FILE_CSV] [FILE_CSV_SEED]
# Default: benchmark_times  ->  summary.csv, summary_by_seed.csv
#
set -euo pipefail

DIR="${1:-benchmark_times}"
CSV="${2:-summary.csv}"
CSV_SEED="${3:-summary_by_seed.csv}"

if ! compgen -G "$DIR/time_*.txt" > /dev/null; then
    echo "Nessun file time_*.txt in '$DIR'. Hai eseguito run_benchmark.sh?" >&2
    exit 1
fi

tmp="$(mktemp)"
tmp_seed="$(mktemp)"
trap 'rm -f "$tmp" "$tmp_seed"' EXIT

for f in "$DIR"/time_*.txt; do
    name="$(basename "$f" .txt)"; name="${name#time_}"

    # Statistiche per istanza (prima colonna = tempo)
    awk -F',' -v name="$name" '
        { sub(/\r$/, "") }
        NF { x[++n]=$1+0; s+=$1;
             if(n==1 || $1<mn) mn=$1;
             if(n==1 || $1>mx) mx=$1 }
        END {
            if(n==0) exit;
            m=s/n;
            for(i=1;i<=n;i++){ d=x[i]-m; ss+=d*d }
            sd=(n>1)? sqrt(ss/(n-1)) : 0;
            printf "%s %d %.6f %.6f %.6f %.6f\n", name, n, m, mn, mx, sd
        }' "$f" >> "$tmp"

    # Statistiche per (istanza, seed)
    awk -F',' -v name="$name" '
        { sub(/\r$/, "") }
        NF {
            seed = (NF >= 4 && $4 != "") ? $4 : "n/a";
            if (!(seed in n)) order[++k] = seed;
            t = $1 + 0;
            c = ++n[seed]; x[seed, c] = t; s[seed] += t;
            if (c == 1 || t < mn[seed]) mn[seed] = t;
            if (c == 1 || t > mx[seed]) mx[seed] = t;
            if ($2 != "") {
                o = $2 + 0; no[seed]++; so[seed] += o;
                if (no[seed] == 1 || o < ob[seed]) ob[seed] = o;
            }
        }
        END {
            for (q = 1; q <= k; q++) {
                sd_ = order[q]; m = s[sd_] / n[sd_]; ss = 0;
                for (i = 1; i <= n[sd_]; i++) { d = x[sd_, i] - m; ss += d * d }
                dev = (n[sd_] > 1) ? sqrt(ss / (n[sd_] - 1)) : 0;
                best = (no[sd_] > 0) ? sprintf("%d", ob[sd_]) : "-";
                avg  = (no[sd_] > 0) ? sprintf("%.2f", so[sd_] / no[sd_]) : "-";
                printf "%s %s %d %.6f %.6f %.6f %.6f %s %s\n",
                       name, sd_, n[sd_], m, mn[sd_], mx[sd_], dev, best, avg
            }
        }' "$f" >> "$tmp_seed"
done

# ordina per media (colonna 3); per seed: istanza, poi seed numerico
sort -k3,3g "$tmp" -o "$tmp"
sort -k1,1 -k2,2g "$tmp_seed" -o "$tmp_seed"

# --- Tabella per istanza ---
printf "%-28s %5s %12s %12s %12s %12s\n" "instance" "runs" "mean(s)" "min(s)" "max(s)" "stddev(s)"
printf -- '-%.0s' $(seq 1 85); echo
while read -r name runs mean mn mx sd; do
    printf "%-28s %5s %12s %12s %12s %12s\n" "$name" "$runs" "$mean" "$mn" "$mx" "$sd"
done < "$tmp"

{
    echo "instance,runs,mean_s,min_s,max_s,stddev_s"
    while read -r name runs mean mn mx sd; do
        echo "$name,$runs,$mean,$mn,$mx,$sd"
    done < "$tmp"
} > "$CSV"

# --- Tabella per seed ---
echo
printf "%-28s %8s %5s %12s %12s %12s %12s %12s %14s\n" \
    "instance" "seed" "runs" "mean(s)" "min(s)" "max(s)" "stddev(s)" "best_obj" "mean_obj"
printf -- '-%.0s' $(seq 1 123); echo
while read -r name seed runs mean mn mx sd best avg; do
    printf "%-28s %8s %5s %12s %12s %12s %12s %12s %14s\n" \
        "$name" "$seed" "$runs" "$mean" "$mn" "$mx" "$sd" "$best" "$avg"
done < "$tmp_seed"

{
    echo "instance,seed,runs,mean_s,min_s,max_s,stddev_s,best_obj,mean_obj"
    while read -r name seed runs mean mn mx sd best avg; do
        echo "$name,$seed,$runs,$mean,$mn,$mx,$sd,$best,$avg"
    done < "$tmp_seed"
} > "$CSV_SEED"

echo
echo "Scritti: $CSV, $CSV_SEED"
