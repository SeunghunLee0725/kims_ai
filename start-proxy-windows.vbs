' KIMS AI 프록시 자동 시작 (백그라운드, 창 없음)
Set objShell = CreateObject("WScript.Shell")
objShell.Run "wsl -d Ubuntu-22.04 -- bash -c ""~/kims-ai-proxy/start-proxy.sh > /tmp/kims-proxy.log 2>&1""", 0, False
