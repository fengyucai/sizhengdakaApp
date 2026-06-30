param(
    [string]$Alias = "ai-sizheng",
    [string]$StorePassword = "",
    [string]$KeyPassword = "",
    [string]$DName = "CN=AI Sizheng, OU=Computer College, O=University of South China, L=Hengyang, ST=Hunan, C=CN"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $projectRoot "android"
$appDir = Join-Path $androidDir "app"
$keystorePath = Join-Path $appDir "ai-sizheng-release.jks"
$keyPropertiesPath = Join-Path $androidDir "key.properties"

if ([string]::IsNullOrWhiteSpace($StorePassword)) {
    $secure = Read-Host "Keystore password" -AsSecureString
    $StorePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    )
}

if ([string]::IsNullOrWhiteSpace($KeyPassword)) {
    $KeyPassword = $StorePassword
}

if (Test-Path -LiteralPath $keystorePath) {
    throw "Keystore already exists: $keystorePath"
}

keytool -genkeypair `
    -v `
    -keystore $keystorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $Alias `
    -storepass $StorePassword `
    -keypass $KeyPassword `
    -dname $DName

@"
storePassword=$StorePassword
keyPassword=$KeyPassword
keyAlias=$Alias
storeFile=app/ai-sizheng-release.jks
"@ | Set-Content -LiteralPath $keyPropertiesPath -Encoding ascii

Write-Host "Release keystore created: $keystorePath"
Write-Host "Signing config written: $keyPropertiesPath"
