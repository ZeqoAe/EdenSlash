@echo off
rem Cree une version a partager : dossier build, fichier EdenSlash_v(version).zip
rem L'autre joueur dezippe puis lance EdenSlash.exe (rien a installer).
cd /d "%~dp0"
python tools\make_release.py
echo.
pause
