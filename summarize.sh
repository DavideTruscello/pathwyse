#!/usr/bin/env bash
# Riassume i file benchmark_times/time_*.txt: per ogni istanza calcola
# numero di run, media, min, max e deviazione standard (campionaria).
# Stampa una tabella ordinata per media e scrive un CSV.
#
# Uso:
#   ./summarize.sh [CARTELLA_TEMPI] [FILE_CSV]
# Default: benchmark_times  ->  summary.csv
#
set -euo pipefail

DIR="${1:-benchmark_times}"
CSV="${2:-summary.csv}"

if ! compgen -G "$DIR/time_*.txt" > /dev/null; then
    echo "Nessun file time_*.txt in '$DIR'. Hai eseguito run_benchmark.sh?" >&2
    exit 1
fi

tmp="$(mktemp)"
for f in "$DIR"/time_*.txt; do
    name="$(basename "$f" .txt)"; name="${name#time_}"
    awk -v name="$name" '
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
done

# ordina per media (colonna 3)
sort -k3,3g "$tmp" -o "$tmp"

# tabella a video
printf "%-28s %5s %12s %12s %12s %12s\n" "instance" "runs" "mean(s)" "min(s)" "max(s)" "stddev(s)"
printf -- '-%.0s' $(seq 1 85); echo
while read -r name runs mean mn mx sd; do
    printf "%-28s %5s %12s %12s %12s %12s\n" "$name" "$runs" "$mean" "$mn" "$mx" "$sd"
done < "$tmp"

# CSV
{
    echo "instance,runs,mean_s,min_s,max_s,stddev_s"
    while read -r name runs mean mn mx sd; do
        echo "$name,$runs,$mean,$mn,$mx,$sd"
    done < "$tmp"
} > "$CSV"

rm -f "$tmp"
echo
echo "Scritto: $CSV"
