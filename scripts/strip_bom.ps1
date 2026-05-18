param([string]$Path)
$content = Get-Content $Path -Raw -Encoding UTF8
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Resolve-Path $Path).Path, $content, $utf8NoBom)
Write-Host "Stripped BOM from $Path"
