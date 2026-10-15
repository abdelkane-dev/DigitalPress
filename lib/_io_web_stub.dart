// Web stub for dart:io — provides minimal stubs so the app compiles on web.
// These are never instantiated at runtime (guarded by try-catch).
class File {
  final String path;
  File(this.path);
  Future<String> readAsString() async => '';
  Future<void> writeAsString(String s, {Object? mode}) async {}
}
class FileMode {
  static final append = FileMode._();
  FileMode._();
}
class Directory {
  final String path;
  Directory(this.path);
}
