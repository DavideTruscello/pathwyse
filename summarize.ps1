param(
    [string]$Dir = "benchmark_times",
    [string]$Csv = "summary.csv"
)

# Cerca i file dei tempi
$files = Get-ChildItem -Path $Dir -Filter "time_*.txt" -File -ErrorAction SilentlyContinue

if ($files.Count -eq 0) {
    Write-Error "Nessun file time_*.txt in '$Dir'. Hai eseguito run_benchmark.ps1?"
    exit 1
}

$results = @()

foreach ($file in $files) {

    $name = $file.BaseName -replace "^time_", ""

    # Legge i tempi e converte ogni riga in numero
    $values = Get-Content $file.FullName |
        Where-Object { $_.Trim() -ne "" } |
        ForEach-Object { [double]$_ }

    if ($values.Count -eq 0) {
        continue
    }

    $runs = $values.Count

    $mean = ($values | Measure-Object -Average).Average
    $min = ($values | Measure-Object -Minimum).Minimum
    $max = ($values | Measure-Object -Maximum).Maximum

    # Deviazione standard campionaria
    if ($runs -gt 1) {
        $sumSquares = 0.0

        foreach ($value in $values) {
            $difference = $value - $mean
            $sumSquares += $difference * $difference
        }

        $stddev = [Math]::Sqrt($sumSquares / ($runs - 1))
    }
    else {
        $stddev = 0.0
    }

    $results += [PSCustomObject]@{
        instance = $name
        runs     = $runs
        mean_s   = $mean
        min_s    = $min
        max_s    = $max
        stddev_s = $stddev
    }
}

# Ordina per media
$results = $results | Sort-Object mean_s

# Tabella a video
Write-Host ("{0,-28} {1,5} {2,12} {3,12} {4,12} {5,12}" -f `
    "instance", "runs", "mean(s)", "min(s)", "max(s)", "stddev(s)")

Write-Host ("-" * 85)

foreach ($result in $results) {
    Write-Host ("{0,-28} {1,5} {2,12:F6} {3,12:F6} {4,12:F6} {5,12:F6}" -f `
        $result.instance,
        $result.runs,
        $result.mean_s,
        $result.min_s,
        $result.max_s,
        $result.stddev_s)
}

# Scrive il CSV
$results |
    Select-Object instance, runs, mean_s, min_s, max_s, stddev_s |
    Export-Csv -Path $Csv -NoTypeInformation

Write-Host ""
Write-Host "Scritto: $Csv"