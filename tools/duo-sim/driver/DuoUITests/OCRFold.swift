import XCTest

/// OCR 밑줄이 접기·펴기·회전 후에도 같은 글줄에 붙어 있고, 그 줄이 그대로 인식되는지 확인한다.
/// run.sh가 테스트 페이지(qa/ocr_page.swift로 생성)를 사진 보관함 맨 앞에 넣어 둔다.
extension DuoTour {
    func testOCRFold() {
        Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
        app.launch(); pause(3)
        dismissSystemPrompts()
        loginIfNeeded()
        dismissSystemPrompts()   // 로그인 직후 "암호를 저장하겠습니까?" 시트가 탭을 가린다
        XCTAssertTrue(mainTab("독서기록").waitForExistence(timeout: 20), "탭이 안 보임")

        tap(mainTab("독서기록"), "tab 독서기록", wait: 2.5)
        tap(subTab("스니펫"), "sub 스니펫(기록)")
        guard tap(app.buttons["plus"].firstMatch, "records plus", wait: 2.5) else { return XCTFail("기록 추가 버튼 없음") }
        guard tap(app.buttons["카메라로 텍스트 추출"].firstMatch, "OCR 버튼", wait: 1.5) else { return XCTFail("OCR 버튼 없음") }
        guard tap(app.buttons["사진 선택"].firstMatch, "사진 선택", wait: 3) else { return XCTFail("사진 선택 없음") }
        capture("O_00_picker")

        // 사진 피커 그리드 첫 칸 = 가장 최근에 추가한 테스트 페이지
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 0)
        guard photo.waitForExistence(timeout: 10) else { return XCTFail("사진 피커 그리드 없음") }
        print("[duo] picking: \(photo.label)")
        photo.tap(); pause(1.5)
        let add = app.buttons["추가"].firstMatch
        if add.exists && add.isHittable { add.tap() }
        pause(3)
        capture("O_01_highlighter_outer_before")

        // 셋째 줄(이미지 높이의 약 39.5%) 위를 가로로 긋는다
        let bounds = app.windows.firstMatch.frame
        let page = app.images.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.width > 150 && bounds.contains($0.frame) }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        guard let img = page else { return XCTFail("밑줄 그을 이미지 없음") }
        print("[duo] page image frame: \(img.frame)")
        let from = img.coordinate(withNormalizedOffset: CGVector(dx: 0.07, dy: 0.395))
        let to = img.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.395))
        from.press(forDuration: 0.15, thenDragTo: to)
        pause(1.2)
        capture("O_02_underlined_outer")

        Host.swap("-position=open -duration=0 -deviceOrientation=portrait -wait", to: "LCD-1")
        pause(2.5)
        capture("O_03_underlined_inner_land")

        Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
        Host.swap("-position=open -duration=0 -deviceOrientation=landscapeLeft -wait", to: "LCD-1")
        pause(2.5)
        capture("O_04_underlined_inner_port")

        let run = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "OCR 실행")).firstMatch
        if tap(run, "OCR 실행", wait: 5) {
            capture("O_05_ocr_result_inner_port")
        } else {
            XCTFail("밑줄이 없어 OCR 실행 버튼이 안 보임")
        }

        // 정리: 결과 화면 취소 → 기록 추가 취소(+폐기 확인)
        closeSheet()
        closeSheet()
        let discard = app.buttons["내용 폐기"].firstMatch
        if discard.exists { discard.tap(); pause(1) }
        Host.swap("-position=closed -duration=0 -deviceOrientation=portrait -wait", to: "LCD")
    }
}
