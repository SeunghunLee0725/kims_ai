const http = require("http");

const TARGET = "http://openchat.kims.re.kr";
const KIMS_EMAIL = process.env.KIMS_EMAIL;
const KIMS_PASSWORD = process.env.KIMS_PASSWORD;
const STATIC_API_KEY = process.env.KIMS_API_KEY;
const PORT = parseInt(process.env.PROXY_PORT, 10) || 4000;

let currentToken = STATIC_API_KEY || null;

// 로그인하여 토큰 발급
function fetchToken() {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      email: KIMS_EMAIL,
      password: KIMS_PASSWORD,
    });
    const req = http.request(
      TARGET + "/api/v1/auths/signin",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          host: "openchat.kims.re.kr",
          "content-length": Buffer.byteLength(payload),
        },
      },
      (res) => {
        let body = [];
        res.on("data", (chunk) => body.push(chunk));
        res.on("end", () => {
          try {
            const json = JSON.parse(Buffer.concat(body).toString());
            if (json.token) {
              currentToken = json.token;
              console.log("[인증] 토큰 발급 성공");
              resolve(json.token);
            } else {
              reject(new Error(json.detail || "토큰 발급 실패"));
            }
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

// 인증 설정 확인
if (!STATIC_API_KEY && (!KIMS_EMAIL || !KIMS_PASSWORD)) {
  console.error(
    "[오류] 인증 정보가 설정되지 않았습니다.\n" +
      "  방법 1) 이메일/비밀번호: export KIMS_EMAIL='...' KIMS_PASSWORD='...'\n" +
      "  방법 2) API 키 직접 설정: export KIMS_API_KEY='eyJ...'\n"
  );
  process.exit(1);
}

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

        // GPT-5.4, Perplexity 등 temperature=0을 지원하지 않는 모델 처리
        if (!model.includes("claude")) {
          if (json.temperature === 0) {
            json.temperature = 0.01;
          }
          // stream_options 미지원 모델 처리
          if (json.stream_options) {
            delete json.stream_options;
          }
        }

        // 일부 모델에서 지원하지 않는 파라미터 제거
        if (model.includes("perplexity")) {
          delete json.top_p;
          delete json.frequency_penalty;
          delete json.presence_penalty;
        }

        data = Buffer.from(JSON.stringify(json));
        console.log(`[요청] 모델: ${json.model}`);
      } catch (e) {
        // JSON 파싱 실패 시 원본 그대로 전달
      }
    }

    const url = TARGET + req.url;

    function doProxy() {
      const headers = { ...req.headers };
      headers["authorization"] = "Bearer " + currentToken;
      headers["host"] = "openchat.kims.re.kr";
      delete headers["content-length"];

      const options = {
        method: req.method,
        headers: { ...headers, "content-length": data.length },
      };

      const proxy = http.request(url, options, (proxyRes) => {
        // 401이고 이메일/비밀번호가 있으면 토큰 재발급 후 재시도
        if (proxyRes.statusCode === 401 && KIMS_EMAIL && KIMS_PASSWORD) {
          // 응답 소비 후 재시도
          proxyRes.resume();
          console.log("[인증] 토큰 만료, 재발급 시도...");
          fetchToken()
            .then(() => doProxy())
            .catch((e) => {
              console.error(`[인증 오류] ${e.message}`);
              res.writeHead(401);
              res.end("Token refresh failed: " + e.message);
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

    doProxy();
  });
});

// 시작 시 토큰이 없으면 로그인하여 발급
(async () => {
  if (!currentToken && KIMS_EMAIL && KIMS_PASSWORD) {
    try {
      await fetchToken();
    } catch (e) {
      console.error(`[인증 오류] 초기 토큰 발급 실패: ${e.message}`);
      process.exit(1);
    }
  }
  server.listen(PORT, () => {
    console.log(`[KIMS AI 프록시] http://localhost:${PORT} 에서 실행 중`);
    console.log(`[KIMS AI 프록시] ${TARGET} 로 요청 전달 (인증 헤더 자동 추가)`);
  });
})();
