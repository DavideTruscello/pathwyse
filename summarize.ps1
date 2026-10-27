param(
    [string]$Dir = "benchmark_times",
    [string]$Csv = "summary.csv",
    [string]$CsvSeed = "summary_by_seed.csv"
)

# Riassume i file benchmark_times/time_*.txt (righe time,obj,tour_length,seed).
#
# 1) Per ogni istanza: numero di run, media, min, max e deviazione standard
#    (campionaria) del tempo, su tutte le righe. Tabella ordinata per media,
#    scritta anche in $Csv.
# 2) Per ogni coppia (istanza, seed): le stesse statistiche sul tempo, piu'
#    obiettivo migliore (minimo) e medio. Scritta in $CsvSeed.
#    Le righe senza colonna seed (formato precedente) finiscono sotto seed "n/a".

$inv = [Globalization.CultureInfo]::InvariantCulture

function Get-Stats([double[]]$values) {
    $n = $values.Count
    $mean = ($values | Measure-Object -Average).Average
    $min = ($values | Measure-Object -Minimum).Minimum
    $max = ($values | Measure-Object -Maximum).Maximum
    $stddev = 0.0
    if ($n -gt 1) {
        $sumSquares = 0.0
        foreach ($value in $values) {
            $difference = $value - $mean
            $sumSquares += $difference * $difference
        }
        $stddev = [Math]::Sqrt($sumSquares / ($n - 1))
    }
    return [PSCustomObject]@{ Runs = $n; Mean = $mean; Min = $min; Max = $max; StdDev = $stddev }
}

# Cerca i file dei tempi
$files = @(Get-ChildItem -Path $Dir -Filter "time_*.txt" -File -ErrorAction SilentlyContinue)

if ($files.Count -eq 0) {
    Write-Error "Nessun file time_*.txt in '$Dir'. Hai eseguito run_benchmark.ps1?"
    exit 1
}

$results = @()
$seedResults = @()

foreach ($file in $files) {

    $name = $file.BaseName -replace "^time_", ""

    # Righe CSV: time,obj,tour_length[,seed]
    $rows = @(Get-Content $file.FullName |
        Where-Object { $_.Trim() -ne "" } |
        ForEach-Object {
            $parts = $_.Trim() -split ","
            [PSCustomObject]@{
                Time = [double]::Parse($parts[0], $inv)
                Obj  = if ($parts.Count -ge 2 -and $parts[1] -ne "") { [double]::Parse($parts[1], $inv) } else { $null }
                Seed = if ($parts.Count -ge 4 -and $parts[3] -ne "") { $parts[3] } else { "n/a" }
            }
        })

    if ($rows.Count -eq 0) {
        continue
    }

    # 1) Per istanza
    $stats = Get-Stats ([double[]]($rows | ForEach-Object { $_.Time }))
    $results += [PSCustomObject]@{
        instance = $name
        runs     = $stats.Runs
        mean_s   = $stats.Mean
        min_s    = $stats.Min
        max_s    = $stats.Max
        stddev_s = $stats.StdDev
    }

    # 2) Per (istanza, seed)
    foreach ($group in ($rows | Group-Object Seed)) {
        $stats = Get-Stats ([double[]]($group.Group | ForEach-Object { $_.Time }))
        $objs = @($group.Group | Where-Object { $null -ne $_.Obj } | ForEach-Object { $_.Obj })
        $seedResults += [PSCustomObject]@{
            instance = $name
            seed     = $group.Name
            runs     = $stats.Runs
            mean_s   = $stats.Mean
            min_s    = $stats.Min
            max_s    = $stats.Max
            stddev_s = $stats.StdDev
            best_obj = if ($objs.Count -gt 0) { ($objs | Measure-Object -Minimum).Minimum } else { "-" }
            mean_obj = if ($objs.Count -gt 0) { ($objs | Measure-Object -Average).Average } else { "-" }
        }
    }
}

# Ordina per media; per seed: istanza, poi seed numerico ("n/a" in fondo)
$results = @($results | Sort-Object mean_s)
$seedResults = @($seedResults | Sort-Object instance, @{ Expression = {
    $v = 0; if ([int]::TryParse($_.seed, [ref]$v)) { $v } else { [int]::MaxValue } } })

function Format-Num($value, [string]$format) {
    if ($value -is [string]) { return $value }
    return ([double]$value).ToString($format, $inv)
}

# --- Tabella per istanza ---
Write-Host ("{0,-28} {1,5} {2,12} {3,12} {4,12} {5,12}" -f `
    "instance", "runs", "mean(s)", "min(s)", "max(s)", "stddev(s)")
Write-Host ("-" * 85)
foreach ($r in $results) {
    Write-Host ("{0,-28} {1,5} {2,12} {3,12} {4,12} {5,12}" -f `
        $r.instance, $r.runs,
        (Format-Num $r.mean_s "F6"), (Format-Num $r.min_s "F6"),
        (Format-Num $r.max_s "F6"), (Format-Num $r.stddev_s "F6"))
}

# --- Tabella per seed ---
Write-Host ""
Write-Host ("{0,-28} {1,8} {2,5} {3,12} {4,12} {5,12} {6,12} {7,12} {8,14}" -f `
    "instance", "seed", "runs", "mean(s)", "min(s)", "max(s)", "stddev(s)", "best_obj", "mean_obj")
Write-Host ("-" * 123)
foreach ($r in $seedResults) {
    Write-Host ("{0,-28} {1,8} {2,5} {3,12} {4,12} {5,12} {6,12} {7,12} {8,14}" -f `
        $r.instance, $r.seed, $r.runs,
        (Format-Num $r.mean_s "F6"), (Format-Num $r.min_s "F6"),
        (Format-Num $r.max_s "F6"), (Format-Num $r.stddev_s "F6"),
        (Format-Num $r.best_obj "F0"), (Format-Num $r.mean_obj "F2"))
}

# --- CSV (numeri sempre con il punto decimale, indipendentemente dalla lingua di Windows) ---
$csvLines = @("instance,runs,mean_s,min_s,max_s,stddev_s")
foreach ($r in $results) {
    $csvLines += ($r.instance, $r.runs,
        (Format-Num $r.mean_s "F6"), (Format-Num $r.min_s "F6"),
        (Format-Num $r.max_s "F6"), (Format-Num $r.stddev_s "F6")) -join ","
}
$csvLines | Set-Content -Path $Csv -Encoding ascii

$csvSeedLines = @("instance,seed,runs,mean_s,min_s,max_s,stddev_s,best_obj,mean_obj")
foreach ($r in $seedResults) {
    $csvSeedLines += ($r.instance, $r.seed, $r.runs,
        (Format-Num $r.mean_s "F6"), (Format-Num $r.min_s "F6"),
        (Format-Num $r.max_s "F6"), (Format-Num $r.stddev_s "F6"),
        (Format-Num $r.best_obj "F0"), (Format-Num $r.mean_obj "F2")) -join ","
}
$csvSeedLines | Set-Content -Path $CsvSeed -Encoding ascii

Write-Host ""
Write-Host "Scritti: $Csv, $CsvSeed"
