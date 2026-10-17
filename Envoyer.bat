@echo off
rem Envoie tes changements sur GitHub (commit + recuperation de ceux des autres + envoi)
cd /d "%~dp0"
echo.
echo === Envoi de tes changements sur GitHub ===
rem Controle des scripts (1 minute) : un script qui ne compile pas casse le jeu de tout le monde.
where python >nul 2>nul || goto envoyer
chcp 65001 >nul
python tools\check_scripts.py
if errorlevel 1 (
  echo.
  echo ATTENTION : des scripts ne compilent pas ^(liste ci-dessus^). Le jeu risque de ne plus se lancer.
  choice /c NO /m "Envoyer quand meme"
  if errorlevel 2 goto envoyer
  echo Envoi annule : rien n a ete envoye.
  pause
  exit /b 1
)
:envoyer
git add -A
git commit -m "Changements locaux du %date% %time%"
git pull --no-rebase --no-edit
git push
echo.
echo === Version maintenant sur GitHub ===
git log --oneline -3
findstr /c:"NUMBER :=" game\scripts\core\version.gd
pause
