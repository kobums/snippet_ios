# DuoDriver.xcodeproj 생성기 — UI 테스트 파일을 추가·삭제했을 때만 다시 돌린다 (생성된 프로젝트는 커밋돼 있음).
#   GEM_PATH="$(brew --prefix fastlane)/libexec" "$(brew --prefix ruby)/bin/ruby" tools/duo-sim/driver/gen.rb
# (xcodeproj gem이 따로 설치돼 있으면 그냥 `ruby gen.rb`)
require 'fileutils'
require 'xcodeproj'

root = File.expand_path(__dir__)
path = File.join(root, 'DuoDriver.xcodeproj')
FileUtils.rm_rf(path)
proj = Xcodeproj::Project.new(path)

# UI 테스트 번들은 대상 앱이 필요해서 빈 호스트 앱을 둔다. 실제 대상은 번들 ID로 띄우는 Snippet.
app = proj.new_target(:application, 'DuoHost', :ios, '26.0', nil, :swift)
ui = proj.new_target(:ui_test_bundle, 'DuoUITests', :ios, '26.0', nil, :swift)
ui.add_dependency(app)

g_app = proj.main_group.new_group('DuoHost', 'DuoHost')
g_ui = proj.main_group.new_group('DuoUITests', 'DuoUITests')
app.add_file_references([g_app.new_file('DuoHostApp.swift')])
Dir[File.join(root, 'DuoUITests', '*.swift')].sort.each { |f| ui.add_file_references([g_ui.new_file(File.basename(f))]) }

[app, ui].each do |t|
  t.build_configurations.each do |c|
    s = c.build_settings
    s['SWIFT_VERSION'] = '5.0'
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['CODE_SIGN_STYLE'] = 'Manual'
    s['CODE_SIGN_IDENTITY'] = '-'   # 시뮬레이터 전용 — 팀·프로비저닝 불필요
    s['DEVELOPMENT_TEAM'] = ''
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
  end
end
app.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.gowoobro.snippet.duohost'
  c.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
end
ui.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.gowoobro.snippet.duouitests'
  c.build_settings['TEST_TARGET_NAME'] = 'DuoHost'
end
proj.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(ui)
scheme.set_launch_target(app)
scheme.save_as(path, 'DuoDriver', true)
puts "generated #{path}"
