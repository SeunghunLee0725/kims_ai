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

### 2단계: 프록시 설치 (자동 로그인 & 토큰 발급 포함)

WSL2 터미널을 열고 다운받은 폴더로 이동해 다음을 실행합니다:

```bash
bash install.sh
```

설치 스크립트가 자동으로:
- Node.js 설치 여부를 확인하고
- `~/kims-ai-proxy/` 디렉토리를 생성하고
- **openchat.kims.re.kr에 로그인하여 API 토큰을 자동 발급**받고
- 프록시 스크립트에 토큰을 설정합니다

> **참고**: 로그인 시 이메일과 비밀번호를 입력하면 자동으로 토큰이 발급됩니다.
> 로그인이 안 되는 경우 웹 브라우저에서 수동으로 토큰을 발급받을 수 있습니다.

**수동 토큰 발급** (자동 로그인 실패 시):
1. 브라우저에서 **http://openchat.kims.re.kr/** 접속 후 로그인
2. 좌측 하단 **사용자 이름** 클릭
3. **설정(Settings)** 선택
4. **계정(Account)** 탭 → **API Keys**
5. **Create new secret key** 클릭
6. 생성된 토큰(`eyJ`로 시작하는 긴 문자열)을 복사

**수동 설치** (스크립트 없이 직접):
```bash
mkdir -p ~/kims-ai-proxy
cp api-proxy.js ~/kims-ai-proxy/
# api-proxy.js 내 API_KEY를 직접 수정하거나, 환경변수로 설정:
export KIMS_API_KEY='eyJ...(여기에 토큰 붙여넣기)'
```

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
[KIMS AI 프록시] http://localhost:4000 에서 실행 중
[KIMS AI 프록시] http://openchat.kims.re.kr 로 요청 전달 (인증 헤더 자동 추가)
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
[오류] API 토큰이 설정되지 않았습니다.
```
- API 토큰을 설정하세요:
  ```bash
  export KIMS_API_KEY='eyJ...'
  ```
- 또는 `~/kims-ai-proxy/api-proxy.js` 파일의 `API_KEY` 값을 직접 수정하세요.

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

- API 토큰이 만료되었을 수 있습니다.
- openchat.kims.re.kr에서 새 토큰을 발급받고 프록시를 재시작하세요:
  ```bash
  export KIMS_API_KEY='새_토큰'
  pkill -f "node.*api-proxy.js"
  ~/kims-ai-proxy/start-proxy.sh
  ```

### 502 Proxy Error

- 원내 네트워크에 연결되어 있는지 확인하세요.
- `curl http://openchat.kims.re.kr` 으로 서버 접근 가능 여부를 확인하세요.

### 포트 4000이 이미 사용 중

- 환경변수로 다른 포트를 지정할 수 있습니다:
  ```bash
  PROXY_PORT=4001 node ~/kims-ai-proxy/api-proxy.js
  ```
- Roo Code의 Base URL도 해당 포트로 변경하세요.

### 프록시 완전 종료

```bash
pkill -f "node.*api-proxy.js"
```

---

## 참고 사항

- 프록시는 외부 의존성 없이 Node.js 기본 모듈(`http`)만 사용합니다.
- API Key 필드에 `sk-dummy`를 입력하는 이유: Roo Code가 빈 키를 허용하지 않으므로 아무 값이나 넣습니다. 실제 인증은 프록시가 처리합니다.
- 프록시는 요청을 가공하지 않고 인증 헤더만 추가하여 그대로 전달합니다.
