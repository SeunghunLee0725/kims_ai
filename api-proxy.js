const http = require("http");

const TARGET = "http://openchat.kims.re.kr";
const API_KEY =
  process.env.KIMS_API_KEY ||
  "여기에_API_토큰을_붙여넣으세요";
const PORT = parseInt(process.env.PROXY_PORT, 10) || 4000;

if (
  API_KEY === "여기에_API_토큰을_붙여넣으세요" &&
  !process.env.KIMS_API_KEY
) {
  console.error(
    "[오류] API 토큰이 설정되지 않았습니다.\n" +
      "  방법 1) 환경변수 설정: export KIMS_API_KEY='eyJ...'\n" +
      "  방법 2) 이 파일의 API_KEY 값을 직접 수정\n"
  );
  process.exit(1);
}

const server = http.createServer((req, res) => {
  let body = [];
  req.on("data", (chunk) => body.push(chunk));
  req.on("end", () => {
    const data = Buffer.concat(body);
    const url = TARGET + req.url;

    const headers = { ...req.headers };
    headers["authorization"] = "Bearer " + API_KEY;
    headers["host"] = "openchat.kims.re.kr";
    delete headers["content-length"];

    const options = {
      method: req.method,
      headers: { ...headers, "content-length": data.length },
    };

    const proxy = http.request(url, options, (proxyRes) => {
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
  });
});

server.listen(PORT, () => {
  console.log(`[KIMS AI 프록시] http://localhost:${PORT} 에서 실행 중`);
  console.log(`[KIMS AI 프록시] ${TARGET} 로 요청 전달 (인증 헤더 자동 추가)`);
});
