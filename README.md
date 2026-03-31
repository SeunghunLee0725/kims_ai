# VS Code에서 KIMS 내부 AI 사용하기 (Roo Code + 프록시)

원내 AI 서비스(openchat.kims.re.kr)를 Windows VS Code에서 코딩 어시스턴트로 활용하는 방법을 안내합니다.

---

## 개요

**문제**: VS Code의 AI 확장(Roo Code, Cline 등)은 OpenAI 호환 API를 지원하지만, openchat.kims.re.kr 서버에 직접 연결하면 인증 헤더 처리 방식 차이로 `401 Unauthorized` 오류가 발생합니다.

**해결**: WSL2에서 로컬 프록시를 실행하여 인증 헤더를 올바르게 주입하고, Roo Code는 이 프록시에 연결합니다.

```
┌─────────────────────────────────────────────────────────┐
│  Windows                                                │
│  ┌───────────────┐         ┌──────────────────────────┐ │
│  │ VS Code       │         │ WSL2                     │ │
│  │  (Roo Code)   │───────▶│  Node.js 프록시 (:4000)  │─┼──▶ openchat.kims.re.kr
│  │               │ :4000   │  (인증 헤더 자동 추가)   │ │       (내부 AI 서버)
│  └───────────────┘         └──────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 자동 토큰 갱신

프록시는 이메일/비밀번호를 `~/.kims-ai-proxy.env`에 저장하여, 토큰이 만료(`401`)되면 **자동으로 재로그인하여 토큰을 갱신**합니다. 별도의 수동 작업이 필요 없습니다.

---

## 사전 요구사항

- Windows 10/11 (WSL2 활성화)
- WSL2에 Node.js 설치 (`node --version` 으로 확인)
- Windows용 VS Code 설치
- 원내 네트워크 접속 환경

Node.js가 없는 경우 WSL2 터미널에서:
```bash
sudo apt update && sudo apt install -y nodejs
```

---

## 설정 절차

### 1단계: openchat.kims.re.kr 계정 준비

1. 브라우저에서 **http://openchat.kims.re.kr/** 접속
2. 계정이 없으면 **회원가입(Sign up)** 진행
3. **이메일(아이디)**과 **비밀번호**를 기억해 두세요 (설치 스크립트에서 사용)

### 2단계: 프록시 설치

WSL2 터미널을 열고 다운받은 폴더로 이동해 다음을 실행합니다:

```bash
bash install.sh
```

설치 스크립트가 자동으로:
- Node.js 설치 여부를 확인하고
- `~/kims-ai-proxy/` 디렉토리를 생성하고
- **openchat.kims.re.kr에 로그인하여 이메일/비밀번호를 `~/.kims-ai-proxy.env`에 저장**하고
- 토큰 만료 시 자동 재로그인이 가능하도록 설정합니다

> **보안**: `~/.kims-ai-proxy.env` 파일은 권한 `600`(소유자만 읽기/쓰기)으로 생성됩니다.

**수동 자격증명 설정** (자동 로그인 실패 시):

```bash
# 방법 1: 이메일/비밀번호 저장 (자동 토큰 갱신 지원 — 권장)
cat > ~/.kims-ai-proxy.env << 'EOF'
KIMS_EMAIL='your@email.com'
KIMS_PASSWORD='yourpassword'
EOF
chmod 600 ~/.kims-ai-proxy.env

# 방법 2: API 토큰 직접 저장 (만료 시 수동 갱신 필요)
echo "KIMS_API_KEY='eyJ...'" > ~/.kims-ai-proxy.env
chmod 600 ~/.kims-ai-proxy.env
```

**API 토큰 수동 발급** (방법 2 선택 시):
1. 브라우저에서 **http://openchat.kims.re.kr/** 접속 후 로그인
2. 좌측 하단 **사용자 이름** 클릭
3. **설정(Settings)** 선택
4. **계정(Account)** 탭 → **API Keys**
5. **Create new secret key** 클릭
6. 생성된 토큰(`eyJ`로 시작하는 긴 문자열)을 복사

### 3단계: 프록시 실행

```bash
~/kims-ai-proxy/start-proxy.sh
```

또는 직접:
```bash
node ~/kims-ai-proxy/api-proxy.js
```

정상 실행 시 다음과 같이 표시됩니다:
```
[설정] /home/user/.kims-ai-proxy.env 로드 완료
[인증] 이메일/비밀번호 방식 (자동 토큰 갱신 활성화)
[시작] KIMS AI 프록시를 시작합니다...
[KIMS AI 프록시] http://localhost:4000 에서 실행 중
[KIMS AI 프록시] http://openchat.kims.re.kr 로 요청 전달 (인증 헤더 자동 추가)
[KIMS AI 프록시] 자동 토큰 갱신 활성화 (계정: your@email.com)
```

> **중요**: VS Code에서 AI를 사용하려면 프록시가 항상 실행되어 있어야 합니다.

### 4단계: Roo Code 확장 설치

1. Windows에서 VS Code 실행
2. 확장(Extensions) 패널 열기 (`Ctrl+Shift+X`)
3. **"Roo Code"** 검색
4. **Install** 클릭

### 5단계: Roo Code 설정

1. Roo Code 아이콘 클릭 (좌측 사이드바)
2. 설정(톱니바퀴 아이콘) 클릭
3. 다음 값을 입력:

| 항목 | 값 |
|------|-----|
| **API Provider** | `OpenAI Compatible` |
| **Base URL** | `http://localhost:4000/api/v1` |
| **API Key** | `sk-dummy` |
| **Model ID** | `claude-sonnet-4-6` |

4. 설정 저장 후 채팅창에 질문을 입력하여 동작 확인

---

## 사용 가능한 모델 목록

### Claude (추천)
| 모델 ID | 설명 |
|---------|------|
| `claude-opus-4-6` | 최고 성능, 복잡한 작업에 적합 |
| `claude-sonnet-4-6` | **추천** - 성능과 속도의 균형 |
| `claude-haiku` | 빠른 응답, 간단한 작업에 적합 |

### GPT-5.4
| 모델 ID | 설명 |
|---------|------|
| `gpt-5.4-xhigh` | 최고 품질 |
| `gpt-5.4-high` | 고품질 |
| `gpt-5.4-medium` | 중간 품질 |
| `gpt-5.4-low` | 저품질 (빠름) |
| `gpt-5.4-none` | 최소 품질 (가장 빠름) |

> **참고**: GPT-5.4 모델은 `temperature=0` 설정을 지원하지 않으므로, Roo Code에서는 Claude 계열 모델을 사용하는 것을 권장합니다.

### Perplexity (검색 특화)
| 모델 ID | 설명 |
|---------|------|
| `perplexity-sonar-pro` | 고급 검색 |
| `perplexity-sonar-reasoning` | 추론 포함 검색 |
| `perplexity-sonar` | 기본 검색 |

---

## 문제 해결

### 프록시가 시작되지 않음

```
[오류] 인증 정보가 없습니다. 프록시를 시작할 수 없습니다.
```
- `~/.kims-ai-proxy.env` 파일이 없거나 비어 있습니다.
- 다음 명령으로 생성하세요:
  ```bash
  cat > ~/.kims-ai-proxy.env << 'EOF'
  KIMS_EMAIL='your@email.com'
  KIMS_PASSWORD='yourpassword'
  EOF
  chmod 600 ~/.kims-ai-proxy.env
  ```

### Roo Code에서 "연결할 수 없습니다" 오류

1. WSL2 터미널에서 프록시가 실행 중인지 확인:
   ```bash
   pgrep -f "node.*api-proxy.js" && echo "실행 중" || echo "중지됨"
   ```
2. 프록시가 중지되었으면 다시 시작:
   ```bash
   ~/kims-ai-proxy/start-proxy.sh
   ```
3. Base URL이 정확한지 확인: `http://localhost:4000/api/v1`

### 401 Unauthorized 오류

- **이메일/비밀번호 방식**: 프록시가 자동으로 재로그인합니다. 로그에서 `[토큰] 토큰 갱신 완료` 메시지를 확인하세요.
- **API 토큰 방식**: 토큰이 만료되었습니다. 새 토큰을 발급받고 `.env` 파일을 업데이트하세요:
  ```bash
  # ~/.kims-ai-proxy.env 파일에서 KIMS_API_KEY 값을 새 토큰으로 교체
  nano ~/.kims-ai-proxy.env
  # 프록시 재시작
  pkill -f "node.*api-proxy.js"
  ~/kims-ai-proxy/start-proxy.sh
  ```
- **근본 해결**: `~/.kims-ai-proxy.env`에 `KIMS_EMAIL` / `KIMS_PASSWORD`를 설정하면 자동 갱신됩니다.

### 502 Proxy Error

- 원내 네트워크에 연결되어 있는지 확인하세요.
- `curl http://openchat.kims.re.kr` 으로 서버 접근 가능 여부를 확인하세요.

### 포트 4000이 이미 사용 중

- 환경변수로 다른 포트를 지정할 수 있습니다:
  ```bash
  PROXY_PORT=4001 node ~/kims-ai-proxy/api-proxy.js
  ```
- 또는 `.env` 파일에 추가:
  ```bash
  echo "PROXY_PORT=4001" >> ~/.kims-ai-proxy.env
  ```
- Roo Code의 Base URL도 해당 포트로 변경하세요.

### 프록시 완전 종료

```bash
pkill -f "node.*api-proxy.js"
```

---

## Roo Code 모드별 모델 설정

Roo Code는 5가지 모드(역할)를 제공하며, 각 모드의 특성에 맞는 최적 모델을 할당하면 품질과 속도를 동시에 최적화할 수 있습니다.

### 모드별 권장 모델 요약

| 모드 | 역할 이름 | 권장 모델 | 선택 이유 |
|------|-----------|-----------|-----------|
| `code` | 💻 Code | `claude-sonnet-4-6` | 코드 품질과 응답 속도의 최적 균형 |
| `architect` | 🏗️ Architect | `claude-opus-4-6` | 깊은 추론·트레이드오프 분석 필요 |
| `ask` | ❓ Ask | `claude-sonnet-4-6` | 빠른 응답과 폭넓은 지식 커버리지 |
| `debug` | 🪲 Debug | `claude-opus-4-6` | 정밀한 추론과 코드 흐름 파악 필수 |
| `orchestrator` | 🪃 Orchestrator | `gpt-5.4-xhigh` | 연구 수준 심층 분석·대규모 계획 수립 |

### 모델 선택 상세 근거

#### 💻 Code 모드 → `claude-sonnet-4-6`

코드 작성·수정·리팩토링·버그 수정이 주 목적입니다.

- Claude 계열은 코드 문법 정확도, 관용적 표현, 테스트 코드 생성에서 최상위 성능을 보입니다.
- Sonnet은 Opus 대비 응답 속도가 빠르면서도 코딩 능력이 충분하여, 반복적인 편집 작업에 최적입니다.
- 코드 모드는 하루에도 수십 번 호출되므로 속도·품질 균형이 중요합니다.

#### 🏗️ Architect 모드 → `claude-opus-4-6`

시스템 설계, 기술 명세, 아키텍처 계획이 주 목적입니다.

- 아키텍처 결정은 장기적 영향을 미치므로 응답 속도보다 **추론 깊이와 품질**이 우선입니다.
- Opus는 Claude 계열 최고 성능 모델로, 복잡한 시스템 간 의존성 분석, 확장성 트레이드오프 평가, 기술 부채 예측에 탁월합니다.
- 호출 빈도가 낮고 한 번의 고품질 응답이 중요한 모드입니다.

#### ❓ Ask 모드 → `claude-sonnet-4-6`

개념 설명, 문서화, 기술 질문 답변이 주 목적입니다.

- 빠른 응답과 다양한 기술 도메인 지식이 핵심입니다.
- Sonnet은 Haiku보다 답변 품질이 높고, Opus보다 응답이 빠릅니다.
- 웹 검색이 필요한 경우 `perplexity-sonar-pro`로 교체를 고려하세요.

#### 🪲 Debug 모드 → `claude-opus-4-6`

디버깅, 오류 분석, 스택 트레이스 해석, 로그 분석이 주 목적입니다.

- 스택 트레이스 해석, 코드 실행 흐름 추적, 근본 원인(root cause) 분석은 **정밀한 다단계 추론**이 필요합니다.
- Opus의 높은 추론 능력이 복잡한 버그 재현 경로 파악과 정확한 수정 방향 제시에 결정적 차이를 만듭니다.
- 잘못된 디버깅 방향은 시간 낭비로 이어지므로 최고 품질 모델이 비용 효율적입니다.

#### 🪃 Orchestrator 모드 → `gpt-5.4-xhigh`

복잡한 워크플로우 조율, 멀티 에이전트 관리, 작업 분해가 주 목적입니다.

- Orchestrator는 전체 작업을 분해하고 하위 에이전트(Code, Debug 등)에 지시하는 **최상위 계획자** 역할입니다.
- `gpt-5.4-xhigh`는 연구 수준의 심층 분석과 대규모 코드 설계 능력을 갖추고 있습니다.
- Claude와 다른 모델 계열을 사용함으로써 관점 다양성을 확보하고, 단일 모델 편향을 방지합니다.

### VS Code settings.json 적용 방법

**방법 1: roo-settings.json 파일 사용 (권장)**

1. `Ctrl+Shift+P` → **"Open User Settings (JSON)"** 실행
2. 프로젝트 루트의 [`roo-settings.json`](roo-settings.json) 파일을 열기
3. `roo-cline.modeApiConfigs` 블록을 복사하여 `settings.json`에 붙여넣기

```json
{
  "roo-cline.modeApiConfigs": {
    "code":         { "model": "claude-sonnet-4-6" },
    "architect":    { "model": "claude-opus-4-6"   },
    "ask":          { "model": "claude-sonnet-4-6" },
    "debug":        { "model": "claude-opus-4-6"   },
    "orchestrator": { "model": "gpt-5.4-xhigh"     }
  }
}
```

**방법 2: Roo Code UI에서 직접 설정**

1. Roo Code 사이드바 → 모드 선택 드롭다운 옆 **설정 아이콘** 클릭
2. 각 모드별로 모델 ID를 [`roo-models.env`](roo-models.env) 파일의 값으로 입력

### 대안 모델

| 상황 | 대안 모델 |
|------|-----------|
| Ask 모드에서 최신 웹 정보 필요 | `perplexity-sonar-pro` |
| Ask 모드에서 빠른 응답 우선 | `claude-haiku` |
| Orchestrator를 Claude로 통일 | `claude-opus-4-6` |
| Code 모드에서 GPT 계열 선호 | `gpt-5.4-high` |

---

## 참고 사항

- 프록시는 외부 의존성 없이 Node.js 기본 모듈(`http`)만 사용합니다.
- API Key 필드에 `sk-dummy`를 입력하는 이유: Roo Code가 빈 키를 허용하지 않으므로 아무 값이나 넣습니다. 실제 인증은 프록시가 처리합니다.
- `~/.kims-ai-proxy.env` 파일에는 비밀번호가 평문으로 저장됩니다. 파일 권한(`600`)을 유지하고 공유 계정에서는 사용에 주의하세요.
- 토큰 갱신 중 동시에 여러 요청이 들어오면, 첫 번째 요청만 재로그인을 수행하고 나머지는 갱신 완료 후 자동으로 재개됩니다.
