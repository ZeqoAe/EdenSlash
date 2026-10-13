@echo off
rem Installe les outils de l IA (Python, PyTorch, Stable-Baselines3) dans ia\.venv
chcp 65001 >nul
cd /d "%~dp0ia"
if not exist .venv\Scripts\python.exe (
  py -3 -m venv .venv || python -m venv .venv
)
.venv\Scripts\python -m pip install --upgrade pip
.venv\Scripts\python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
.venv\Scripts\python -m pip install stable-baselines3 gymnasium numpy
echo.
echo Installation terminee. Lance IA_Entrainer.bat pour entrainer l IA.
pause
