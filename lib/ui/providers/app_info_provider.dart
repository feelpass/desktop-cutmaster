import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 런타임에 OS native channel(macOS Info.plist / Windows resource)에서
/// pubspec.yaml의 version을 읽어온다. 단축키 치트시트 외에도 향후 About
/// 다이얼로그, export 메타데이터 등 어디서든 `ref.watch`로 사용한다.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// "0.1.0+1" 형태 — pubspec.yaml의 version 필드와 동일.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await ref.watch(packageInfoProvider.future);
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version}+${info.buildNumber}';
});
