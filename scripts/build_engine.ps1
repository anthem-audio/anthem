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

# -Force here just supresses the error if the directory already exists
New-Item -ItemType Directory -Force -Path .\assets\build\

$BuildFiles = Get-ChildItem $BuildOutputDirectory\anthem_engine.* -Exclude *.d
foreach ($File in $BuildFiles) {
    $FileName = [System.IO.Path]::GetFileName($File)
    Copy-Item -Path $File -Destination .\assets\build\$FileName
}
