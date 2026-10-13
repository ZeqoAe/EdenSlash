@echo off
rem Regarder l IA jouer. Exemples : IA_Regarder.bat hardcore   ou   IA_Regarder.bat hardcore magicien
rem Scenarios : mannequin, mannequin4, fuyard, survie, facile, normal, difficile, hardcore, toutes, duo
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0ia"
set SCEN=%1
set CLS=%2
if "%SCEN%"=="" (
  echo Scenarios : mannequin4, mannequin, fuyard, survie, facile, normal, difficile, hardcore, duo ^(1 contre 2^)
  set /p SCEN=Scenario a regarder ^(Entree = etape en cours^) : 
  set /p CLS=Classe jouee, ex. guerrier, magicien, clerc ^(Entree = au hasard^) : 
)
if "%CLS%"=="" (
  .venv\Scripts\python -u watch.py %SCEN%
) else (
  .venv\Scripts\python -u watch.py %SCEN% --classe "%CLS%"
)
pause
