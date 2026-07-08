# Arrêter la stack Docker Digital Press
# Se positionner à la racine du projet (un niveau au-dessus du dossier scripts)
Set-Location "$PSScriptRoot\.."

Write-Host "Arrêt des conteneurs..." -ForegroundColor Yellow
docker compose down
Write-Host "Stack arrêtée." -ForegroundColor Green
