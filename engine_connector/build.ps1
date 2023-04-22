# Set the script's location as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptPath

# Build

New-Item -ItemType Directory -Path .\build -Force

Push-Location -Path .\build

cmake ..
cmake --build .

Pop-Location

Pop-Location
