require 'xcodeproj'

PROJECT_PATH = 'Halo.xcodeproj'
project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == 'Halo' } or abort 'Halo target not found'

# ---- Source files ---------------------------------------------------------
halo = project.main_group.children.find { |g| g.respond_to?(:display_name) && g.display_name == 'Halo' } or abort 'Halo group not found'
core = halo.children.find { |g| g.respond_to?(:display_name) && g.display_name == 'Core' } or abort 'Core group not found'
views = halo.children.find { |g| g.respond_to?(:display_name) && g.display_name == 'Views' } or abort 'Views group not found'

def ensure_source(project, target, group, filename)
  ref = group.files.find { |f| f.path == filename || f.display_name == filename }
  ref ||= group.new_reference(filename)
  unless target.source_build_phase.files.any? { |bf| bf.file_ref == ref }
    bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    bf.file_ref = ref
    target.source_build_phase.files << bf
  end
end

ensure_source(project, target, core, 'AccountLicenseManager.swift')
ensure_source(project, target, views, 'AccountLicenseSettingsView.swift')

# ---- Swift packages ------------------------------------------------------
def ensure_package(project, target, url, version, products)
  root = project.root_object
  package = root.package_references.find { |p| p.repositoryURL == url }
  unless package
    package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package.repositoryURL = url
    package.requirement = { 'kind' => 'exactVersion', 'version' => version }
    root.package_references << package
  end

  products.each do |product_name|
    dependency = target.package_product_dependencies.find { |d| d.product_name == product_name }
    unless dependency
      dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
      dependency.package = package
      dependency.product_name = product_name
      target.package_product_dependencies << dependency
    end
    unless target.frameworks_build_phase.files.any? { |bf| bf.product_ref == dependency }
      build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
      build_file.product_ref = dependency
      target.frameworks_build_phase.files << build_file
    end
  end
end

ensure_package(project, target,
  'https://github.com/licenseseat/licenseseat-swift.git',
  '0.4.2', ['LicenseSeat'])
ensure_package(project, target,
  'https://github.com/firebase/firebase-ios-sdk.git',
  '12.11.0', ['FirebaseCore', 'FirebaseAuth'])

# Keep credentials out of source control. Developers can set these build settings
# locally/through CI; Info.plist only receives their substituted values.
target.build_configurations.each do |config|
  config.build_settings['HALO_LICENSESEAT_API_KEY'] ||= ''
  config.build_settings['HALO_LICENSESEAT_PRODUCT_SLUG'] ||= ''
end

project.save

# ---- Runtime startup -----------------------------------------------------
app_path = 'Halo/App/HaloApp.swift'
app = File.read(app_path)
needle = "        store.workspace.start()\n"
replacement = "        store.workspace.start()\n        HaloAccountLicenseManager.shared.start()\n"
unless app.include?('HaloAccountLicenseManager.shared.start()')
  abort 'workspace start anchor not found' unless app.include?(needle)
  app.sub!(needle, replacement)
  File.write(app_path, app)
end

# ---- Settings ------------------------------------------------------------
settings_path = 'Halo/Views/WorkspaceSettingsView.swift'
settings = File.read(settings_path)
settings.sub!(
  'private let sections = ["General", "Appearance",',
  'private let sections = ["General", "Account", "Appearance",'
) unless settings.include?('"General", "Account", "Appearance"')
settings.sub!(
  '        case "General": return "gearshape"\n',
  '        case "General": return "gearshape"\n        case "Account": return "person.crop.circle.badge.checkmark"\n'
) unless settings.include?('case "Account": return')
settings.sub!(
  '        case "Schedules": ScheduleSettingsView(workspace: workspace)\n',
  '        case "Account": AccountLicenseSettingsView()\n        case "Schedules": ScheduleSettingsView(workspace: workspace)\n'
) unless settings.include?('case "Account": AccountLicenseSettingsView()')
File.write(settings_path, settings)

# ---- Plists --------------------------------------------------------------
def plist_set(path, key, type, value)
  buddy = '/usr/libexec/PlistBuddy'
  exists = system(buddy, '-c', "Print :#{key}", path, out: File::NULL, err: File::NULL)
  command = exists ? "Set :#{key} #{value}" : "Add :#{key} #{type} #{value}"
  abort "Failed to set #{key} in #{path}" unless system(buddy, '-c', command, path)
end

plist_set('Halo/Info.plist', 'HaloLicenseSeatAPIKey', 'string', '$(HALO_LICENSESEAT_API_KEY)')
plist_set('Halo/Info.plist', 'HaloLicenseSeatProductSlug', 'string', '$(HALO_LICENSESEAT_PRODUCT_SLUG)')
plist_set('Halo/Info.plist', 'FirebaseAppDelegateProxyEnabled', 'bool', 'false')

entitlements = 'Halo/Halo.entitlements'
buddy = '/usr/libexec/PlistBuddy'
unless system(buddy, '-c', 'Print :keychain-access-groups', entitlements, out: File::NULL, err: File::NULL)
  abort 'Unable to add keychain-access-groups' unless system(buddy, '-c', 'Add :keychain-access-groups array', entitlements)
end
existing = `#{buddy} -c 'Print :keychain-access-groups' '#{entitlements}' 2>/dev/null`
unless existing.include?('$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)')
  index = existing.lines.count { |line| line.strip.start_with?('$(') }
  abort 'Unable to add Firebase keychain group' unless system(buddy, '-c', "Add :keychain-access-groups:#{index} string $(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)", entitlements)
end

puts 'Firebase account + LicenseSeat integration applied'
