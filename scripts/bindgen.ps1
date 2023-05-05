# Set the repository root as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptPath\..

# Loop through all .fbs files in ./engine/messages/
Get-ChildItem -Path ./engine/messages/ -Filter *.fbs | ForEach-Object {
    # Call flatc for each file
    flatc --cpp -o ./engine/generated/ $_.FullName
    flatc --dart -o ./lib/generated/ $_.FullName
}

# Format generated Dart files
dart format ./lib/generated

Pop-Location
