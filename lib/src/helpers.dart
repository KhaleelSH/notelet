import 'package:package_info_plus/package_info_plus.dart';

import 'types.dart';

/// The app's version name: `CFBundleShortVersionString` on iOS, `versionName`
/// on Android.
Future<String> getCurrentAppVersion() async {
  final version = (await PackageInfo.fromPlatform()).version;

  return version.isEmpty ? '0' : version;
}

List<NoteletVersionNoteItem> getVersionNotes(
  String version,
  List<NoteletVersionNotes> notes,
) {
  return notes.where((notes) => notes.version == version).firstOrNull?.items ??
      const [];
}
