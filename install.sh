#!/bin/bash
# ============================================================
#  KIMS AI 프록시 설치 스크립트
#  openchat.kims.re.kr → VS Code Roo Code 연결용
# ============================================================

set -e

INSTALL_DIR="$HOME/kims-ai-proxy"
ENV_FILE="$HOME/.kims-ai-proxy.env"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENCHAT_URL="http://openchat.kims.re.kr"

echo ""
echo "============================================"
echo "  KIMS AI 프록시 설치"
echo "============================================"
echo ""

# --- 1. Node.js 확인 ---
if ! command -v node &>/dev/null; then
    echo "[오류] Node.js가 설치되어 있지 않습니다."
    echo "  다음 명령으로 설치하세요:"
    echo "    sudo apt update && sudo apt install -y nodejs"
    exit 1
fi
echo "[확인] Node.js $(node --version) 발견"

# --- 2. curl 확인 ---
if ! command -v curl &>/dev/null; then
    echo "[오류] curl이 설치되어 있지 않습니다."
    echo "  다음 명령으로 설치하세요:"
    echo "    sudo apt install -y curl"
    exit 1
fi

# --- 3. 설치 디렉토리 생성 ---
mkdir -p "$INSTALL_DIR"
echo "[설치] $INSTALL_DIR 디렉토리 생성"

# --- 4. 프록시 스크립트 복사 ---
cp "$SCRIPT_DIR/api-proxy.js" "$INSTALL_DIR/api-proxy.js"
echo "[설치] api-proxy.js 복사 완료"

# --- 5. openchat.kims.re.kr 로그인 및 자격증명 저장 ---
echo ""
echo "============================================"
echo "  openchat.kims.re.kr 로그인"
echo "============================================"
echo ""
echo "  이메일/비밀번호를 저장하면 토큰 만료 시 자동으로 갱신됩니다."
echo "  (계정이 없으면 먼저 $OPENCHAT_URL 에서 회원가입하세요)"
echo ""

SAVED_EMAIL=""
SAVED_PASS=""
LOGIN_OK=false

# 로그인 시도 (최대 3회)
for attempt in 1 2 3; do
    read -rp "  이메일 (아이디): " USER_EMAIL
    read -rsp "  비밀번호: " USER_PASS
    echo ""

    if [ -z "$USER_EMAIL" ] || [ -z "$USER_PASS" ]; then
        echo "[건너뛰기] 이메일/비밀번호가 비어 있습니다."
        break
    fi

    echo "[로그인] $OPENCHAT_URL 에 로그인 중..."

    # 로그인 API 호출
    LOGIN_RESULT=$(curl -s --max-time 10 \
        -X POST "$OPENCHAT_URL/api/v1/auths/signin" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASS\"}" 2>&1)

    # 로그인 토큰 추출
    LOGIN_TOKEN=$(echo "$LOGIN_RESULT" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$LOGIN_TOKEN" ]; then
        echo "[실패] 로그인에 실패했습니다."
        ERROR_MSG=$(echo "$LOGIN_RESULT" | grep -o '"detail":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$ERROR_MSG" ]; then
            echo "  사유: $ERROR_MSG"
        fi
        if [ "$attempt" -lt 3 ]; then
            echo "  다시 시도해주세요. (${attempt}/3)"
            echo ""
        fi
        continue
    fi

    echo "[성공] 로그인 완료"
    SAVED_EMAIL="$USER_EMAIL"
    SAVED_PASS="$USER_PASS"
    LOGIN_OK=true
    break
done

# --- 6. 자격증명 저장 (.env 파일) ---
if [ "$LOGIN_OK" = true ]; then
    # .env 파일에 이메일/비밀번호 저장 (토큰 자동 갱신용)
    cat > "$ENV_FILE" << ENVEOF
# KIMS AI 프록시 자격증명
# 이 파일은 토큰 만료 시 자동 재로그인에 사용됩니다.
# 파일 권한을 600으로 유지하세요 (소유자만 읽기/쓰기).
KIMS_EMAIL='${SAVED_EMAIL}'
KIMS_PASSWORD='${SAVED_PASS}'
ENVEOF
    chmod 600 "$ENV_FILE"
    echo "[설정] 자격증명이 $ENV_FILE 에 저장되었습니다. (권한: 600)"
    echo "       토큰 만료 시 프록시가 자동으로 재로그인합니다."
else
    echo ""
    echo "--------------------------------------------"
    echo "  수동 자격증명 설정"
    echo "--------------------------------------------"
    echo ""
    echo "  로그인에 실패했거나 건너뛴 경우, 다음 중 하나를 선택하세요:"
    echo ""
    echo "  [방법 1] 이메일/비밀번호 저장 (자동 토큰 갱신 지원 — 권장):"
    echo "    cat > $ENV_FILE << 'EOF'"
    echo "    KIMS_EMAIL='your@email.com'"
    echo "    KIMS_PASSWORD='yourpassword'"
    echo "    EOF"
    echo "    chmod 600 $ENV_FILE"
    echo ""
    echo "  [방법 2] API 토큰 직접 설정 (만료 시 수동 갱신 필요):"
    echo "    1. $OPENCHAT_URL 접속 후 로그인"
    echo "    2. 좌측 하단 사용자 이름 클릭 → 설정(Settings)"
    echo "    3. 계정(Account) 탭 → API Keys → Create new secret key"
    echo "    4. 생성된 토큰(eyJ...로 시작)을 복사 후:"
    echo "       echo \"KIMS_API_KEY='eyJ...'\" >> $ENV_FILE"
    echo "       chmod 600 $ENV_FILE"
    echo ""
    read -rp "  API 토큰을 지금 붙여넣으시겠습니까? (Enter로 건너뛰기): " MANUAL_TOKEN
    if [ -n "$MANUAL_TOKEN" ]; then
        cat > "$ENV_FILE" << ENVEOF
# KIMS AI 프록시 자격증명
# 토큰 만료 시 수동으로 갱신이 필요합니다.
# 자동 갱신을 원하면 KIMS_EMAIL / KIMS_PASSWORD 를 추가하세요.
KIMS_API_KEY='${MANUAL_TOKEN}'
ENVEOF
        chmod 600 "$ENV_FILE"
        echo "[설정] API 토큰이 $ENV_FILE 에 저장되었습니다."
    else
        echo "[참고] 나중에 $ENV_FILE 파일을 직접 생성하여 설정하세요."
    fi
fi

# --- 7. 시작 스크립트 복사 ---
cp "$SCRIPT_DIR/start-proxy.sh" "$INSTALL_DIR/start-proxy.sh"
chmod +x "$INSTALL_DIR/start-proxy.sh"
echo "[설치] start-proxy.sh 복사 완료"

# --- 8. 자동 시작 설정 (선택) ---
echo ""
read -rp "WSL 시작 시 프록시를 자동 실행하시겠습니까? (y/N): " AUTO_START

if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
    BASHRC_LINE="# KIMS AI 프록시 자동 시작"
    if ! grep -q "$BASHRC_LINE" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << RCEOF

$BASHRC_LINE
if ! pgrep -f "node.*api-proxy.js" > /dev/null 2>&1; then
    "$INSTALL_DIR/start-proxy.sh" > /dev/null 2>&1 &
    echo "[KIMS AI 프록시] 백그라운드에서 시작됨"
fi
RCEOF
        echo "[설정] ~/.bashrc에 자동 시작 등록 완료"
    else
        echo "[참고] 이미 자동 시작이 등록되어 있습니다."
    fi
else
    echo "[참고] 수동으로 시작하려면: ~/kims-ai-proxy/start-proxy.sh"
fi

# --- 완료 ---
echo ""
echo "============================================"
echo "  설치 완료!"
echo "============================================"
echo ""
echo "  1. 프록시 시작:"
echo "     ~/kims-ai-proxy/start-proxy.sh"
echo ""
echo "  2. Windows VS Code에서 Roo Code 설치:"
echo "     Ctrl+Shift+X → 'Roo Code' 검색 → Install"
echo ""
echo "  3. Roo Code 설정:"
echo "     - API Provider: OpenAI Compatible"
echo "     - Base URL:     http://localhost:4000/api/v1"
echo "     - API Key:      sk-dummy"
echo "     - Model ID:     claude-sonnet-4-6"
echo ""
