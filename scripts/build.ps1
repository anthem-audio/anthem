# Set the repository root as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptPath\..

# Build engine connector
.\engine_connector\build.ps1
Copy-Item -Path ".\engine_connector\build\Debug\EngineConnector.dll" -Destination ".\assets\EngineConnector.dll"

# Build engine executable
.\engine\build.ps1
Copy-Item -Path ".\engine\build\AnthemEngine_artefacts\Debug\AnthemEngine.exe" -Destination ".\assets\AnthemEngine.exe"

Pop-Location
