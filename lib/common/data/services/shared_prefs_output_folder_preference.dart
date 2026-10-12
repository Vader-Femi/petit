import 'package:petit/common/domain/services/output_folder_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsOutputFolderPreference implements OutputFolderPreference {
  SharedPrefsOutputFolderPreference(this._prefs);

  static const _key = 'output_folder';

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String? path) async {
    if (path == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, path);
    }
  }
}
