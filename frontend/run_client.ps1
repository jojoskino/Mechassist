param([switch]$OpenBrowser, [switch]$Force)
& "$PSScriptRoot\flutter_run.ps1" -Role client -OpenBrowser:$OpenBrowser -Force:$Force @args
