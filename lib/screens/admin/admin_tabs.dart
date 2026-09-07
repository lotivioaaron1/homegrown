// lib/screens/admin/admin_tabs.dart

/// Tab indices for AdminShellScreen.
///
/// Named rather than written as bare integers at each call site, because the
/// overview cards act as shortcuts into other tabs and would silently jump to
/// the wrong one the first time a tab is inserted. Kept in its own file so
/// both the shell and the screens it hosts can refer to it without importing
/// each other.
class AdminTab {
  static const int overview = 0;
  static const int users = 1;
  static const int content = 2;
  static const int reports = 3;
  static const int approvals = 4;

  /// How many tabs the shell shows. Keeps the nav bar and the constants above
  /// from drifting apart.
  static const int count = 5;
}
