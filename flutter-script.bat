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
echo [1/9] Instalando Git...
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements

REM ===== 2. Descargar Flutter =====
echo [2/9] Configurando Flutter...
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

REM ===== 3. PATH Flutter =====
echo [3/9] Configurando PATH Flutter...
echo %PATH% | find /I "flutter\bin" >nul
if %errorlevel% neq 0 (
setx PATH "%PATH%;%USERPROFILE%\flutter\bin"
)

REM ===== 4. Verificar Flutter =====
echo [4/9] Verificando Flutter...
call %USERPROFILE%\flutter\bin\flutter doctor

REM ===== 5. Instalar Java 21 =====
echo [5/9] Instalando Java 21...
winget install Microsoft.OpenJDK.21 --accept-package-agreements --accept-source-agreements

REM ===== 6. Crear SDK =====
echo [6/9] Creando Android SDK...
if not exist %USERPROFILE%\Android\Sdk (
mkdir %USERPROFILE%\Android\Sdk
)
cd /d %USERPROFILE%\Android

REM ===== 7. Descargar herramientas =====
echo [7/9] Descargando commandline-tools...
if not exist sdk.zip (
curl -L -o sdk.zip https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
)

if not exist cmdline-tools (
tar -xf sdk.zip
)

mkdir %USERPROFILE%\Android\Sdk\cmdline-tools\latest >nul 2>&1
xcopy /E /I /Y cmdline-tools %USERPROFILE%\Android\Sdk\cmdline-tools\latest >nul

REM ===== 8. Variables de entorno =====
echo [8/9] Configurando variables...
setx ANDROID_HOME "%USERPROFILE%\Android\Sdk"
setx ANDROID_SDK_ROOT "%USERPROFILE%\Android\Sdk"

echo %PATH% | find /I "Android\Sdk\platform-tools" >nul
if %errorlevel% neq 0 (
setx PATH "%PATH%;%USERPROFILE%\Android\Sdk\cmdline-tools\latest\bin;%USERPROFILE%\Android\Sdk\platform-tools"
)

REM ===== 9. Instalar SDK + ADB =====
echo [9/9] Instalando SDK y ADB...
cd /d %USERPROFILE%\Android\Sdk\cmdline-tools\latest\bin

call sdkmanager --licenses
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
pause
