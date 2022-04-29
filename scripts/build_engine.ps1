param(
    [switch]$Release = $False
)

$WorkingDirectory = Convert-Path .

if (-not(Test-Path ($WorkingDirectory + "\pubspec.yaml"))) {
    Write-Error "This script must be run from the project root."
    Exit
}

if ($Release) {
    cargo build --manifest-path ".\rust\engine\Cargo.toml" --release
    $BuildOutputDirectory = ".\rust\engine\target\release"
}
else {
    cargo build --manifest-path ".\rust\engine\Cargo.toml"
    $BuildOutputDirectory = ".\rust\engine\target\debug"
}

try {
    mkdir .\assets\build\
} catch {}

$BuildFiles = Get-ChildItem $BuildOutputDirectory\anthem_engine.* -Exclude *.d
foreach ($File in $BuildFiles) {
    $FileName = [System.IO.Path]::GetFileName($File)
    Copy-Item -Path $File -Destination .\assets\build\$FileName
}
