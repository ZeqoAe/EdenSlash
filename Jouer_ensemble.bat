@echo off
rem Mode amis (essai, lot NET-A) : heberger une partie, rejoindre un ami, ou essayer a deux sur ce PC.
rem Les arguments se donnent SANS "--" : sinon le jeu prend le profil de test.
rem Lancer Jouer.bat une fois apres chaque mise a jour (il rafraichit les ressources du jeu).
set "GODOT=C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64.exe"
echo.
echo   Eden Slash - Jouer ensemble (essai)
echo   1 = Heberger une partie
echo   2 = Rejoindre un ami (son adresse, par exemple 100.64.0.7)
echo   3 = Essai a deux sur ce PC (deux fenetres, la 2e avec une sauvegarde a part)
echo.
set "CHOIX="
set /p CHOIX=Ton choix : 
if "%CHOIX%"=="1" goto heberger
if "%CHOIX%"=="2" goto rejoindre
if "%CHOIX%"=="3" goto deux
goto :eof
:heberger
start "" "%GODOT%" --path "%~dp0game" --host
goto :eof
:rejoindre
set "ADR="
set /p ADR=Adresse de l'hote : 
if "%ADR%"=="" goto :eof
start "" "%GODOT%" --path "%~dp0game" --join=%ADR%
goto :eof
:deux
start "" "%GODOT%" --path "%~dp0game" --host
timeout /t 8 /nobreak >nul
start "" "%GODOT%" --path "%~dp0game" --profil=ami --join=127.0.0.1
