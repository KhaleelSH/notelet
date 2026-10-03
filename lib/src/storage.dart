import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Persists the app version whose release notes the user last saw.
///
/// By default this uses the platform's standard preferences (`UserDefaults` on
/// iOS, `SharedPreferences` on Android). To share the "seen" state with an iOS
/// App Group, pass preferences configured with a suite name:
///
/// ```dart
/// NoteletStorage(
///   preferences: SharedPreferencesAsync(
///     options: SharedPreferencesAsyncFoundationOptions(
///       suiteName: 'group.com.example.myapp',
///     ),
///   ),
/// )
/// ```
class NoteletStorage {
  const NoteletStorage({this._preferences});

  /// The preferences key holding the latest seen version.
  ///
  /// Matches the key used by the Swift Notelet package, so on iOS an app that
  /// moves to Flutter keeps its users' "seen" state.
  static const latestSeenAppVersionKey = 'Notelet.LatestSeenAppVersion';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _resolvedPreferences =>
      _preferences ?? SharedPreferencesAsync();

  /// Marks the app's current version as seen, e.g. right after onboarding so
  /// new users only see release notes on their first update.
  Future<void> markCurrentVersionAsSeen() async {
    await _resolvedPreferences.setString(
      latestSeenAppVersionKey,
      await getCurrentAppVersion(),
    );
  }

  /// Clears the latest seen version so [NoteletPresentedVersion.current] notes
  /// show again.
  Future<void> resetSeenVersion() {
    return _resolvedPreferences.remove(latestSeenAppVersionKey);
  }

  /// The version the user last saw, or `null` if they never dismissed a
  /// [NoteletPresentedVersion.current] sheet.
  Future<String?> getLatestSeenAppVersion() {
    return _resolvedPreferences.getString(latestSeenAppVersionKey);
  }
}
