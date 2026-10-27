param(
    [string]$InstanceDir = "instances",
    [int]$Runs = 10,
    [string]$Pattern = "*.txt",
    [string]$SeedsFile = "",
    [string]$Settings = "pathwyse.set"
)

# Esegue pathwyse su ogni istanza di una cartella, una volta per ogni seed
# elencato in SeedsFile (uno per riga), ripetendo ogni seed $Runs volte.
# Per ogni seed viene generata una copia temporanea di $Settings con la riga
#     algo/default/graph_reduction/arcs/seed = <seed>
# e passata al binario con -param: il file $Settings originale non viene toccato.
#
# Se SeedsFile non esiste, ogni istanza viene eseguita $Runs volte con $Settings
# cosi' com'e' (comportamento precedente).
#
# I risultati vengono accodati a benchmark_times/time_<istanza>.txt nel formato
#     time,obj,tour_length,seed
#
# Va lanciato dalla ROOT del progetto (dove ci sono pathwyse.set e bin\pathwyse.exe).
#
# Esempi:
#   .\run_benchmark.ps1 instances\more_instances\truscello_txts 1
#   .\run_benchmark.ps1 -InstanceDir instances\spprclib -Runs 3 -Pattern *.sppcc -SeedsFile seeds.txt

$Bin = ".\bin\pathwyse.exe"
$OutDir = "benchmark_times"
$SeedKey = "algo/default/graph_reduction/arcs/seed"

# Per default seeds.txt sta nella stessa cartella dello script
if ([string]::IsNullOrEmpty($SeedsFile)) {
    $SeedsFile = Join-Path $PSScriptRoot "seeds.txt"
}

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

# Cerca le istanze
$files = @(Get-ChildItem -Path $InstanceDir -Filter $Pattern -File)

if ($files.Count -eq 0) {
    Write-Error "Nessun file '$Pattern' in '$InstanceDir'."
    exit 1
}

# Legge i seed: un intero per riga, righe vuote e commenti (#) ignorati
$seeds = @()
if (Test-Path $SeedsFile -PathType Leaf) {
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
}
else {
    Write-Host "File dei seed non trovato ($SeedsFile): uso $Settings cosi' com'e'."
}

$settingsLines = @(Get-Content $Settings)

# Avvisa se la componente stocastica e' disattivata (in quel caso il seed non ha effetto)
if ($seeds.Count -gt 0) {
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

# Crea la cartella dei risultati solo se non esiste.
# I file gia' presenti vengono mantenuti: pathwyse accoda una riga per run
# a benchmark_times/time_<istanza>.txt, quindi i nuovi risultati si
# aggiungono a quelli delle esecuzioni precedenti.
if (-not (Test-Path $OutDir -PathType Container)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# Prepara un file di configurazione temporaneo per ogni seed
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("pathwyse_bench_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Elenco delle configurazioni da eseguire: $null = usa $Settings direttamente
$configs = @()
if ($seeds.Count -gt 0) {
    foreach ($seed in $seeds) {
        $found = $false
        $newLines = foreach ($line in $settingsLines) {
            if ($line -match ('^\s*' + [regex]::Escape($SeedKey) + '\s*=')) {
                $found = $true
                "$SeedKey = $seed"
            }
            else {
                $line
            }
        }
        $newLines = @($newLines)
        if (-not $found) { $newLines += "$SeedKey = $seed" }

        $tmpSettings = Join-Path $tmpDir "pathwyse_seed_$seed.set"
        [System.IO.File]::WriteAllLines($tmpSettings, [string[]]$newLines, $utf8NoBom)
        $configs += [PSCustomObject]@{ Seed = $seed; Path = $tmpSettings }
    }
}
else {
    $configs += [PSCustomObject]@{ Seed = $null; Path = $null }
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

                if ($null -ne $config.Path) {
                    & $Bin $file.FullName -param $config.Path *> $null
                }
                else {
                    & $Bin $file.FullName *> $null
                }

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
Write-Host "Fatto: $count istanze. Risultati in '$OutDir/'."
Write-Host "Per le medie: .\summarize.ps1"
