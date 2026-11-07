# 시뮬레이터용 표지 이미지 HTTPS 서버 (127.0.0.1:8090). 앱이 표지 URL을 https로 올리므로 run.sh가 만든 QA 전용 CA로 서명한다.
import http.server, ssl, sys, functools
root, cert, key = sys.argv[1], sys.argv[2], sys.argv[3]
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 8090), handler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(cert, key)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
httpd.serve_forever()
