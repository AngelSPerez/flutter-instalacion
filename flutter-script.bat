@echo off
setlocal enabledelayedexpansion

echo =====================================
echo SETUP FLUTTER + ANDROID SDK (SIN UAC)
echo =====================================

REM ===== 1. Descargar Java 21 OpenJDK (ZIP, sin admin) =====
echo [1/7] Instalando Java 21 OpenJDK...

set "JAVA_DIR=%USERPROFILE%\Java"
set "JAVA_HOME=%JAVA_DIR%\jdk-21"

if not exist "%JAVA_HOME%\bin\java.exe" goto instalar_java
echo Java 21 ya existe, OK
goto java_listo

:instalar_java
if not exist "%JAVA_DIR%" mkdir "%JAVA_DIR%"

echo Descargando JDK 21 desde Adoptium...
curl.exe -L --retry 5 --retry-delay 2 "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse" -o "%JAVA_DIR%\jdk21.zip"

echo Verificando integridad de jdk21.zip...
powershell -NoProfile -Command "try { Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::OpenRead('%JAVA_DIR%\jdk21.zip').Dispose(); exit 0 } catch { exit 1 }"
if %errorlevel% neq 0 goto java_zip_corrupto

echo Extrayendo JDK...
powershell -NoProfile -Command "Expand-Archive -Path '%JAVA_DIR%\jdk21.zip' -DestinationPath '%JAVA_DIR%\tmp21' -Force"

for /d %%i in ("%JAVA_DIR%\tmp21\*") do move "%%i" "%JAVA_HOME%" >nul
rmdir /s /q "%JAVA_DIR%\tmp21"
del "%JAVA_DIR%\jdk21.zip"
goto java_listo

:java_zip_corrupto
echo ERROR: jdk21.zip corrupto, eliminando y abortando.
del /f "%JAVA_DIR%\jdk21.zip"
pause
exit /b

:java_listo
REM ===== 2. Configurar JAVA_HOME y ponerlo AL TOPE del PATH =====
echo [2/7] Configurando JAVA_HOME y PATH...

powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('JAVA_HOME', '%JAVA_HOME%', 'User')"

powershell -NoProfile -Command "$jbin = '%JAVA_HOME%\bin'; $cur = [Environment]::GetEnvironmentVariable('PATH','User'); $cleaned = ($cur -split ';' | Where-Object { $_ -notlike '*Java\jdk*' }) -join ';'; [Environment]::SetEnvironmentVariable('PATH', $jbin + ';' + $cleaned, 'User')"

set "PATH=%JAVA_HOME%\bin;%PATH%"

java -version
if %errorlevel% neq 0 goto java_error
goto flutter_inicio

:java_error
echo ERROR: Java no responde. Revisa la descarga.
pause
exit /b

:flutter_inicio
REM ===== 3. Flutter - deteccion =====
echo [3/7] Configurando Flutter...

where flutter >nul 2>&1
if %errorlevel% equ 0 goto flutter_listo

if exist "%USERPROFILE%\flutter\bin\flutter.bat" goto flutter_path

echo Flutter no detectado, descargando (modo curl)...

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$j = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'; $h = $j.current_release.stable; ($j.releases | Where-Object { $_.hash -eq $h }).archive"`) do set "ARC=%%i"

if "%ARC%"=="" goto flutter_error_version

set "URL=https://storage.googleapis.com/flutter_infra_release/releases/%ARC%"
echo URL: %URL%

curl.exe -L --retry 5 --retry-delay 2 "%URL%" -o "%USERPROFILE%\flutter.zip"

if not exist "%USERPROFILE%\flutter.zip" goto flutter_error_descarga

echo Descarga completada correctamente.

echo Verificando integridad de flutter.zip...
powershell -NoProfile -Command "try { Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::OpenRead('%USERPROFILE%\flutter.zip').Dispose(); exit 0 } catch { exit 1 }"
if %errorlevel% neq 0 goto flutter_zip_corrupto

echo Extrayendo Flutter...
powershell -NoProfile -Command "Expand-Archive -Path '%USERPROFILE%\flutter.zip' -DestinationPath '%USERPROFILE%' -Force"
if %errorlevel% neq 0 goto flutter_error_extraccion

del "%USERPROFILE%\flutter.zip"
goto flutter_path

:flutter_error_version
echo ERROR: No se pudo obtener la version de Flutter.
pause
exit /b

:flutter_error_descarga
echo ERROR: Fallo la descarga de Flutter.
pause
exit /b

:flutter_zip_corrupto
echo ERROR: flutter.zip corrupto, eliminando y abortando.
del /f "%USERPROFILE%\flutter.zip"
pause
exit /b

:flutter_error_extraccion
echo ERROR: Fallo la extraccion de Flutter.
pause
exit /b

:flutter_path
REM ===== 4. PATH Flutter =====
echo [4/7] Configurando PATH Flutter...
powershell -NoProfile -Command "$fb = $env:USERPROFILE + '\flutter\bin'; $cur = [Environment]::GetEnvironmentVariable('PATH','User'); if ($cur -notlike '*flutter\bin*') { [Environment]::SetEnvironmentVariable('PATH', $fb + ';' + $cur, 'User') }"

set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
goto android_inicio

:flutter_listo
echo [4/7] PATH Flutter ya configurado, saltando...

:android_inicio
REM ===== 5. Crear estructura Android SDK =====
echo [5/7] Creando Android SDK...
if not exist "%USERPROFILE%\Android\Sdk" mkdir "%USERPROFILE%\Android\Sdk"

cd /d "%USERPROFILE%\Android"

if not exist sdk.zip goto descargar_sdk

echo Verificando integridad de sdk.zip...
powershell -NoProfile -Command "try { Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::OpenRead('%USERPROFILE%\Android\sdk.zip').Dispose(); exit 0 } catch { exit 1 }"
if %errorlevel% neq 0 goto sdk_zip_corrupto
echo sdk.zip OK, reutilizando.
goto extraer_sdk

:sdk_zip_corrupto
echo sdk.zip corrupto, eliminando...
del /f sdk.zip

:descargar_sdk
echo Descargando commandline-tools...
curl -L --retry 3 -o sdk.zip https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
if %errorlevel% neq 0 goto sdk_error_descarga

:extraer_sdk
if exist cmdline-tools (
    echo Limpiando extraccion anterior de cmdline-tools...
    rmdir /s /q cmdline-tools
)

tar -xf sdk.zip
if %errorlevel% neq 0 goto sdk_error_extraccion

if not exist "%USERPROFILE%\Android\Sdk\cmdline-tools\latest" mkdir "%USERPROFILE%\Android\Sdk\cmdline-tools\latest"
xcopy /E /I /Y cmdline-tools\* "%USERPROFILE%\Android\Sdk\cmdline-tools\latest\" >nul
goto android_vars

:sdk_error_descarga
echo ERROR: Fallo la descarga de commandline-tools.
pause
exit /b

:sdk_error_extraccion
echo ERROR extrayendo sdk.zip, puede estar corrupto.
del /f sdk.zip
pause
exit /b

:android_vars
REM ===== 6. Variables Android =====
echo [6/7] Configurando variables Android...
powershell -NoProfile -Command "[Environment]::SetEnvironmentVariable('ANDROID_HOME', $env:USERPROFILE + '\Android\Sdk', 'User'); [Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $env:USERPROFILE + '\Android\Sdk', 'User')"

powershell -NoProfile -Command "$sdk = $env:USERPROFILE + '\Android\Sdk'; $cur = [Environment]::GetEnvironmentVariable('PATH','User'); if ($cur -notlike '*Android\Sdk*') { [Environment]::SetEnvironmentVariable('PATH', $sdk + '\cmdline-tools\latest\bin;' + $sdk + '\platform-tools;' + $cur, 'User') }"

set "ANDROID_HOME=%USERPROFILE%\Android\Sdk"
set "PATH=%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"

REM ===== 7. Instalar SDK components =====
echo [7/7] Instalando SDK components...
cd /d "%ANDROID_HOME%\cmdline-tools\latest\bin"

echo y | sdkmanager --licenses
call sdkmanager "platform-tools" "platforms;android-36" "build-tools;28.0.3"
echo y | sdkmanager --licenses
if %errorlevel% neq 0 goto sdkmanager_error

adb version >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: ADB no detectado aun (normal, reinicia la terminal)
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
exit /b

:sdkmanager_error
echo ERROR: Fallo sdkmanager.
pause
exit /b
