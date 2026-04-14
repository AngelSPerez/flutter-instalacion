@echo off
setlocal enabledelayedexpansion

echo =====================================
echo SETUP FLUTTER + ANDROID SDK (ROBUSTO)
echo =====================================

REM ===== Verificar winget =====
where winget >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: winget no esta instalado. Actualiza Windows o instala App Installer.
    pause
    exit /b
)

REM ===== 1. Instalar Git =====
echo [1/10] Instalando Git...
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements

REM ===== 2. Descargar Flutter =====
echo [2/10] Configurando Flutter...
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

REM ===== 3. PATH Flutter (seguro via registro) =====
echo [3/10] Configurando PATH Flutter...
echo %PATH% | find /I "flutter\bin" >nul
if %errorlevel% neq 0 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "CURRENT_USER_PATH=%%B"
    if not defined CURRENT_USER_PATH (
        reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%USERPROFILE%\flutter\bin" /f >nul
    ) else (
        reg add "HKCU\Environment" /v PATH /t REG_EXPAND_SZ /d "%USERPROFILE%\flutter\bin;!CURRENT_USER_PATH!" /f >nul
    )
)

REM Aplicar en sesion actual
set "PATH=%USERPROFILE%\flutter\bin;%PATH%"

REM ===== 4. Verificar Flutter =====
echo [4/10] Verificando Flutter...
call %USERPROFILE%\flutter\bin\flutter doctor

REM ===== 5. Instalar Java =====
echo [5/10] Instalando Java 21...
winget install Microsoft.OpenJDK.21 --accept-package-agreements --accept-source-agreements

REM ===== 6. Configurar Java =====
echo [6/10] Configurando Java...

set "JAVA_PATH="

for /d %%i in ("%LOCALAPPDATA%\Programs\Microsoft\jdk-*") do (
    if not defined JAVA_PATH set "JAVA_PATH=%%i"
)

if not defined JAVA_PATH (
    for /d %%i in ("C:\Program Files\Microsoft\jdk-*") do (
        if not defined JAVA_PATH set "JAVA_PATH=%%i"
    )
)

if not defined JAVA_PATH (
    echo ERROR: No se encontro Java
    pause
    exit /b
)

echo Java encontrado en:
echo %JAVA_PATH%

setx JAVA_HOME "%JAVA_PATH%" >nul

set "JAVA_HOME=%JAVA_PATH%"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo JAVA configurado correctamente

REM ===== 7. Crear SDK =====
echo [7/10] Creando Android SDK...
if not exist %USERPROFILE%\Android\Sdk (
    mkdir %USERPROFILE%\Android\Sdk
)

REM ===== 8. Descargar herramientas =====
echo [8/10] Descargando commandline-tools...
cd /d %USERPROFILE%\Android

if not exist sdk.zip (
    curl -L -o sdk.zip https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
)

REM Solo extraer si no se extrajo antes
if not exist cmdline-tools (
    tar -xf sdk.zip
    if %errorlevel% neq 0 (
        echo ERROR extrayendo sdk.zip
        pause
        exit /b
    )
)

REM Crear destino y copiar contenido (evitar duplicar carpeta)
if not exist %USERPROFILE%\Android\Sdk\cmdline-tools\latest (
    mkdir %USERPROFILE%\Android\Sdk\cmdline-tools\latest
)
xcopy /E /I /Y cmdline-tools\* %USERPROFILE%\Android\Sdk\cmdline-tools\latest\ >nul

REM ===== 9. Variables Android =====
echo [9/10] Configurando variables Android...
setx ANDROID_HOME "%USERPROFILE%\Android\Sdk" >nul
setx ANDROID_SDK_ROOT "%USERPROFILE%\Android\Sdk" >nul

set "ANDROID_HOME=%USERPROFILE%\Android\Sdk"
set "PATH=%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"

REM ===== 10. Instalar SDK =====
echo [10/10] Instalando SDK y ADB...
cd /d %USERPROFILE%\Android\Sdk\cmdline-tools\latest\bin

echo y | call sdkmanager --licenses
call sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

REM ===== Verificar ADB =====
echo Verificando ADB...
adb version >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: ADB no detectado en PATH (reinicia terminal)
) else (
    echo ADB instalado correctamente
)

echo =====================================
echo TODO LISTO
echo Reinicia la terminal antes de usar Flutter
echo =====================================

flutter doctor

pause
