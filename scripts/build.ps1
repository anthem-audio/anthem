# Set the repository root as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptPath\..

# Run bindgen
.\scripts\bindgen.ps1

# Build engine executable
.\engine\build.ps1

# Set engine executable source and destination paths
$platform = [System.Environment]::OSVersion.Platform
if ($platform -eq [System.PlatformID]::Win32NT) {
    $engineExeSrc = ".\engine\build\AnthemEngine_artefacts\Debug\AnthemEngine.exe"
    $engineExeDest = ".\assets\engine\AnthemEngine.exe"
} else {
    $engineExeSrc = "./engine/build/AnthemEngine_artefacts/AnthemEngine"
    $engineExeDest = "./assets/engine/AnthemEngine"
}

Copy-Item -Path $engineExeSrc -Destination $engineExeDest

Pop-Location
