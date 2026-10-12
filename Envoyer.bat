@echo off
rem Envoie tes changements sur GitHub (commit + recuperation de ceux des autres + envoi)
cd /d "%~dp0"
echo.
echo === Envoi de tes changements sur GitHub ===
git add -A
git commit -m "Changements locaux du %date% %time%"
git pull --no-rebase --no-edit
git push
echo.
echo === Version maintenant sur GitHub ===
git log --oneline -3
findstr /c:"NUMBER :=" game\scripts\core\version.gd
pause
