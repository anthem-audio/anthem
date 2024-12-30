# Check for --build option passed to the script
if ($args -contains "--build") {
  # Set the repository root as the current directory
  $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
  Push-Location $scriptPath\..

  # Build test executable
  .\engine\build_test.ps1

  # Ensure that the assets directory exists
  New-Item -ItemType Directory -Path ".\assets\engine" -Force | Out-Null
}

# Set test executable source path
$platform = [System.Environment]::OSVersion.Platform
if ($platform -eq [System.PlatformID]::Win32NT) {
  $testSrc = ".\engine\build\Debug\AnthemTest.exe"
} else {
  $testSrc = "./engine/build/AnthemTest"
}

# Run test executable (mirror output to console)
$testOutput = & $testSrc
Write-Output $testOutput
