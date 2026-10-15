@echo off
rem ────────────────────────────────────────────────────────────────────────
rem  Relance DigitalPress sur le téléphone Android.
rem
rem  Après une installation ou un force-stop, Android place l'app en état
rem  « stopped » : le tap sur l'icône ne lance rien tant que l'app n'a pas
rem  été démarrée une fois. Ce script force ce premier démarrage via adb.
rem ────────────────────────────────────────────────────────────────────────
setlocal

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"

echo [1/2] Verifie la connexion du telephone...
"%ADB%" get-state || goto :error

echo [2/2] Lancement de DigitalPress (com.digitalpress.app)...
"%ADB%" shell am start -n com.digitalpress.app/.MainActivity || goto :error

echo.
echo OK : l'app est lancee, le tap sur l'icone fonctionnera normalement.
exit /b 0

:error
echo.
echo ERREUR : telephone non detecte ou adb introuvable.
echo  - Branchez le telephone avec le debogage USB active.
echo  - Ou installez les outils platform-tools Android.
exit /b 1
