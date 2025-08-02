cd /d C:\monitoring
start /MIN powershell -C "./check.ps1"
start /MIN powershell -C "./server.ps1"
start /MAX msedge "http://localhost:8080/"