@echo off
rem Deux IA s affrontent dans une fenetre (meme cerveau des deux cotes, sans Python).
rem Exemples : IA_Duel.bat   (classes au hasard a chaque combat)   ou   IA_Duel.bat guerrier magicien
chcp 65001 >nul
cd /d "%~dp0"
set C=game\data\cerveaux
set BRAIN=
for %%N in (cerveau_maitre cerveau_expert cerveau_hardcore cerveau_actuel cerveau_difficile cerveau_normal cerveau_facile) do (
  if not defined BRAIN if exist "%C%\%%N.json" set BRAIN=%%N
)
if not defined BRAIN (
  echo Pas encore de cerveau : lance d abord IA_Entrainer.bat
  pause
  exit /b
)
set HERO=%~1
set FOE=%~2
if "%HERO%"=="" set HERO=random
if "%FOE%"=="" set FOE=random
echo Cerveau : %BRAIN%   -   %HERO% contre %FOE%   (fermer la fenetre du jeu pour arreter)
start "" "C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64.exe" --path game res://scenes/ml_arena.tscn -- --watch --scenario=duel --brain=res://data/cerveaux/%BRAIN%.json --hero=%HERO% --foe=%FOE%
