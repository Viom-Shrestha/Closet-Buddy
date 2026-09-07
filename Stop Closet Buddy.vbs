Set shell = CreateObject("WScript.Shell")
shell.Run "taskkill /IM closet_buddy.exe /F", 0, True
shell.Run "powershell.exe -NoProfile -WindowStyle Hidden -Command ""Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }""", 0, True
