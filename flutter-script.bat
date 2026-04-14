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

    echo Extrayendo JDK...
    powershell -NoProfile -Command ^
        "Expand-Archive -Path '%JAVA_DIR%\jdk21.zip' -DestinationPath '%JAVA_DIR%\tmp21' -Force"

    REM Adoptium extrae a una carpeta tipo jdk-21.x.x+xx — la renombramos a jdk-21
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

REM Inserta Java al inicio del PATH de usuario (elimina duplicados si ya estaba)
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

REM ===== 3. Descargar Flutter como ZIP (sin Git) =====
echo [3/7] Descargando Flutter...

if not exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    echo Obteniendo URL de la version estable...
    powershell -NoProfile -Command ^
        "$j   = (Invoke-WebRequest 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json').Content | ConvertFrom-Json; " ^
        "$h   = $j.current_release.stable; " ^
        "$arc = ($j.releases | Where-Object { $_.hash -eq $h }).archive; " ^
        "$url = $j.base_url + '/' + $arc; " ^
        "Write-Host $url; " ^
        "Invoke-WebRequest -Uri $url -OutFile '%USERPROFILE%\flutter.zip'"

    echo Extrayendo Flutter...
    powershell -NoProfile -Command ^
        "Expand-Archive -Path '%USERPROFILE%\flutter.zip' -DestinationPath '%USERPROFILE%' -Force"

    del "%USERPROFILE%\flutter.zip"
) else (
    echo Flutter ya existe, OK
)

REM ===== 4. PATH Flutter =====
echo [4/7] Configurando PATH Flutter...
powershell -NoProfile -Command ^
    "$fb  = $env:USERPROFILE + '\flutter\bin'; " ^
    "$cur = [Environment]::GetEnvironmentVariable('PATH','User'); " ^
    "if ($cur -notlike '*flutter\bin*') { [Environment]::SetEnvironmentVariable('PATH', $fb + ';' + $cur, 'User') }"

set "PATH=%USERPROFILE%\flutter\bin;%PATH%"

REM ===== 5. Crear estructura Android SDK =====
echo [5/7] Creando Android SDK...
if not exist "%USERPROFILE%\Android\Sdk" mkdir "%USERPROFILE%\Android\Sdk"

cd /d "%USERPROFILE%\Android"

if not exist sdk.zip (
    echo Descargando commandline-tools...
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

echo y | call sdkmanager --licenses
call sdkmanager "platform-tools" "platforms;android-36" "build-tools;28.0.3"
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
