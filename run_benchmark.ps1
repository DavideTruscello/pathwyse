<#
Esegue pathwyse su tutte le istanze di una cartella e raccoglie i risultati in
    benchmark\result_intl.csv   (separatore ","  decimali con ".")
    benchmark\result_it.csv     (separatore ";"  decimali con ",", per Excel in italiano)
Ogni esecuzione aggiunge una riga a entrambi i file (che non vengono mai svuotati).

Lo script crea una copia temporanea del file di configurazione con
    output/benchmark = 1
(e, se si passa un file dei seed, con il seed di ogni esecuzione).
Il file di configurazione originale non viene mai modificato.

Va lanciato dalla ROOT del progetto (dove ci sono pathwyse.set e bin\pathwyse.exe).

Parametri:
  -InstanceDir  obbligatorio. Le sottocartelle non vengono esplorate.
  -Runs         quante volte eseguire ogni istanza (per ogni seed). Default: 1
  -Pattern      quali file della cartella usare. Default: * (tutti i file)
  -SeedsFile    file con un seed per riga. Default: nessuno (si usa il seed
                scritto nel file di configurazione)
  -Settings     file di configurazione. Default: pathwyse.set

Esempi:
  .\run_benchmark.ps1 instances\more_instances\spprclib
  .\run_benchmark.ps1 instances\more_instances\spprclib 1 *.sppcc
  .\run_benchmark.ps1 -InstanceDir instances\more_instances\spprclib -Runs 3 -SeedsFile seeds.txt
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InstanceDir,
    [Parameter(Position = 1)]
    [int]$Runs = 1,
    [Parameter(Position = 2)]
    [string]$Pattern = "*",
    [Parameter(Position = 3)]
    [string]$SeedsFile = "",
    [string]$Settings = "pathwyse.set"
)

$Bin = ".\bin\pathwyse.exe"
$OutDir = "benchmark"
$SeedKey = "algo/default/graph_reduction/arcs/seed"
$BenchKey = "output/benchmark"

# Controlla che il programma esista
if (-not (Test-Path $Bin -PathType Leaf)) {
    Write-Error "Binario non trovato: $Bin"
    Write-Error "Lancia dalla root del progetto e assicurati di aver ricompilato."
    exit 1
}

# Controlla che il file di configurazione esista
if (-not (Test-Path $Settings -PathType Leaf)) {
    Write-Error "File di configurazione non trovato: $Settings"
    exit 1
}

# Controlla la cartella e il numero di ripetizioni
if (-not (Test-Path $InstanceDir -PathType Container)) {
    Write-Error "Cartella delle istanze non trovata: $InstanceDir"
    exit 1
}
if ($Runs -lt 1) {
    Write-Error "Numero di ripetizioni non valido: $Runs"
    exit 1
}

# Cerca le istanze (solo file, senza entrare nelle sottocartelle)
$files = @(Get-ChildItem -Path $InstanceDir -Filter $Pattern -File)

if ($files.Count -eq 0) {
    Write-Error "Nessun file '$Pattern' in '$InstanceDir'."
    exit 1
}

$settingsLines = @(Get-Content $Settings)

# Legge i seed (solo se e' stato passato un file): un intero per riga,
# righe vuote e commenti (#) ignorati
$seeds = @()
if (-not [string]::IsNullOrEmpty($SeedsFile)) {
    if (-not (Test-Path $SeedsFile -PathType Leaf)) {
        Write-Error "File dei seed non trovato: $SeedsFile"
        exit 1
    }
    $lineNumber = 0
    foreach ($line in Get-Content $SeedsFile) {
        $lineNumber++
        $value = ($line -replace "#.*$", "").Trim()
        if ($value -eq "") { continue }
        if ($value -notmatch '^-?\d+$') {
            Write-Error "Seed non valido alla riga ${lineNumber} di ${SeedsFile}: '$value'"
            exit 1
        }
        $seeds += $value
    }
    if ($seeds.Count -eq 0) {
        Write-Error "Nessun seed trovato in $SeedsFile."
        exit 1
    }
    Write-Host "Seed letti da ${SeedsFile}: $($seeds -join ', ')"

    # Avvisa se la componente stocastica e' disattivata (in quel caso il seed non ha effetto)
    foreach ($line in $settingsLines) {
        if ($line -match '^\s*algo/default/graph_reduction/arcs/active\s*=\s*0\s*$') {
            Write-Warning "arcs/active = 0: la riduzione degli archi e' spenta, il seed non ha effetto."
        }
        if ($line -match '^\s*algo/default/graph_reduction/arcs/is_deterministic\s*=\s*1\s*$') {
            Write-Warning "is_deterministic = 1: selezione deterministica, il seed non ha effetto."
        }
        if ($line -match '^\s*algo/default/graph_reduction/arcs/temperature\s*=\s*(\S+)\s*$') {
            if ([double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture) -le 0) {
                Write-Warning "temperature <= 0: selezione greedy, il seed non ha effetto."
            }
        }
    }
}
else {
    Write-Host "Nessun file dei seed: uso il seed scritto in $Settings."
}

if (-not (Test-Path $OutDir -PathType Container)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# Cartella per i file di configurazione temporanei
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("pathwyse_bench_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Crea una copia di $Settings con output/benchmark = 1 e, se $seed non e' vuoto, con quel seed
function New-BenchmarkSettings([string]$path, [string]$seed) {
    $benchFound = $false
    $seedFound = $false
    $newLines = foreach ($line in $settingsLines) {
        if ($line -match ('^\s*' + [regex]::Escape($BenchKey) + '\s*=')) {
            $benchFound = $true
            "$BenchKey = 1"
        }
        elseif ($seed -ne "" -and $line -match ('^\s*' + [regex]::Escape($SeedKey) + '\s*=')) {
            $seedFound = $true
            "$SeedKey = $seed"
        }
        else {
            $line
        }
    }
    $newLines = @($newLines)
    if (-not $benchFound) { $newLines += "$BenchKey = 1" }
    if ($seed -ne "" -and -not $seedFound) { $newLines += "$SeedKey = $seed" }
    [System.IO.File]::WriteAllLines($path, [string[]]$newLines, $utf8NoBom)
}

# Elenco delle configurazioni da eseguire
$configs = @()
if ($seeds.Count -gt 0) {
    foreach ($seed in $seeds) {
        $tmpSettings = Join-Path $tmpDir "pathwyse_seed_$seed.set"
        New-BenchmarkSettings $tmpSettings $seed
        $configs += [PSCustomObject]@{ Seed = $seed; Path = $tmpSettings }
    }
}
else {
    $tmpSettings = Join-Path $tmpDir "pathwyse.set"
    New-BenchmarkSettings $tmpSettings ""
    $configs += [PSCustomObject]@{ Seed = $null; Path = $tmpSettings }
}

$count = 0

try {
    foreach ($file in $files) {

        $name = $file.Name
        $count++

        Write-Host "[$count] $name"

        foreach ($config in $configs) {

            if ($null -ne $config.Seed) {
                Write-Host "    seed $($config.Seed)  (x$Runs)"
            }
            else {
                Write-Host "    (x$Runs)"
            }

            for ($i = 1; $i -le $Runs; $i++) {
                & $Bin $file.FullName -param $config.Path *> $null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "       [warn] run $i fallito per $name"
                }
            }
        }
    }
}
finally {
    # Rimuove i file temporanei anche in caso di interruzione (Ctrl+C)
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Fatto: $count istanze. Risultati in '$OutDir\result_intl.csv' e '$OutDir\result_it.csv'."
