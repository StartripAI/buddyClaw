#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'xcodeproj'

ROOT = Pathname(__dir__).join('..').expand_path
PROJECT_PATH = ROOT.join('BuddyClaw.xcodeproj')

TARGET_DEPLOYMENT = '14.0'
LAST_UPGRADE_CHECK = '2640'
CREATED_ON_TOOLS_VERSION = '26.4'

def ensure_file(group, path)
  group.find_file_by_path(path.to_s) || group.new_file(path.to_s)
end

def configure_app_target(target, xcconfig_ref)
  target.build_configuration_list.build_configurations.each do |config|
    config.base_configuration_reference = xcconfig_ref
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'YES'
    config.build_settings['CODE_SIGN_INJECT_BASE_ENTITLEMENTS'] = 'NO'
    config.build_settings['ENABLE_HARDENED_RUNTIME'] = config.name == 'Release' ? 'YES' : 'NO'
    config.build_settings['PRODUCT_NAME'] = 'BuddyClaw'
    config.build_settings['SDKROOT'] = 'macosx'
    config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
  end
end

def configure_test_target(target)
  target.build_configuration_list.build_configurations.each do |config|
    config.build_settings['BUNDLE_LOADER'] = ''
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['DEFINES_MODULE'] = 'YES'
    config.build_settings['ENABLE_TESTABILITY'] = 'YES'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = [
      '$(inherited)',
      '@loader_path/Frameworks',
      '@loader_path/../Frameworks',
    ]
    config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = TARGET_DEPLOYMENT
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.alfred.buddyclaw.tests'
    config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    config.build_settings['SDKROOT'] = 'macosx'
    config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
    config.build_settings['SWIFT_VERSION'] = '5.9'
    config.build_settings['TEST_HOST'] = ''
  end
end

def add_local_package_dependency(project, target, package_ref, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.package = package_ref
  dependency.product_name = product_name
  target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

def write_scheme(project_path, scheme_name, runnable_target, test_target)
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(runnable_target, test_target, launch_target: true)
  scheme.launch_action.build_configuration = 'Debug'
  scheme.test_action.build_configuration = 'Debug'
  scheme.profile_action.build_configuration = 'Release'
  scheme.analyze_action.build_configuration = 'Debug'
  scheme.archive_action.build_configuration = 'Release'

  shared_dir = Xcodeproj::XCScheme.shared_data_dir(project_path)
  FileUtils.mkdir_p(shared_dir)
  scheme.save_as(project_path, scheme_name, true)
end

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes['BuildIndependentTargetsInParallel'] = '1'
project.root_object.attributes['LastUpgradeCheck'] = LAST_UPGRADE_CHECK
project.root_object.attributes['TargetAttributes'] = {}
project.root_object.compatibility_version = 'Xcode 15.0'
project.root_object.development_region = 'en'
project.root_object.known_regions = %w[en Base]

main_group = project.main_group
sources_group = main_group.find_subpath('Sources', true)
cli_group = sources_group.find_subpath('BuddyClawCLI', true)
tests_group = main_group.find_subpath('Tests/DesktopBuddyTests', true)
support_group = main_group.find_subpath('Support', true)
config_group = main_group.find_subpath('Config', true)
scripts_group = main_group.find_subpath('scripts', true)

cli_entry = ensure_file(cli_group, ROOT.join('Sources/BuddyClawCLI/BuddyClawCLIEntry.swift').relative_path_from(ROOT))
test_refs = Dir.glob(ROOT.join('Tests/DesktopBuddyTests/*.swift').to_s).sort.map do |file|
  ensure_file(tests_group, Pathname(file).relative_path_from(ROOT))
end
[
  'Support/BuddyClaw-Info.plist',
  'Support/BuddyClawAppStore.entitlements',
  'Support/PrivacyInfo.xcprivacy',
  'Support/Assets.xcassets',
  'Config/Common.xcconfig',
  'Config/BuddyClawDirect.xcconfig',
  'Config/BuddyClawAppStore.xcconfig',
  'scripts/release_buddyclaw.sh',
  'scripts/archive_app_store.sh',
  'Package.swift',
].each do |path|
  group =
    case path
    when /\AConfig\// then config_group
    when /\ASupport\// then support_group
    when /\Ascripts\// then scripts_group
    else main_group
    end
  ensure_file(group, path)
end

assets_ref = ensure_file(support_group, 'Support/Assets.xcassets')
privacy_ref = ensure_file(support_group, 'Support/PrivacyInfo.xcprivacy')
direct_xcconfig_ref = ensure_file(config_group, 'Config/BuddyClawDirect.xcconfig')
app_store_xcconfig_ref = ensure_file(config_group, 'Config/BuddyClawAppStore.xcconfig')

direct_target = project.new_target(:application, 'BuddyClawDirect', :osx, TARGET_DEPLOYMENT)
app_store_target = project.new_target(:application, 'BuddyClawAppStore', :osx, TARGET_DEPLOYMENT)
test_target = project.new_target(:unit_test_bundle, 'DesktopBuddyTests', :osx, TARGET_DEPLOYMENT)

[direct_target, app_store_target].each do |target|
  target.add_file_references([cli_entry])
  target.add_resources([assets_ref, privacy_ref])
end
test_target.add_file_references(test_refs)

package_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package_ref.relative_path = '.'
project.root_object.package_references << package_ref

[direct_target, app_store_target, test_target].each do |target|
  add_local_package_dependency(project, target, package_ref, 'DesktopBuddy')
end

configure_app_target(direct_target, direct_xcconfig_ref)
configure_app_target(app_store_target, app_store_xcconfig_ref)
configure_test_target(test_target)

project.root_object.attributes['TargetAttributes'][direct_target.uuid] = {
  'CreatedOnToolsVersion' => CREATED_ON_TOOLS_VERSION,
}
project.root_object.attributes['TargetAttributes'][app_store_target.uuid] = {
  'CreatedOnToolsVersion' => CREATED_ON_TOOLS_VERSION,
}
project.root_object.attributes['TargetAttributes'][test_target.uuid] = {
  'CreatedOnToolsVersion' => CREATED_ON_TOOLS_VERSION,
}

project.sort
project.save

write_scheme(PROJECT_PATH, 'BuddyClawDirect', direct_target, test_target)
write_scheme(PROJECT_PATH, 'BuddyClawAppStore', app_store_target, test_target)
