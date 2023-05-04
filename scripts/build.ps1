# Set the repository root as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptPath\..

# Run bindgen
.\scripts\bindgen.ps1

# Build engine connector
.\engine_connector\build.ps1

# Set engine connector source and destination paths
$platform = [System.Environment]::OSVersion.Platform
if ($platform -eq [System.PlatformID]::Win32NT) {
    $engineConnectorSrc = ".\engine_connector\build\Debug\EngineConnector.dll"
    $engineConnectorDest = ".\assets\engine\EngineConnector.dll"
} else {
    $engineConnectorSrc = "./engine_connector/build/libEngineConnector.so"
    $engineConnectorDest = "./assets/engine/libEngineConnector.so"
}

New-Item -ItemType Directory -Path ".\assets\engine" -Force | Out-Null
Copy-Item -Path $engineConnectorSrc -Destination $engineConnectorDest

# Build engine executable
.\engine\build.ps1

# Set engine executable source and destination paths
if ($platform -eq [System.PlatformID]::Win32NT) {
    $engineExeSrc = ".\engine\build\AnthemEngine_artefacts\Debug\AnthemEngine.exe"
    $engineExeDest = ".\assets\engine\AnthemEngine.exe"
} else {
    $engineExeSrc = "./engine/build/AnthemEngine_artefacts/AnthemEngine"
    $engineExeDest = "./assets/engine/AnthemEngine"
}

Copy-Item -Path $engineExeSrc -Destination $engineExeDest

Pop-Location
