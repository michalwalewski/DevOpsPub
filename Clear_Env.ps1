Write-Host "Clearing the environment.." -ForegroundColor Green
& "C:\Program Files\TAP-Windows\bin\tapinstall.exe" remove tap0901

Remove-Item -Recurse -Force C:\nodepool

& "C:\Program Files\TAP-Windows\bin\tapinstall.exe" install "C:\Program Files\TAP-Windows\driver\OemVista.inf" tap0901 -ErrorAction Stop -ErrorVariable SearchError

Write-Host "Completed" -ForegroundColor Green
