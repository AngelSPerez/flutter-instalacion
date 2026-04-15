@echo off
setlocal enabledelayedexpansion

echo =====================================
echo SETUP FLUTTER + ANDROID SDK (SIN UAC)
echo =====================================

REM ===== 1. Descargar Java 21 OpenJDK (ZIP, sin admin) =====
echo [1/7] Instalando Java 21 OpenJDK...

set "JAVA_DIR=%USERPROFILE%\Java"
set "JAVA_HOME=%JAVA_DIR%\jdk-21"

if not exist "%JAVA_HOME%\bin\java.exe" (
    if not exist "%JAVA_DIR%" mkdir "%JAVA_DIR%"

    echo Descargando JDK 21 desde Adoptium...
    powershell -NoProfile -Command ^
        "Invoke-WebRequest -Uri 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse' -OutFile '%JAVA_DIR%\jdk21.zip'"

    echo Verificando integridad de jdk21.zip...
    powershell -NoProfile -Command ^
        "try { Add-Type -Assembly 'System.IO.Compression.FileSystem'; " ^
        "[System.IO.Compression.ZipFile]::OpenRead('%JAVA_DIR%\jdk21.zip').Dispose(); " ^
        "exit 0 } catch { exit 1 }"
    if %errorlevel% neq 0 (
        echo ERROR: jdk21.zip corrupto, eliminando y abortando.
        del /f "%JAVA_DIR%\jdk21.zip"
        pause
        exit /b
    )

    echo Extrayendo JDK...
    powershell -NoProfile -Command ^
        "Expand-Archive -Path '%JAVA_DIR%\jdk21.zip' -DestinationPath '%JAVA_DIR%\tmp21' -Force"

    for /d %%i in ("%JAVA_DIR%\tmp21\*") do (
        move "%%i" "%JAVA_HOME%" >nul
    )
    rmdir /s /q "%JAVA_DIR%\tmp21"
    del "%JAVA_DIR%\jdk21.zip"
) else (
    echo Java 21 ya existe, OK
)

REM ===== 2. Configurar JAVA_HOME y ponerlo AL TOPE del PATH =====
echo [2/7] Configurando JAVA_HOME y PATH...

powershell -NoProfile -Command ^
    "[Environment]::SetEnvironmentVariable('JAVA_HOME', '%JAVA_HOME%', 'User')"

powershell -NoProfile -Command ^
    "$jbin = '%JAVA_HOME%\bin'; " ^
    "$cur  = [Environment]::GetEnvironmentVariable('PATH','User'); " ^
    "$cleaned = ($cur -split ';' | Where-Object { $_ -notlike '*Java\jdk*' }) -join ';'; " ^
    "[Environment]::SetEnvironmentVariable('PATH', $jbin + ';' + $cleaned, 'User')"

set "PATH=%JAVA_HOME%\bin;%PATH%"

java -version
if %errorlevel% neq 0 (
    echo ERROR: Java no responde. Revisa la descarga.
    pause
    exit /b
)

REM ===== 3. Flutter - deteccion =====
echo [3/7] Configurando Flutter...

where flutter >nul 2>&1
if %errorlevel% equ 0 (
    echo Flutter ya instalado y en PATH, saltando descarga.
    goto :flutter_listo
)

if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    echo Flutter existe en disco pero no estaba en PATH.
    goto :flutter_path
)

echo Flutter no detectado, descargando (modo curl)...

for /f "delims=" %%i in ('powershell -NoProfile -Command ^
    "$j = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'; ^
    $h = $j.current_release.stable; ^
    ($j.releases | Where-Object { $_.hash -eq $h }).archive"') do set "ARC=%%i"

if "%ARC%"=="" (
    echo ERROR: No se pudo obtener la version de Flutter.
    pause
    exit /b
)

set "URL=https://storage.googleapis.com/flutter_infra_release/releases/%ARC%"

echo URL: %URL%

curl.exe -L --retry 5 --retry-delay 2 "%URL%" -o "%USERPROFILE%\flutter.zip"

if not exist "%USERPROFILE%\flutter.zip" (
    echo ERROR: Fallo la descarga de Flutter.
    pause
    exit /b
)

echo Descarga completada correctamente.

echo Verificando integridad de flutter.zip...
powershell -NoProfile -Command ^
    "try { Add-Type -Assembly 'System.IO.Compression.FileSystem'; " ^
    "[System.IO.Compression.ZipFile]::OpenRead('%USERPROFILE%\flutter.zip').Dispose(); " ^
    "exit 0 } catch { exit 1 }"
if %errorlevel% neq 0 (
    echo ERROR: flutter.zip corrupto, eliminando y abortando.
    del /f "%USERPROFILE%\flutter.zip"
    pause
    exit /b
)

echo Extrayendo Flutter...
powershell -NoProfile -Command ^
    "Expand-Archive -Path '%USERPROFILE%\flutter.zip' -DestinationPath '%USERPROFILE%' -Force"

if %errorlevel% neq 0 (
    echo ERROR: Fallo la extraccion de Flutter.
    pause
    exit /b
)

del "%USERPROFILE%\flutter.zip"

:flutter_path
REM ===== 4. PATH Flutter =====
echo [4/7] Configurando PATH Flutter...
powershell -NoProfile -Command ^
    "$fb  = $env:USERPROFILE + '\flutter\bin'; " ^
    "$cur = [Environment]::GetEnvironmentVariable('PATH','User'); " ^
    "if ($cur -notlike '*flutter\bin*') { [Environment]::SetEnvironmentVariable('PATH', $fb + ';' + $cur, 'User') }"

set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
goto :android_inicio

:flutter_listo
echo [4/7] PATH Flutter ya configurado, saltando...

:android_inicio
REM ===== 5. Crear estructura Android SDK =====
echo [5/7] Creando Android SDK...
if not exist "%USERPROFILE%\Android\Sdk" mkdir "%USERPROFILE%\Android\Sdk"

cd /d "%USERPROFILE%\Android"

REM --- Verificar si sdk.zip existe y no esta corrupto ---
if exist sdk.zip (
    echo Verificando integridad de sdk.zip...
    powershell -NoProfile -Command ^
        "try { Add-Type -Assembly 'System.IO.Compression.FileSystem'; " ^
        "[System.IO.Compression.ZipFile]::OpenRead('%USERPROFILE%\Android\sdk.zip').Dispose(); " ^
        "exit 0 } catch { exit 1 }"
    if %errorlevel% neq 0 (
        echo sdk.zip corrupto, eliminando...
        del /f sdk.zip
    ) else (
        echo sdk.zip OK, reutilizando.
    )
)

if not exist sdk.zip (
    echo Descargando commandline-tools...
    curl -L --retry 3 -o sdk.zip https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
    if %errorlevel% neq 0 (
        echo ERROR: Fallo la descarga de commandline-tools.
        pause
        exit /b
    )
)

REM --- Limpiar extraccion previa si existe ---
if exist cmdline-tools (
    echo Limpiando extraccion anterior de cmdline-tools...
    rmdir /s /q cmdline-tools
)

tar -xf sdk.zip
if %errorlevel% neq 0 (
    echo ERROR extrayendo sdk.zip, puede estar corrupto.
    del /f sdk.zip
    pause
    exit /b
)

if not exist "%USERPROFILE%\Android\Sdk\cmdline-tools\latest" (
    mkdir "%USERPROFILE%\Android\Sdk\cmdline-tools\latest"
)
xcopy /E /I /Y cmdline-tools\* "%USERPROFILE%\Android\Sdk\cmdline-tools\latest\" >nul

REM ===== 6. Variables Android =====
echo [6/7] Configurando variables Android...
powershell -NoProfile -Command ^
    "[Environment]::SetEnvironmentVariable('ANDROID_HOME',     $env:USERPROFILE + '\Android\Sdk', 'User'); " ^
    "[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $env:USERPROFILE + '\Android\Sdk', 'User')"

powershell -NoProfile -Command ^
    "$sdk = $env:USERPROFILE + '\Android\Sdk'; " ^
    "$cur = [Environment]::GetEnvironmentVariable('PATH','User'); " ^
    "if ($cur -notlike '*Android\Sdk*') { " ^
    "  [Environment]::SetEnvironmentVariable('PATH', $sdk + '\cmdline-tools\latest\bin;' + $sdk + '\platform-tools;' + $cur, 'User') }"

set "ANDROID_HOME=%USERPROFILE%\Android\Sdk"
set "PATH=%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"

REM ===== 7. Instalar SDK components =====
echo [7/7] Instalando SDK components...
cd /d "%ANDROID_HOME%\cmdline-tools\latest\bin"

echo y | sdkmanager --licenses
call sdkmanager "platform-tools" "platforms;android-36" "build-tools;28.0.3"
echo y | sdkmanager --licenses
if %errorlevel% neq 0 (
    echo ERROR: Fallo sdkmanager.
    pause
    exit /b
)

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
