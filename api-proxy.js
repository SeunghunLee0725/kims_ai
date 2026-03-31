const http = require("http");

const TARGET = "http://openchat.kims.re.kr";
const PORT = parseInt(process.env.PROXY_PORT, 10) || 4000;

const USER_EMAIL = process.env.KIMS_EMAIL || "";
const USER_PASS = process.env.KIMS_PASSWORD || "";

// 현재 유효한 API 토큰 (런타임 중 갱신됨)
let currentToken = process.env.KIMS_API_KEY || "";
let isRefreshing = false;
let refreshQueue = []; // 토큰 갱신 중 대기 중인 요청 콜백

// ── 시작 시 토큰 유효성 검사 ──────────────────────────────────────────────────
if (!currentToken && !USER_EMAIL) {
  console.error(
    "[오류] 인증 정보가 설정되지 않았습니다.\n" +
      "  방법 1) 이메일/비밀번호 환경변수 설정 (자동 토큰 갱신 지원):\n" +
      "    export KIMS_EMAIL='your@email.com'\n" +
      "    export KIMS_PASSWORD='yourpassword'\n" +
      "  방법 2) API 토큰 직접 설정 (만료 시 수동 갱신 필요):\n" +
      "    export KIMS_API_KEY='eyJ...'\n"
  );
  process.exit(1);
}

// ── 로그인하여 토큰 발급 ──────────────────────────────────────────────────────
function login() {
  return new Promise((resolve, reject) => {
    if (!USER_EMAIL || !USER_PASS) {
      return reject(new Error("이메일/비밀번호 환경변수가 설정되지 않았습니다."));
    }

    const body = Buffer.from(
      JSON.stringify({ email: USER_EMAIL, password: USER_PASS })
    );

    const options = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": body.length,
        host: "openchat.kims.re.kr",
      },
    };

    const req = http.request(
      TARGET + "/api/v1/auths/signin",
      options,
      (res) => {
        let data = [];
        res.on("data", (chunk) => data.push(chunk));
        res.on("end", () => {
          try {
            const json = JSON.parse(Buffer.concat(data).toString());

            // 1) 전용 API 키 조회 시도
            if (json.token) {
              fetchApiKey(json.token).then(resolve).catch(() => {
                // API 키 조회 실패 시 로그인 토큰 사용
                resolve(json.token);
              });
            } else {
              reject(new Error("로그인 응답에 token이 없습니다: " + JSON.stringify(json)));
            }
          } catch (e) {
            reject(new Error("로그인 응답 파싱 실패: " + e.message));
          }
        });
      }
    );

    req.on("error", (e) => reject(new Error("로그인 요청 실패: " + e.message)));
    req.write(body);
    req.end();
  });
}

// ── 전용 API 키 조회 ──────────────────────────────────────────────────────────
function fetchApiKey(loginToken) {
  return new Promise((resolve, reject) => {
    const options = {
      method: "GET",
      headers: {
        Authorization: "Bearer " + loginToken,
        host: "openchat.kims.re.kr",
      },
    };

    const req = http.request(
      TARGET + "/api/v1/auths/api_key",
      options,
      (res) => {
        let data = [];
        res.on("data", (chunk) => data.push(chunk));
        res.on("end", () => {
          try {
            const json = JSON.parse(Buffer.concat(data).toString());
            if (json.api_key && json.api_key !== "null") {
              resolve(json.api_key);
            } else {
              // 전용 API 키 없음 → 로그인 토큰 사용
              resolve(loginToken);
            }
          } catch (e) {
            resolve(loginToken); // 파싱 실패 시 로그인 토큰 사용
          }
        });
      }
    );

    req.on("error", () => resolve(loginToken));
    req.end();
  });
}

// ── 토큰 갱신 (중복 갱신 방지: 큐 방식) ─────────────────────────────────────
function refreshToken() {
  if (isRefreshing) {
    // 이미 갱신 중이면 완료될 때까지 대기
    return new Promise((resolve, reject) => {
      refreshQueue.push({ resolve, reject });
    });
  }

  isRefreshing = true;
  console.log("[토큰] 토큰 만료 감지 — 자동 재로그인 중...");

  return login()
    .then((newToken) => {
      currentToken = newToken;
      isRefreshing = false;
      console.log("[토큰] 토큰 갱신 완료");

      // 대기 중인 요청들 모두 재개
      refreshQueue.forEach((cb) => cb.resolve(newToken));
      refreshQueue = [];
      return newToken;
    })
    .catch((err) => {
      isRefreshing = false;
      console.error("[토큰] 토큰 갱신 실패:", err.message);

      refreshQueue.forEach((cb) => cb.reject(err));
      refreshQueue = [];
      throw err;
    });
}

// ── 프록시 요청 처리 ──────────────────────────────────────────────────────────
function proxyRequest(req, res, data, token, isRetry) {
  const headers = { ...req.headers };
  headers["authorization"] = "Bearer " + token;
  headers["host"] = "openchat.kims.re.kr";
  delete headers["content-length"];

  const options = {
    method: req.method,
    headers: { ...headers, "content-length": data.length },
  };

  const proxy = http.request(TARGET + req.url, options, (proxyRes) => {
    // 401 감지: 토큰 만료 → 자동 갱신 후 1회 재시도
    if (proxyRes.statusCode === 401 && !isRetry) {
      // 응답 본문을 소비해야 소켓이 재사용됨
      proxyRes.resume();

      if (!USER_EMAIL) {
        console.error(
          "[오류] 401 Unauthorized — 토큰이 만료되었습니다.\n" +
            "  자동 갱신을 사용하려면 KIMS_EMAIL / KIMS_PASSWORD 환경변수를 설정하세요."
        );
        res.writeHead(401);
        res.end(
          JSON.stringify({
            error: "Token expired. Set KIMS_EMAIL and KIMS_PASSWORD for auto-refresh.",
          })
        );
        return;
      }

      refreshToken()
        .then((newToken) => {
          proxyRequest(req, res, data, newToken, true /* isRetry */);
        })
        .catch((err) => {
          res.writeHead(502);
          res.end("Token refresh failed: " + err.message);
        });
      return;
    }

    // 4xx/5xx 에러 응답 본문을 로그에 출력
    if (proxyRes.statusCode >= 400) {
      let errChunks = [];
      proxyRes.on("data", (chunk) => errChunks.push(chunk));
      proxyRes.on("end", () => {
        const errBody = Buffer.concat(errChunks).toString();
        console.error(`[오류] HTTP ${proxyRes.statusCode} — ${req.method} ${req.url}`);
        try {
          const parsed = JSON.parse(errBody);
          const msg = (parsed.error && parsed.error.message) || JSON.stringify(parsed);
          console.error(`[오류] 원인: ${msg.slice(0, 300)}`);
        } catch (_) {
          console.error(`[오류] 응답: ${errBody.slice(0, 300)}`);
        }
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        res.end(errBody);
      });
      return;
    }

    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });

  proxy.on("error", (e) => {
    console.error(`[프록시 오류] ${e.message}`);
    res.writeHead(502);
    res.end("Proxy error: " + e.message);
  });

  proxy.write(data);
  proxy.end();
}

// ── HTTP 서버 ─────────────────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  let body = [];
  req.on("data", (chunk) => body.push(chunk));
  req.on("end", () => {
    let data = Buffer.concat(body);

    // 요청 본문을 파싱하여 모델별 호환성 문제 자동 수정
    if (
      req.method === "POST" &&
      req.url.includes("/chat/completions") &&
      data.length > 0
    ) {
      try {
        const json = JSON.parse(data.toString());
        const model = (json.model || "").toLowerCase();

        const isClaude = model.includes("claude");
        const isGpt54 = model.startsWith("gpt-5.4");
        // gpt-5.4-none 은 reasoning_effort=none 이므로 top_p/temperature 제약 없음
        const isGpt54Reasoning = isGpt54 && !model.endsWith("-none");
        const isPerplexity = model.includes("perplexity");

        // ── Claude 계열 ──────────────────────────────────────────────────────
        // - temperature 와 top_p 를 동시에 보낼 수 없음 → top_p 제거
        // - frequency_penalty, presence_penalty 미지원 → 제거
        if (isClaude) {
          if (json.top_p !== undefined) {
            delete json.top_p;
          }
          delete json.frequency_penalty;
          delete json.presence_penalty;
        }

        // ── GPT-5.4 계열 (reasoning 모델: xhigh/high/medium/low) ────────────
        // - temperature=0 또는 0.01 불가, 오직 1만 허용
        // - top_p 미지원 → 제거
        // - frequency_penalty, presence_penalty 미지원 → 제거
        // - stream_options 미지원 → 제거
        if (isGpt54Reasoning) {
          if (json.temperature !== undefined) {
            json.temperature = 1;
          }
          delete json.top_p;
          delete json.frequency_penalty;
          delete json.presence_penalty;
          delete json.stream_options;
        }

        // ── GPT-5.4-none (reasoning_effort=none) ────────────────────────────
        // - frequency_penalty, presence_penalty 미지원 → 제거
        // - stream_options 미지원 → 제거
        if (isGpt54 && !isGpt54Reasoning) {
          delete json.frequency_penalty;
          delete json.presence_penalty;
          delete json.stream_options;
        }

        // ── Perplexity 계열 ──────────────────────────────────────────────────
        // - 현재 테스트 결과 top_p, frequency_penalty, presence_penalty 모두 허용됨
        // - stream_options 허용됨
        // (추가 제거 불필요)

        const removed = [];
        // 로그용: 변경된 파라미터 추적은 위에서 직접 처리

        data = Buffer.from(JSON.stringify(json));

        const flags = [];
        if (isClaude) flags.push("claude");
        else if (isGpt54Reasoning) flags.push("gpt-5.4-reasoning");
        else if (isGpt54) flags.push("gpt-5.4-none");
        else if (isPerplexity) flags.push("perplexity");
        console.log(`[요청] 모델: ${json.model} [${flags.join(",") || "기타"}]`);
      } catch (e) {
        // JSON 파싱 실패 시 원본 그대로 전달
        console.error(`[경고] 요청 본문 파싱 실패: ${e.message}`);
      }
    }

    proxyRequest(req, res, data, currentToken, false);
  });
});

// ── 시작 ──────────────────────────────────────────────────────────────────────
function start() {
  const doListen = () => {
    server.listen(PORT, () => {
      console.log(`[KIMS AI 프록시] http://localhost:${PORT} 에서 실행 중`);
      console.log(`[KIMS AI 프록시] ${TARGET} 로 요청 전달 (인증 헤더 자동 추가)`);
      if (USER_EMAIL) {
        console.log(`[KIMS AI 프록시] 자동 토큰 갱신 활성화 (계정: ${USER_EMAIL})`);
      }
    });
  };

  // 이메일/비밀번호가 있으면 시작 시 토큰 발급
  if (USER_EMAIL && USER_PASS && !currentToken) {
    console.log("[토큰] 시작 시 토큰 발급 중...");
    login()
      .then((token) => {
        currentToken = token;
        console.log("[토큰] 토큰 발급 완료");
        doListen();
      })
      .catch((err) => {
        console.error("[오류] 초기 토큰 발급 실패:", err.message);
        console.error("  이메일/비밀번호를 확인하거나 KIMS_API_KEY를 직접 설정하세요.");
        process.exit(1);
      });
  } else {
    doListen();
  }
}

start();
