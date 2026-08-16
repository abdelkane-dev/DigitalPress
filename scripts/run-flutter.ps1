# Lance Flutter sans profil PowerShell (corrige Unblock-File / Split-Path)
$ErrorActionPreference = "Stop"
# Se positionner à la racine du projet (un niveau au-dessus du dossier scripts)
Set-Location "$PSScriptRoot\.."

Write-Host ""
Write-Host "=== Digital Press - Flutter ===" -ForegroundColor Cyan
Write-Host ""

# Verifier le backend Docker
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/health/" -UseBasicParsing -TimeoutSec 3
    if ($r.StatusCode -eq 200) {
        Write-Host "Backend OK" -ForegroundColor Green
    }
} catch {
    Write-Host "ATTENTION: Backend non detecte. Lancez: .\scripts\docker-up.ps1" -ForegroundColor Yellow
}

# Utiliser PowerShell sans profil pour appeler flutter
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command @"
Set-Location '$PSScriptRoot\..'
flutter pub get
if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
flutter run $($args -join ' ')
"@
