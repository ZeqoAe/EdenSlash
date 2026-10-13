@echo off
rem Regarder l IA jouer. Exemples : IA_Regarder.bat hardcore   (mannequin, fuyard, survie, facile, normal, difficile, hardcore)
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0ia"
set SCEN=%1
if "%SCEN%"=="" (
  echo Scenarios : mannequin4, mannequin, fuyard, survie, facile, normal, difficile, hardcore
  set /p SCEN=Scenario a regarder ^(Entree = etape en cours^) : 
)
.venv\Scripts\python -u watch.py %SCEN%
pause
