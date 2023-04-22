# Set the script's location as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptPath\..

# Build engine connector
.\engine_connector\build.ps1
Copy-Item -Path ".\engine_connector\build\Debug\EngineConnector.dll" -Destination ".\assets\EngineConnector.dll"

Pop-Location
