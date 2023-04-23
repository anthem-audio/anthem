# Set the repository root as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptPath\..

flatc --cpp -o ./engine/generated/ ./engine/messages/messages.fbs
flatc --dart -o ./lib/generated/ ./engine/messages/messages.fbs
dart format ./lib/generated

Pop-Location
