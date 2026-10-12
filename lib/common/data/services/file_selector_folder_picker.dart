import 'package:file_selector/file_selector.dart';
import 'package:petit/common/domain/services/folder_picker.dart';

class FileSelectorFolderPicker implements FolderPicker {
  @override
  Future<String?> pickFolder({String? initialDirectory}) {
    return getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: 'Save here',
    );
  }
}
