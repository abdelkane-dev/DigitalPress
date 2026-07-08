# Corrige les erreurs Flutter "Unblock-File" / "Split-Path" dans PowerShell
# Executez UNE FOIS en PowerShell administrateur ou utilisateur normal :
#   .\scripts\fix-flutter-powershell.ps1

$flutterPath = "C:\flutter"

if (-not (Test-Path $flutterPath)) {
    Write-Host "Flutter introuvable dans $flutterPath" -ForegroundColor Red
    Write-Host "Adaptez le chemin dans fix-flutter-powershell.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Deblocage des scripts Flutter..." -ForegroundColor Yellow
Get-ChildItem -Path $flutterPath -Recurse -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue |
    ForEach-Object { Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue }

Write-Host "Chargement des modules PowerShell..." -ForegroundColor Yellow
Import-Module Microsoft.PowerShell.Management -Force -ErrorAction SilentlyContinue
Import-Module Microsoft.PowerShell.Utility -Force -ErrorAction SilentlyContinue

Write-Host "Test flutter --version..." -ForegroundColor Yellow
flutter --version

Write-Host ""
Write-Host "Si la version s'affiche, vous pouvez utiliser: flutter run" -ForegroundColor Green
Write-Host "Sinon utilisez: .\scripts\run-flutter.bat" -ForegroundColor Cyan
