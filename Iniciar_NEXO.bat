@echo off
setlocal EnableExtensions
title NEXO - Emulador y Flutter

REM ==================================================
REM CONFIGURACION
REM ==================================================
set "PROJECT_DIR=%~dp0"
set "EMULATOR_ID=Pixel_8"
set "DEVICE_ID="
set "ADB="
set "EMULATOR_EXE="

REM ==================================================
REM COMPROBAR PROYECTO Y FLUTTER
REM ==================================================
cd /d "%PROJECT_DIR%" || goto ERROR_PROJECT

if not exist "pubspec.yaml" goto ERROR_PROJECT

where flutter >nul 2>&1
if errorlevel 1 goto ERROR_FLUTTER

REM ==================================================
REM LOCALIZAR ANDROID SDK, ADB Y EMULATOR.EXE
REM ==================================================
if defined ANDROID_SDK_ROOT (
    if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
    if exist "%ANDROID_SDK_ROOT%\emulator\emulator.exe" set "EMULATOR_EXE=%ANDROID_SDK_ROOT%\emulator\emulator.exe"
)

if defined ANDROID_HOME (
    if not defined ADB if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
    if not defined EMULATOR_EXE if exist "%ANDROID_HOME%\emulator\emulator.exe" set "EMULATOR_EXE=%ANDROID_HOME%\emulator\emulator.exe"
)

if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined EMULATOR_EXE if exist "%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" set "EMULATOR_EXE=%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe"

if not defined ADB (
    for /f "delims=" %%I in ('where adb 2^>nul') do if not defined ADB set "ADB=%%I"
)

if not defined ADB goto ERROR_ADB

REM ==================================================
REM DETECTAR EMULADOR YA ENCENDIDO
REM ==================================================
echo.
echo ========================================
echo          NEXO - INICIADOR
echo ========================================
echo.
echo Comprobando si el emulador ya esta encendido...
call :FIND_EMULATOR

REM ==================================================
REM INICIAR EMULADOR SI HACE FALTA
REM ==================================================
if defined DEVICE_ID goto WAIT_BOOT

echo.
echo Iniciando emulador: %EMULATOR_ID%

if defined EMULATOR_EXE (
    start "" "%EMULATOR_EXE%" -avd "%EMULATOR_ID%"
) else (
    flutter emulators --launch "%EMULATOR_ID%"
    if errorlevel 1 goto ERROR_LAUNCH
)

REM ==================================================
REM ESPERAR A QUE ADB DETECTE EL EMULADOR
REM ==================================================
echo Esperando a que aparezca el dispositivo...
for /L %%I in (1,1,120) do (
    call :FIND_EMULATOR
    if defined DEVICE_ID goto WAIT_BOOT
    timeout /t 2 /nobreak >nul
)

goto ERROR_DEVICE

REM ==================================================
REM ESPERAR A QUE ANDROID TERMINE DE ARRANCAR
REM ==================================================
:WAIT_BOOT
echo.
echo Emulador detectado: %DEVICE_ID%
echo Esperando a que Android termine de arrancar...
set "BOOTED="

for /L %%I in (1,1,120) do (
    "%ADB%" -s "%DEVICE_ID%" shell getprop sys.boot_completed > "%TEMP%\nexo_boot_status.txt" 2>nul
    set "BOOTED="
    for /f "usebackq delims=" %%B in ("%TEMP%\nexo_boot_status.txt") do if "%%B"=="1" set "BOOTED=1"
    if defined BOOTED goto RUN_APP
    timeout /t 2 /nobreak >nul
)

goto ERROR_BOOT

REM ==================================================
REM INICIAR NEXO
REM ==================================================
:RUN_APP
echo.
echo ========================================
echo       INICIANDO NEXO EN FLUTTER
echo ========================================
echo.
cd /d "%PROJECT_DIR%"
flutter run -d "%DEVICE_ID%"
echo.
echo Flutter ha finalizado.
pause
endlocal
exit /b 0

REM ==================================================
REM SUBRUTINA: BUSCAR UN EMULADOR EN ADB
REM ==================================================
:FIND_EMULATOR
set "DEVICE_ID="
"%ADB%" devices > "%TEMP%\nexo_adb_devices.txt" 2>nul
"%SystemRoot%\System32\findstr.exe" /B /C:"emulator-" "%TEMP%\nexo_adb_devices.txt" > "%TEMP%\nexo_emulators.txt"
for /f "usebackq tokens=1" %%A in ("%TEMP%\nexo_emulators.txt") do if not defined DEVICE_ID set "DEVICE_ID=%%A"
exit /b 0

:ERROR_PROJECT
echo ERROR: No encuentro pubspec.yaml en la carpeta del proyecto.
goto END_ERROR

:ERROR_FLUTTER
echo ERROR: Flutter no esta disponible en el PATH.
goto END_ERROR

:ERROR_ADB
echo ERROR: No encuentro ADB. Comprueba Android SDK y las variables ANDROID_SDK_ROOT o ANDROID_HOME.
goto END_ERROR

:ERROR_LAUNCH
echo ERROR: Flutter no pudo iniciar el emulador %EMULATOR_ID%.
echo Prueba en PowerShell: flutter emulators --launch %EMULATOR_ID%
goto END_ERROR

:ERROR_DEVICE
echo ERROR: El emulador no aparece en ADB.
echo Comprueba Android Studio Device Manager y vuelve a intentarlo.
goto END_ERROR

:ERROR_BOOT
echo ERROR: Android no termino de arrancar en el tiempo esperado.
echo Comprueba la ventana del emulador y el estado del AVD en Android Studio.
goto END_ERROR

:END_ERROR
echo.
pause
endlocal
exit /b 1
