#!/bin/bash
# ============================================================
#  KIMS AI 프록시 시작 스크립트
#  이 파일을 직접 실행하거나, install.sh로 설치 후 사용하세요.
# ============================================================

ENV_FILE="$HOME/.kims-ai-proxy.env"

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

# .env 파일 로드 (이메일/비밀번호 또는 API 토큰)
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set -a
    source "$ENV_FILE"
    set +a
    echo "[설정] $ENV_FILE 로드 완료"
else
    echo "[경고] $ENV_FILE 파일이 없습니다."
    echo "  install.sh를 실행하거나 직접 파일을 생성하세요:"
    echo ""
    echo "  [자동 갱신 — 권장]"
    echo "    cat > $ENV_FILE << 'EOF'"
    echo "    KIMS_EMAIL='your@email.com'"
    echo "    KIMS_PASSWORD='yourpassword'"
    echo "    EOF"
    echo "    chmod 600 $ENV_FILE"
    echo ""
    echo "  [수동 토큰]"
    echo "    echo \"KIMS_API_KEY='eyJ...'\" > $ENV_FILE"
    echo "    chmod 600 $ENV_FILE"
    echo ""
    # 환경변수가 이미 설정되어 있으면 계속 진행
    if [ -z "$KIMS_EMAIL" ] && [ -z "$KIMS_API_KEY" ]; then
        echo "[오류] 인증 정보가 없습니다. 프록시를 시작할 수 없습니다."
        exit 1
    fi
    echo "[참고] 현재 셸 환경변수를 사용하여 계속 진행합니다."
fi

# 인증 정보 확인
if [ -n "$KIMS_EMAIL" ]; then
    echo "[인증] 이메일/비밀번호 방식 (자동 토큰 갱신 활성화)"
elif [ -n "$KIMS_API_KEY" ]; then
    echo "[인증] API 토큰 방식 (만료 시 수동 갱신 필요)"
else
    echo "[오류] KIMS_EMAIL 또는 KIMS_API_KEY가 설정되지 않았습니다."
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
    echo "  $ENV_FILE 파일의 인증 정보를 확인하세요."
    exit 1
fi
