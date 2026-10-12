@echo off
rem Recupere la derniere version depuis GitHub.
rem Les fichiers modifies sur ce PC (souvent par l'editeur Godot) bloquent la mise a jour :
rem ils sont mis de cote (git stash) le temps de la mise a jour, puis remis.
cd /d "%~dp0"
echo.
echo === Recuperation de la derniere version ===
git checkout claude/optimistic-gauss-p2g2pq
set CHANGES=
for /f "delims=" %%i in ('git status --porcelain') do set CHANGES=1
if defined CHANGES (
	echo Fichiers modifies sur ce PC : mis de cote le temps de la mise a jour...
	git stash push -u -m "mise-a-jour-auto"
)
git pull --no-rebase --no-edit origin claude/optimistic-gauss-p2g2pq
if errorlevel 1 (
	echo.
	echo !!! La mise a jour a echoue : copie ce texte a Claude.
)
if defined CHANGES (
	git stash pop
	if errorlevel 1 (
		echo.
		echo Certains fichiers modifies sur ce PC n'ont pas pu etre remis
		echo ^(ils sont gardes dans "git stash list"^). La mise a jour, elle, est faite.
	)
)
echo.
git log --oneline -3
findstr /c:"NUMBER :=" game\scripts\core\version.gd
echo.
echo Si de nouveaux fichiers sont arrives : ouvre une fois Editeur.bat, ferme-le, puis Jouer.bat
pause
