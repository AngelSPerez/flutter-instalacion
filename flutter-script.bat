@echo off
setlocal enabledelayedexpansion

echo =====================================
echo SETUP FLUTTER + ANDROID SDK (SIN UAC)
echo =====================================

REM ===== Verificar PowerShell =====
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell no encontrado.
    pause
    exit /b
)

REM ===== 1. Instalar Scoop =====
echo [1/10] Instalando Scoop...
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; irm get.scoop.sh | iex"

REM Refrescar PATH desde registro para sesion actual
for /f "usebackq tokens=2,*" %%A in (`reg query HKCU\Environment /v PATH 2^>nul`) do set "USERPATH=%%B"
set "PATH=%USERPROFILE%\scoop\shims;%USERPATH%;%SystemRoot%\system32;%SystemRoot%"

REM Verificar Scoop
where scoop >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Scoop no se reconoce incluso tras refrescar PATH.
    pause
    exit /b
)

REM ===== 2. Instalar Git via Scoop =====
echo [2/10] Instalando Git...
powershell -NoProfile -Command "scoop install git"
if %errorlevel% neq 0 (
    echo ERROR: Fallo la instalacion de Git.
    pause
    exit /b
)

REM Refrescar PATH tras instalar Git
for /f "usebackq tokens=2,*" %%A in (`reg query HKCU\Environment /v PATH 2^>nul`) do set "USERPATH=%%B"
set "PATH=%USERPROFILE%\scoop\shims;%USERPATH%;%SystemRoot%\system32;%SystemRoot%"

REM ===== 3. Instalar Java 21 via Scoop =====
echo [3/10] Instalando Java 21 (Temurin)...
powershell -NoProfile -Command "scoop bucket add java"
powershell -NoProfile -Command "scoop install temurin21-jdk"
if %errorlevel% neq 0 (
    echo ERROR: Fallo la instalacion de Java.
    pause
    exit /b
)

REM Refrescar PATH tras instalar Java
for /f "usebackq tokens=2,*" %%A in (`reg query HKCU\Environment /v PATH 2^>nul`) do set "USERPATH=%%B"
set "PATH=%USERPROFILE%\scoop\shims;%USERPATH%;%SystemRoot%\system32;%SystemRoot%"

REM ===== 4. Configurar JAVA_HOME =====
echo [4/10] Configurando JAVA_HOME...
for /f "delims=" %%i in ('powershell -NoProfile -Command "scoop prefix temurin21-jdk"') do set "JAVA_HOME=%%i"

if not defined JAVA_HOME (
    echo ERROR: No se pudo obtener el path de Java desde Scoop.
    pause
    exit /b
)

echo Java encontrado en: %JAVA_HOME%
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('JAVA_HOME', '%JAVA_HOME%', 'User')"
set "PATH=%JAVA_HOME%\bin;%PATH%"

REM ===== 5. Clonar Flutter =====
echo [5/10] Configurando Flutter...
cd /d %USERPROFILE%
if not exist flutter (
    git clone https://github.com/flutter/flutter.git -b stable
    if %errorlevel% neq 0 (
        echo ERROR clonando Flutter
        pause
        exit /b
    )
) else (
    echo Flutter ya existe, OK
)

REM ===== 6. PATH Flutter =====
echo [6/10] Configurando PATH Flutter...
powershell -NoProfile -Command "$current = [Environment]::GetEnvironmentVariable('PATH','User'); if ($current -notlike '*flutter\bin*') { $new = $env:USERPROFILE + '\flutter\bin;' + $current; [Environment]::SetEnvironmentVariable('PATH', $new, 'User') }"
set "PATH=%USERPROFILE%\flutter\bin;%PATH%"

REM ===== 7. Crear estructura Android SDK =====
echo [7/10] Creando Android SDK...
if not exist %USERPROFILE%\Android\Sdk mkdir %USERPROFILE%\Android\Sdk

REM ===== 8. Descargar cmdline-tools =====
echo [8/10] Descargando commandline-tools...
cd /d %USERPROFILE%\Android

if not exist sdk.zip (
    curl -L -o sdk.zip https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
)

if not exist cmdline-tools (
    tar -xf sdk.zip
    if %errorlevel% neq 0 (
        echo ERROR extrayendo sdk.zip
        pause
        exit /b
    )
)

if not exist %USERPROFILE%\Android\Sdk\cmdline-tools\latest (
    mkdir %USERPROFILE%\Android\Sdk\cmdline-tools\latest
)
xcopy /E /I /Y cmdline-tools\* %USERPROFILE%\Android\Sdk\cmdline-tools\latest\ >nul

REM ===== 9. Variables Android =====
echo [9/10] Configurando variables Android...
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('ANDROID_HOME', $env:USERPROFILE + '\Android\Sdk', 'User')"
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $env:USERPROFILE + '\Android\Sdk', 'User')"
powershell -NoProfile -Command "$current = [Environment]::GetEnvironmentVariable('PATH','User'); if ($current -notlike '*Android\Sdk*') { $new = $env:USERPROFILE + '\Android\Sdk\cmdline-tools\latest\bin;' + $env:USERPROFILE + '\Android\Sdk\platform-tools;' + $current; [Environment]::SetEnvironmentVariable('PATH', $new, 'User') }"

set "ANDROID_HOME=%USERPROFILE%\Android\Sdk"
set "PATH=%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"

REM ===== 10. Instalar SDK components y verificar =====
echo [10/10] Instalando SDK components...
cd /d %USERPROFILE%\Android\Sdk\cmdline-tools\latest\bin

echo y | call sdkmanager --licenses
call sdkmanager "platform-tools" "platforms;android-36" "build-tools;28.0.3"
if %errorlevel% neq 0 (
    echo ERROR: Fallo sdkmanager.
    pause
    exit /b
)

adb version >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: ADB no detectado aun (reinicia la terminal)
) else (
    echo ADB instalado correctamente
)

echo Aceptando licencias Flutter/Android...
call flutter doctor --android-licenses

echo =====================================
echo TODO LISTO - Reinicia la terminal
echo =====================================

flutter doctor
pause
