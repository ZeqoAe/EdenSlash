@echo off
rem Recupere la derniere version depuis GitHub
cd /d "%~dp0"
echo.
echo === Recuperation de la derniere version ===
git pull --no-rebase --no-edit
echo.
git log --oneline -3
findstr /c:"NUMBER :=" game\scripts\core\version.gd
echo.
echo Si de nouveaux fichiers sont arrives : ouvre une fois Editeur.bat, ferme-le, puis Jouer.bat
pause
