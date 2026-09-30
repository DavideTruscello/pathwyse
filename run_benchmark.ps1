param(
    [string]$InstanceDir = "instances",
    [int]$Runs = 10,
    [string]$Pattern = "*.txt"
)

$Bin = ".\bin\pathwyse.exe"
$OutDir = "benchmark_times"

# Controlla che il programma esista
if (-not (Test-Path $Bin -PathType Leaf)) {
    Write-Error "Binario non trovato: $Bin"
    Write-Error "Lancia dalla root del progetto e assicurati di aver ricompilato."
    exit 1
}

# Cerca le istanze
$files = Get-ChildItem -Path $InstanceDir -Filter $Pattern -File

if ($files.Count -eq 0) {
    Write-Error "Nessun file '$Pattern' in '$InstanceDir'."
    exit 1
}

# Crea la cartella dei risultati se non esiste
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Batch pulito: elimina i risultati precedenti
Get-ChildItem -Path $OutDir -Filter "time_*.txt" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force

$count = 0

foreach ($file in $files) {

    $name = $file.Name
    $count++

    Write-Host "[$count] $name  (x$Runs)"

    for ($i = 1; $i -le $Runs; $i++) {

        & $Bin $file.FullName *> $null

        if ($LASTEXITCODE -ne 0) {
            Write-Host "   [warn] run $i fallito per $name"
        }
    }
}

Write-Host ""
Write-Host "Fatto: $count istanze. Tempi in '$OutDir/'."
Write-Host "Per le medie: .\summarize.ps1"
