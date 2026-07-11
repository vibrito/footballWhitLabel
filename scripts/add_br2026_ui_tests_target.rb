require 'xcodeproj'

project_path = File.expand_path('../BR2026.xcodeproj', __dir__)
root = File.dirname(project_path)
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'BR2026' } or raise 'BR2026 target not found'
ui_test_target = project.targets.find { |t| t.name == 'BR2026UITests' }

if ui_test_target.nil?
  ui_test_target = project.new_target(:ui_test_bundle, 'BR2026UITests', :ios, '26.0', nil, :swift)
  ui_test_target.add_dependency(app_target)

  ui_test_target.build_configurations.each do |config|
    config.build_settings['TEST_TARGET_NAME'] = 'BR2026'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.vibrito.BR2026UITests'
    config.build_settings['SWIFT_VERSION'] = '6.0'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['DEVELOPMENT_TEAM'] = app_target.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
  end

  scheme_path = Xcodeproj::XCScheme.shared_data_dir(project_path) + 'BR2026.xcscheme'
  scheme = Xcodeproj::XCScheme.new(scheme_path)
  scheme.add_test_target(ui_test_target)
  scheme.save!

  puts "Created BR2026UITests target and wired it into the BR2026 scheme"
end

group = project.main_group['BR2026UITests'] || project.main_group.new_group('BR2026UITests', 'BR2026UITests')
existing_paths = ui_test_target.source_build_phase.files_references.map { |f| f.real_path.to_s }

Dir.glob(File.join(root, 'BR2026UITests', '**', '*.swift')).sort.each do |path|
  next if existing_paths.include?(path)
  file_ref = group.new_reference(path)
  ui_test_target.add_file_references([file_ref])
  puts "Added #{File.basename(path)} to BR2026UITests"
end

project.save
