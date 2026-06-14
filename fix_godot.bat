@echo off
REM Fix Godot projects.cfg and launch tibia2d project

REM Write corrected projects.cfg
set CFG=%APPDATA%\Godot\projects.cfg

(
echo [C:/Users/Hem/godot_rpg]
echo favorite=false
echo.
echo [C:/Users/Hem/OneDrive/Documents/tibia-3d]
echo favorite=false
echo.
echo [C:/Users/Hem/tibia2d]
echo favorite=false
echo last_modified=1781481600
) > "%CFG%"

echo projects.cfg uppdaterad!

REM Find and launch Godot with the tibia2d project directly
set GODOT=C:\Users\Hem\Mitt spel\Godot_v4.6.2-stable_win64.exe
if exist "%GODOT%" (
    echo Startar Godot med tibia2d-projektet...
    start "" "%GODOT%" --editor --path "C:\Users\Hem\tibia2d"
) else (
    echo Godot hittades inte pa %GODOT%
    echo Oppna Godot manuellt och projektet borde nu visas korrekt.
)
pause
