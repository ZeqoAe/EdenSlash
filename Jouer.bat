@echo off
rem Lance Eden Slash (F1 en jeu pour l'aide, F9 pour signaler un probleme)
rem Une fois par nouvelle version du code, rafraichit le cache des classes (sinon ecran gris au demarrage)
set "GODOT=C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64.exe"
set "GODOTC=C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64_console.exe"
set "MARK=%~dp0game\.godot\dernier_import.txt"
set "HEADV="
set "OLDV="
for /f %%h in ('git -C "%~dp0." rev-parse HEAD 2^>nul') do set "HEADV=%%h"
if exist "%MARK%" set /p OLDV=<"%MARK%"
if not defined HEADV goto lancer
if "%HEADV%"=="%OLDV%" goto lancer
echo Mise a jour des ressources du jeu, une fois par nouvelle version (1 a 2 minutes)...
"%GODOTC%" --headless --path "%~dp0game" --import >nul 2>&1
>"%MARK%" echo %HEADV%
:lancer
start "" "%GODOT%" --path "%~dp0game"
