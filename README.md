# flutter-instalacion

# =========================
# JAVA SWITCH (SCOOP) AUTO
# =========================

$javaHome = "$env:USERPROFILE\scoop\apps\temurin21-jdk\current"

# ---------- TEMPORAL ----------
$env:JAVA_HOME = $javaHome
$env:Path = "$javaHome\bin;$env:Path"

Write-Host "== TEMPORAL ACTIVADO ==" -ForegroundColor Green
java -version
where java


# ---------- PERMANENTE ----------
[Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")

$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($oldPath -notlike "*temurin21-jdk*") {
    $newPath = "$javaHome\bin;" + $oldPath
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

Write-Host "== PERMANENTE CONFIGURADO ==" -ForegroundColor Yellow
