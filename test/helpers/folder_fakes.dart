import 'package:petit/common/domain/services/folder_picker.dart';
import 'package:petit/common/domain/services/output_folder_preference.dart';

class FakeFolderPicker implements FolderPicker {
  FakeFolderPicker([this.result]);

  String? result;
  int calls = 0;
  String? lastInitialDirectory;

  @override
  Future<String?> pickFolder({String? initialDirectory}) async {
    calls++;
    lastInitialDirectory = initialDirectory;
    return result;
  }
}

class FakePreference implements OutputFolderPreference {
  FakePreference([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? path) async => value = path;
}
