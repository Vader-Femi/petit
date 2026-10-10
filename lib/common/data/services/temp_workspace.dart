import 'package:petit/common/domain/services/workspace.dart';
import 'package:petit/core/utils/work_dir.dart';

class TempWorkspace implements Workspace {
  @override
  Future<void> clear() => clearTempFiles();
}
