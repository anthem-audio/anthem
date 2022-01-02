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

Get-ChildItem $BuildOutputDirectory\anthem_engine.* -Exclude *.d | Copy-Item -Destination .\assets\build
