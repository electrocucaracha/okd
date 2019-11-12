import http from "k6/http";
import { check, sleep } from "k6";
export let options = {
  hosts: {
    "www.non-qat-example.com": "127.0.0.1"
  },
  vus: 10,
  duration: "20s",
  insecureSkipTLSVerify: true,
  noConnectionReuse: true,
  noVUConnectionReuse: true,
  tlsCipherSuites: [
    "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
  ]
};
export default function() {
  let res = http.get("https://www.non-qat-example.com");
  check(res, {
    "status was 200": (r) => r.status == 200,
    "transaction time OK": (r) => r.timings.duration < 200
  });
};
