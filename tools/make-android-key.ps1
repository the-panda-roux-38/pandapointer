# Crée la clé de signature de l'APK PandaPointer (une seule fois).
#  - la clé et son mot de passe sont rangés HORS du dépôt : %USERPROFILE%\PandaPointer-signing\
#  - si l'outil « gh » (GitHub CLI) est installé et connecté, les secrets du dépôt sont ajoutés tout seuls ;
#    sinon, le script t'indique quoi copier où.
# Lancer avec :  powershell -ExecutionPolicy Bypass -File tools\make-android-key.ps1
$ErrorActionPreference = "Stop"
$repo = "the-panda-roux-38/pandapointer"
$dir = Join-Path $env:USERPROFILE "PandaPointer-signing"
$jks = Join-Path $dir "release.jks"
if (Test-Path $jks) { throw "Une clé existe déjà : $jks. Je ne l'écrase pas (tu perdrais les mises à jour)." }

# 1. Trouver keytool (livré avec Java / Android Studio)
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    $candidates = @(
        "$env:JAVA_HOME\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"
    )
    $keytool = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $keytool) { throw "keytool introuvable. Installe Android Studio (il contient Java) ou ajoute Java au PATH." }

# 2. Mot de passe aléatoire
$bytes = New-Object byte[] 18
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$password = -join ($bytes | ForEach-Object { $_.ToString("x2") })

# 3. Fabriquer la clé (valable ~27 ans)
New-Item -ItemType Directory -Force $dir | Out-Null
& $keytool -genkeypair -keystore $jks -alias pandapointer -keyalg RSA -keysize 2048 -validity 10000 `
    -storepass $password -keypass $password -dname "CN=PandaPointer, O=Panda"
if ($LASTEXITCODE -ne 0) { throw "keytool a échoué." }
Set-Content -Path (Join-Path $dir "mot-de-passe.txt") -Value $password -Encoding ascii
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))

Write-Host ""
Write-Host "Clé créée dans : $dir" -ForegroundColor Green
Write-Host "SAUVEGARDE ce dossier (clé USB, cloud perso) : sans lui, plus de mises à jour de l'appli installée." -ForegroundColor Yellow

# 4. Secrets GitHub
$gh = Get-Command gh -ErrorAction SilentlyContinue
$done = $false
if ($gh) {
    & gh auth status *> $null
    if ($LASTEXITCODE -eq 0) {
        & gh secret set ANDROID_KEYSTORE_B64 --repo $repo --body $b64
        & gh secret set ANDROID_KEYSTORE_PASSWORD --repo $repo --body $password
        if ($LASTEXITCODE -eq 0) { $done = $true; Write-Host "Secrets GitHub ajoutés automatiquement." -ForegroundColor Green }
    }
}
if (-not $done) {
    Set-Clipboard -Value $b64
    Write-Host ""
    Write-Host "À faire à la main sur GitHub : https://github.com/$repo/settings/secrets/actions" -ForegroundColor Cyan
    Write-Host "  1. New repository secret  ->  ANDROID_KEYSTORE_B64  ->  colle (c'est déjà dans ton presse-papiers)"
    Write-Host "  2. New repository secret  ->  ANDROID_KEYSTORE_PASSWORD  ->  le contenu de mot-de-passe.txt"
}
