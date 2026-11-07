# Duo 시뮬레이터 순회 도구

iPhone Duo 시뮬레이터에서 Snippet을 자세별로 돌며 화면마다 스크린샷과 접근성 트리를 남긴다.
레이아웃 수정 후 재검증, App Store Duo 스크린샷(2027년 4월부터 필수) 준비에 쓴다.

| 자세 (`-c`) | 화면 | 앱 창 (현재) |
|---|---|---|
| `outer` | 접은 상태, 바깥 화면 | 466×678pt, 탭바·상태바가 오른쪽 세로 바 |
| `inner_land` | 펼친 상태(기본), 안쪽 가로 | 469×669pt 세로 창 + 양옆 여백 (`UIRequiresFullScreen`) |
| `inner_port` | 펼친 상태, 안쪽 세로 | 669×951pt |
| `book` / `book_port` | 반쯤 접기(약 100°), 가로/세로 | 접힘 선이 화면 가운데 |
| `port` / `land` | Duo 아닌 기기(iPad 등)를 세로·가로로 돌려 순회 (`--device`와 함께) | |
| `first` | Duo 아닌 비교 기기용 — 첫 화면과 대시보드만 | |

## 실행

```bash
tools/duo-sim/run.sh                       # outer, inner_land, inner_port, book
tools/duo-sim/run.sh -c outer,inner_port   # 일부 자세만
tools/duo-sim/run.sh --ocr                 # OCR 밑줄이 접기·펴기·회전 후에도 같은 줄에 붙는지 (--ocr-only: 그것만)
tools/duo-sim/run.sh --skip-build          # 앱 재빌드·재설치 생략
```

결과는 `tools/duo-sim/out/<run>/`: 화면별 PNG(바깥 1398×2034, 안쪽 2853×2007·2007×2853 — App Store 규격과 같은 크기),
`tree/`(요소 프레임이 담긴 접근성 트리), `sheets/`(자세별 모아보기), `test.log`.

필요한 것: Xcode 27.1+와 iPhone Duo 시뮬레이터 런타임(iOS 27.1+), Docker Desktop, 로컬 `kobums/snippetback:latest` 이미지(`deploy.sh`로 빌드).

## 구성

- `duotool/` — 접기·펴기 제어. Xcode 27.2 시뮬레이터 앱에는 접기 메뉴가 없어서 Duo 런타임 SpringBoard의
  디스플레이 테스트 서비스(`SBSDisplayToolService`, 비공개 API)를 `xcrun simctl spawn`으로 부른다.
  엔타이틀먼트(`com.apple.springboard.sbdisplay.service`)는 코드서명이 아니라 `__TEXT` 섹션에 넣는다 — 코드서명에 넣으면 macOS가 실행을 막는다.
  비공개 API라 Xcode·런타임이 바뀌면 깨질 수 있다. 직접 쓸 때:
  `xcrun simctl spawn <기기> tools/duo-sim/build/duotool swap -position=open -duration=0 -deviceOrientation=portrait -wait`
- `driver/` — XCUITest 드라이버. 번들 ID로 Snippet을 띄워 탭·서브탭·시트·책 상세·타이머를 순회한다.
  테스트 파일을 추가·삭제하면 `driver/gen.rb`로 프로젝트를 다시 만든다.
- `scripts/watcher.sh` — 시뮬레이터 안 테스트 ↔ 맥 브리지. 테스트가 남긴 요청 파일을 보고 duotool·디스플레이별 캡처를 실행한다.
- `qa/` — 로컬 QA 백엔드(`backend.sh up|seed|down|reset`), 테스트 데이터(`seed.py`, `books.json`), 표지·OCR 페이지 이미지 생성기.

## 알아둘 것

- **기기 방향은 바깥 화면 기준이다.** `portrait`로 펼치면 안쪽 화면은 가로, `landscapeLeft`로 펼쳐야 세로.
  XCUIDevice 회전은 접기 직후의 테스트 잠금 때문에 먹지 않으므로 duotool의 `-deviceOrientation`을 쓴다.
- Debug 시뮬레이터 빌드는 `localhost:8008`에 붙는다. 운영 서버·실제 계정은 쓰지 않고, QA 계정
  (`qa@snippet.test`, 공개 문장 작성용 `writer@snippet.test`)과 DB·JWT 비밀값은 실행할 때 무작위로 만들어 `.qa.env`(gitignore)에만 둔다.
- 앱이 표지 URL을 https로 올리므로 표지 서버(`:8090`)는 QA 전용 CA로 서명하고, 그 CA를 해당 시뮬레이터 키체인에만 넣는다.
- 정리: `tools/duo-sim/qa/backend.sh down`(중지) 또는 `reset`(컨테이너·비밀값 삭제), `rm -rf tools/duo-sim/build tools/duo-sim/out`.
