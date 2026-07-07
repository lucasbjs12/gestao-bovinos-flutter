# Build de release com ofuscação do código Dart.
#
# Uso:
#   .\scripts\build_release.ps1          -> gera o AAB (para a Play Store)
#   .\scripts\build_release.ps1 apk      -> gera o APK (instalação direta)
#
# Os símbolos de depuração ficam em build\symbols. GUARDE essa pasta junto
# com o backup do keystore a cada versão publicada: sem ela não é possível
# traduzir stack traces ofuscados de crashes (flutter symbolize).
param(
    [ValidateSet('aab', 'apk')]
    [string]$Tipo = 'aab'
)

$alvo = if ($Tipo -eq 'aab') { 'appbundle' } else { 'apk' }

flutter build $alvo --release --obfuscate --split-debug-info=build/symbols

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Build concluido." -ForegroundColor Green
    if ($Tipo -eq 'aab') {
        Write-Host "AAB: build\app\outputs\bundle\release\app-release.aab"
    } else {
        Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk"
    }
    Write-Host "Simbolos (guarde com o backup!): build\symbols"
}
