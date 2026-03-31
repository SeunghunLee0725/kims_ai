#!/bin/bash
# ============================================================
#  KIMS AI 프록시 설치 스크립트
#  openchat.kims.re.kr → VS Code Roo Code 연결용
# ============================================================

set -e

INSTALL_DIR="$HOME/kims-ai-proxy"
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

# --- 5. openchat.kims.re.kr 로그인 및 API 토큰 발급 ---
echo ""
echo "============================================"
echo "  openchat.kims.re.kr 로그인"
echo "============================================"
echo ""
echo "  AI 서비스에 로그인하여 API 토큰을 발급받습니다."
echo "  (계정이 없으면 먼저 $OPENCHAT_URL 에서 회원가입하세요)"
echo ""

API_TOKEN=""

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

    # API 키 조회 (이미 생성된 키가 있는지 확인)
    echo "[토큰] API 토큰을 가져오는 중..."
    API_KEY_RESULT=$(curl -s --max-time 10 \
        "$OPENCHAT_URL/api/v1/auths/api_key" \
        -H "Authorization: Bearer $LOGIN_TOKEN" 2>&1)

    EXISTING_KEY=$(echo "$API_KEY_RESULT" | grep -o '"api_key":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$EXISTING_KEY" ] && [ "$EXISTING_KEY" != "null" ]; then
        API_TOKEN="$EXISTING_KEY"
        echo "[성공] API 토큰을 가져왔습니다."
    else
        # 기존 키가 없으면 로그인 토큰 자체를 사용
        # (Open WebUI에서는 로그인 토큰도 API 인증에 사용 가능)
        API_TOKEN="$LOGIN_TOKEN"
        echo "[성공] 로그인 토큰을 API 토큰으로 사용합니다."
    fi
    break
done

# 로그인 실패 시 수동 입력 안내
if [ -z "$API_TOKEN" ]; then
    echo ""
    echo "--------------------------------------------"
    echo "  수동 API 토큰 설정"
    echo "--------------------------------------------"
    echo ""
    echo "  로그인에 실패했거나 건너뛴 경우,"
    echo "  웹 브라우저에서 직접 토큰을 발급받을 수 있습니다:"
    echo ""
    echo "  1. $OPENCHAT_URL 접속 후 로그인"
    echo "  2. 좌측 하단 사용자 이름 클릭"
    echo "  3. '설정(Settings)' 선택"
    echo "  4. '계정(Account)' 탭 → 'API Keys'"
    echo "  5. 'Create new secret key' 클릭"
    echo "  6. 생성된 토큰(eyJ...로 시작)을 복사"
    echo ""
    read -rp "  API 토큰을 붙여넣으세요 (Enter로 건너뛰기): " API_TOKEN
fi

# 토큰 설정
if [ -z "$API_TOKEN" ]; then
    echo ""
    echo "[참고] 토큰을 나중에 설정하려면:"
    echo "  export KIMS_API_KEY='eyJ...' 를 실행하거나"
    echo "  $INSTALL_DIR/api-proxy.js 파일을 직접 수정하세요."
else
    # api-proxy.js 안의 기본값을 실제 토큰으로 교체
    sed -i "s|여기에_API_토큰을_붙여넣으세요|${API_TOKEN}|g" \
        "$INSTALL_DIR/api-proxy.js"
    echo "[설정] API 토큰이 저장되었습니다."
fi

# --- 6. 시작 스크립트 복사 ---
cp "$SCRIPT_DIR/start-proxy.sh" "$INSTALL_DIR/start-proxy.sh"
chmod +x "$INSTALL_DIR/start-proxy.sh"
echo "[설치] start-proxy.sh 복사 완료"

# --- 7. 자동 시작 설정 (선택) ---
echo ""
read -rp "WSL 시작 시 프록시를 자동 실행하시겠습니까? (y/N): " AUTO_START

if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
    BASHRC_LINE="# KIMS AI 프록시 자동 시작"
    if ! grep -q "$BASHRC_LINE" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << RCEOF

$BASHRC_LINE
if ! pgrep -f "node.*api-proxy.js" > /dev/null 2>&1; then
    node "$INSTALL_DIR/api-proxy.js" > /dev/null 2>&1 &
    echo "[KIMS AI 프록시] 백그라운드에서 시작됨 (PID: \$!)"
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
