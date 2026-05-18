param([switch]$OpenBrowser, [switch]$Force)
& "$PSScriptRoot\flutter_run.ps1" -Role mechanic -OpenBrowser:$OpenBrowser -Force:$Force @args
