# 로컬 QA 백엔드(localhost:8008)에 화면 점검용 테스트 데이터를 넣는다. 운영 서버와 무관.
# 문장은 저작권 문제가 없도록 직접 쓴 것. 표지 URL은 http로 넣고, 앱이 https로 올려 run.sh의 로컬 표지 서버(:8090)에서 받는다.
import json, os, sys, urllib.request, urllib.error

API = "http://localhost:8008/api"
COVER = "http://localhost:8090"

def call(method, path, token=None, body=None):
    req = urllib.request.Request(API + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data, timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> {e.code} {e.read()[:300]!r}")

def login(email, pw):
    return call("POST", "/auth/login", body={"email": email, "password": pw})["token"]

books = json.load(open(sys.argv[1]))
tok = {"qa": login("qa@snippet.test", os.environ["QA_PASSWORD"]),
       "writer": login("writer@snippet.test", os.environ["WRITER_PASSWORD"])}

existing = call("GET", "/userbooks?page=0&size=1", tok["qa"])
if isinstance(existing, dict):
    existing = existing.get("content", [])
if existing:
    print("already seeded")
    sys.exit(0)

ub = {}
for who, lst in books.items():
    for b in lst:
        body = {k: b.get(k) for k in ["title", "author", "publisher", "isbn", "totalPage", "type", "status", "startDate", "endDate"]}
        body["coverUrl"] = f"{COVER}/{b['isbn']}.png"
        body["pubDate"] = "2025-03-15"
        uid = call("POST", "/userbooks", tok[who], body)
        if b.get("readPage"):
            call("PATCH", f"/userbooks/{uid}", tok[who], {"readPage": b["readPage"]})
        dto = call("GET", f"/userbooks/{uid}", tok[who])
        ub[b["isbn"]] = {"userBookId": uid, "bookId": dto["bookId"], "who": who, "title": b["title"]}

# 다른 사용자(writer)의 공개 문장 → QA 계정의 스와이프 카드가 된다
lines = [
    "마음이 머무는 곳을 따라가다 보면, 결국 내가 어떤 사람인지 알게 된다.",
    "파도는 매번 같은 자리로 돌아오지만, 한 번도 같은 모양이었던 적은 없었다.",
    "누군가의 손을 잡는다는 건 그 사람의 온도를 기억하겠다는 약속이다.",
    "별은 멀리 있어서 아름다운 게 아니라, 오래 빛나서 아름다운 것이다.",
    "고양이는 질문하지 않는다. 다만 오래 바라볼 뿐이다. 어쩌면 그게 철학의 시작인지도 모른다.",
    "접힌 시간 안에는 펼쳐 보지 못한 하루들이 차곡차곡 쌓여 있었다.",
    "빈 의자는 누군가를 기다리는 게 아니라, 누군가가 있었다는 걸 기억하는 것이다.",
    "가장 긴 밤에도 창문 하나만큼의 빛은 남아 있었다. 우리는 그 빛으로 서로의 얼굴을 읽었다.",
    "말하지 않은 문장들이 우리 사이에 조용히 쌓여, 어느새 다리가 되어 있었다.",
    "길을 잃었다고 생각한 순간, 사실은 새로운 지도의 첫 줄을 그리고 있었다.",
    "천천히 읽는 사람만이 행간에 숨어 있는 계절을 발견한다.",
    "우리는 서로의 이야기를 끝까지 들어줄 단 한 사람이 필요했을 뿐이다. 그 한 사람이 되어 주는 일은 생각보다 어렵지 않았고, 생각보다 오래 걸렸다.",
]
writer_books = [v for v in ub.values() if v["who"] == "writer"]
for i, text in enumerate(lines):
    wb = writer_books[i % len(writer_books)]
    call("POST", "/records", tok["writer"], {"bookId": wb["bookId"], "type": "snippet", "text": text,
                                              "tag": ["위로", "사랑", "성장", "고독", "희망"][i % 5], "relatedPage": 20 + i * 17, "isPublic": True})

# QA 계정 자신의 기록 (스니펫/일기/리뷰)
qa_books = [v for v in ub.values() if v["who"] == "qa"]
recs = [
    ("snippet", "책장을 넘기는 소리가 빗소리와 닮아서, 오늘은 조금 더 오래 읽었다.", "위로", 45, True),
    ("snippet", "서점의 불빛은 늘 같은 시간에 켜졌고, 그 시간이 되면 나는 늘 같은 질문을 떠올렸다.", "고독", 88, False),
    ("diary", "출근길 지하철에서 30쪽. 주인공이 편지를 쓰는 장면에서 멈췄다. 나도 누군가에게 편지를 써 본 지 오래됐다.", None, 120, None),
    ("review", "잔잔하지만 오래 남는 이야기. 마지막 장의 문장 하나 때문에 다시 처음부터 읽고 싶어졌다. 별 다섯 개.", None, None, None),
    ("snippet", "수학은 숲을 세는 방법이 아니라, 숲을 바라보는 방법이었다.", "성장", 201, True),
    ("diary", "새벽에 깨서 한 챕터. 도서관 장면 묘사가 너무 좋아서 밑줄을 세 번이나 그었다.", None, 64, None),
    ("review", "물리학 책인데 이상하게 시집처럼 읽혔다. 어려운 개념을 일상의 언어로 풀어내는 솜씨가 좋다.", None, None, None),
    ("snippet", "아주 긴 문장을 테스트하기 위한 기록입니다. 화면 폭이 넓어지면 이 문장이 몇 줄로 보이는지, 카드가 너무 넓게 늘어나지는 않는지, 줄 간격과 여백이 자연스러운지 확인하려고 일부러 길게 적었습니다.", "희망", 150, False),
]
for i, (t, text, tag, page, public) in enumerate(recs):
    b = qa_books[i % 5]
    body = {"bookId": b["bookId"], "type": t, "text": text}
    if tag: body["tag"] = tag
    if page: body["relatedPage"] = page
    if public is not None: body["isPublic"] = public
    call("POST", "/records", tok["qa"], body)

# 독서 세션 — 스트릭·캘린더·통계용 (읽는 중인 책 위주, 최근 3주)
reading = [v for v in qa_books if v["title"] in ("바람이 머무는 서점", "우리가 잠시 빛났던 계절에 관한 아주 긴 제목의 에세이")]
dates = ["2026-10-19", "2026-10-21", "2026-10-24", "2026-10-26", "2026-10-29", "2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"]
page = {reading[0]["userBookId"]: 100, reading[1]["userBookId"]: 40}
for i, d in enumerate(dates):
    r = reading[i % 2]
    sp = page[r["userBookId"]]; ep = sp + 8 + (i % 3) * 4
    call("POST", "/readingsessions", tok["qa"], {"userBookId": r["userBookId"], "durationSeconds": 900 + i * 240,
                                                 "startPage": sp, "endPage": ep, "sessionDate": d})
    page[r["userBookId"]] = ep

call("PUT", "/readinggoals", tok["qa"], {"year": 2026, "targetBooks": 24})
print("seeded:", len(ub), "library rows,", len(lines), "public writer snippets,", len(recs), "qa records,", len(dates), "sessions")
