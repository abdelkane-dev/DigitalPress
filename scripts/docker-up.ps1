# Digital Press — Lancer toute la stack Docker
$ErrorActionPreference = "Stop"
# Se positionner à la racine du projet (un niveau au-dessus du dossier scripts)
Set-Location "$PSScriptRoot\.."

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Digital Press — Docker Stack" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "ERREUR: Docker n'est pas installe ou pas dans le PATH." -ForegroundColor Red
    Write-Host "Installez Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

Write-Host "1/3 Construction et demarrage des conteneurs..." -ForegroundColor Yellow
docker compose up --build -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERREUR: docker compose a echoue." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2/3 Attente du backend (health check)..." -ForegroundColor Yellow
$max = 60
$ok = $false
for ($i = 1; $i -le $max; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/health/" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) {
            $ok = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
        Write-Host "  En attente... ($i/$max)" -ForegroundColor DarkGray
    }
}

if (-not $ok) {
    Write-Host "ATTENTION: Le backend met du temps a demarrer." -ForegroundColor Yellow
    Write-Host "Verifiez les logs: docker compose logs -f backend" -ForegroundColor Yellow
} else {
    Write-Host "Backend OK!" -ForegroundColor Green
}

Write-Host ""
Write-Host "3/3 Verification login API..." -ForegroundColor Yellow
try {
    $body = '{"username":"admin","password":"Admin123!"}'
    $login = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/accounts/login/" `
        -Method POST -ContentType "application/json" -Body $body
    if ($login.access) {
        Write-Host "Login API OK (JWT recu)" -ForegroundColor Green
    }
} catch {
    Write-Host "Login API: en attente des migrations..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  STACK DOCKER PRETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  API:         http://127.0.0.1:8000/api/" -ForegroundColor White
Write-Host "  Health:      http://127.0.0.1:8000/api/health/" -ForegroundColor White
Write-Host "  Swagger:     http://127.0.0.1:8000/api/docs/" -ForegroundColor White
Write-Host "  Admin:       http://127.0.0.1:8000/admin/" -ForegroundColor White
Write-Host ""
Write-Host "  Comptes demo:" -ForegroundColor Cyan
Write-Host "    admin / Admin123!" -ForegroundColor White
Write-Host "    editeur_afrique / Editeur@2024!" -ForegroundColor White
Write-Host "    lecteur1 / Lecteur@2024!" -ForegroundColor White
Write-Host ""
Write-Host "  Flutter (autre terminal):" -ForegroundColor Cyan
Write-Host "    flutter pub get" -ForegroundColor White
Write-Host "    flutter run" -ForegroundColor White
Write-Host ""
Write-Host "  Logs backend:  docker compose logs -f backend" -ForegroundColor DarkGray
Write-Host "  Arreter:       docker compose down" -ForegroundColor DarkGray
Write-Host "                 ou .\scripts\docker-down.ps1" -ForegroundColor DarkGray
Write-Host ""
