# Script d'envoi et de mise à jour automatique sur le VPS
$VPS_IP = "192.162.71.56"
$VPS_USER = "root"
$REMOTE_DIR = "/opt/digitalpress"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  🚀 Déploiement DigitalPress vers $VPS_IP...       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Nettoyage local et création de l'archive compressée
Write-Host "`n1. Compression propre du backend..." -ForegroundColor Yellow
Get-ChildItem -Path backend -Include "__pycache__", "*.pyc" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
tar -czf backend.tar.gz backend deploy_vps_direct.sh

# 2. Envoi de l'archive unique ultra-rapide
Write-Host "`n2. Envoi de l'archive vers le VPS (1 seul fichier)..." -ForegroundColor Yellow
Write-Host "👉 Entrez votre mot de passe VPS :" -ForegroundColor Green
scp backend.tar.gz ${VPS_USER}@${VPS_IP}:${REMOTE_DIR}/

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n3. Extraction et exécution de la mise à jour sur le VPS..." -ForegroundColor Yellow
    ssh ${VPS_USER}@${VPS_IP} "mkdir -p /opt/digitalpress && cd /opt/digitalpress && tar -xzf backend.tar.gz && chmod +x deploy_vps_direct.sh && ./deploy_vps_direct.sh"
    Write-Host "`n🎉 Déploiement terminé avec succès !" -ForegroundColor Green
} else {
    Write-Host "`n❌ Échec du transfert SCP." -ForegroundColor Red
}
