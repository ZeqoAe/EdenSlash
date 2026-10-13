@echo off
rem Entraine l IA du guerrier (12 jeux sans fenetre). Ctrl+C pour arreter : tout est sauvegarde.
rem Relancer reprend la ou ca s etait arrete.
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0ia"
if not exist .venv\Scripts\python.exe (
  echo Lance d abord IA_Installer.bat
  pause
  exit /b
)
.venv\Scripts\python -u train.py %*
pause
