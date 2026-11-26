import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

String? findIsarCoreLibrary() {
  final override = Platform.environment['ISAR_CORE_LIB'];
  if (override != null && File(override).existsSync()) return override;

  final libraryPath = switch (Abi.current()) {
    Abi.linuxX64 || Abi.linuxArm || Abi.linuxArm64 => 'linux/libisar.so',
    Abi.macosX64 || Abi.macosArm64 => 'macos/libisar.dylib',
    Abi.windowsX64 => 'windows/libisar.dll',
    _ => null,
  };
  if (libraryPath == null) return null;

  // flutter test does not support Isolate.resolvePackageUriSync. Use pub's
  // package config so other cached versions cannot affect which core is loaded.
  final packageConfig = File('.dart_tool/package_config.json').absolute;
  if (!packageConfig.existsSync()) return null;

  final config =
      jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'];
  if (packages is! List) return null;
  for (final package in packages) {
    if (package is! Map<String, dynamic> ||
        package['name'] != 'isar_community_flutter_libs') {
      continue;
    }
    final rootUri = package['rootUri'];
    if (rootUri is! String) return null;
    final root = Directory.fromUri(packageConfig.uri.resolve(rootUri));
    final library = File.fromUri(root.uri.resolve(libraryPath));
    return library.existsSync() ? library.path : null;
  }
  return null;
}
