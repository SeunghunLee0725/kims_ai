#!/bin/bash
# ============================================================
#  KIMS AI 프록시 시작 스크립트
#  이 파일을 직접 실행하거나, install.sh로 설치 후 사용하세요.
# ============================================================

# 프록시 스크립트 위치 탐색 (설치된 경로 → 현재 디렉토리 순)
if [ -f "$HOME/kims-ai-proxy/api-proxy.js" ]; then
    PROXY_JS="$HOME/kims-ai-proxy/api-proxy.js"
elif [ -f "$(dirname "$0")/api-proxy.js" ]; then
    PROXY_JS="$(cd "$(dirname "$0")" && pwd)/api-proxy.js"
else
    echo "[오류] api-proxy.js를 찾을 수 없습니다."
    echo "  먼저 install.sh를 실행하거나,"
    echo "  api-proxy.js가 있는 디렉토리에서 실행하세요."
    exit 1
fi

# 이미 실행 중인지 확인
if pgrep -f "node.*api-proxy.js" > /dev/null 2>&1; then
    echo "[알림] 프록시가 이미 실행 중입니다."
    echo "  중지: pkill -f 'node.*api-proxy.js'"
    echo "  재시작: pkill -f 'node.*api-proxy.js' && $0"
    exit 0
fi

echo "[시작] KIMS AI 프록시를 시작합니다..."
echo "  스크립트: $PROXY_JS"
echo ""

node "$PROXY_JS" &
PROXY_PID=$!

# 시작 확인 (1초 대기)
sleep 1
if kill -0 "$PROXY_PID" 2>/dev/null; then
    echo ""
    echo "============================================"
    echo "  프록시 실행 중 (PID: $PROXY_PID)"
    echo "============================================"
    echo ""
    echo "  VS Code Roo Code 설정값:"
    echo "    Base URL : http://localhost:4000/api/v1"
    echo "    API Key  : sk-dummy"
    echo "    Model    : claude-sonnet-4-6"
    echo ""
    echo "  프록시 종료:"
    echo "    kill $PROXY_PID"
    echo "    또는 pkill -f 'node.*api-proxy.js'"
    echo ""
else
    echo "[오류] 프록시 시작에 실패했습니다."
    echo "  api-proxy.js 파일에서 API 토큰을 확인하세요."
    exit 1
fi
