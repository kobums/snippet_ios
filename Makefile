.PHONY: beta ship release promo

# TestFlight 업로드 (빌드 번호 bump 없음)
beta:
	fastlane beta

# 빌드 번호 자동 증가 + TestFlight 업로드
ship:
	fastlane ship

# patch 버전 bump + App Store 업로드 (심사 제출은 App Store Connect에서 수동)
release:
	fastlane release

# 프로모션 텍스트만 업데이트 (빌드/심사 없이 즉시 반영)
promo:
	fastlane promo
