$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$distDir = Join-Path $repoRoot 'alist\public\dist'
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('alist-web-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
try {
    $archive = Join-Path $tempDir 'dist.tar.gz'
    Invoke-WebRequest -UseBasicParsing `
        -Uri 'https://github.com/alist-org/alist-web/releases/latest/download/dist.tar.gz' `
        -OutFile $archive
    tar -xzf $archive -C $tempDir
    if (Test-Path $distDir) { Remove-Item -LiteralPath $distDir -Recurse -Force }
    Move-Item -LiteralPath (Join-Path $tempDir 'dist') -Destination $distDir
    Write-Output "Fetched Alist web distribution into $distDir"
} finally {
    if (Test-Path $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
}
