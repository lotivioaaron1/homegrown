// lib/widgets/barangay_picker_sheet.dart
import 'package:flutter/material.dart';
import '../services/barangay_service.dart';
import '../theme/app_theme.dart';

/// Shows the shared barangay-selection bottom sheet, backed by the live
/// [BarangayService] list instead of a hand-typed catalog. Returns the
/// selected barangay name, or null if the sheet was dismissed.
Future<String?> showBarangayPickerSheet(BuildContext context,
    {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _BarangayPickerSheet(selected: selected),
  );
}

class _BarangayPickerSheet extends StatefulWidget {
  final String? selected;
  const _BarangayPickerSheet({this.selected});

  @override
  State<_BarangayPickerSheet> createState() => _BarangayPickerSheetState();
}

class _BarangayPickerSheetState extends State<_BarangayPickerSheet> {
  final _search = TextEditingController();
  List<String> _all = [];
  List<String> _filtered = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    // Always resolves: BarangayService falls back to a bundled snapshot
    // rather than failing, because a user who can't pick a barangay can't
    // finish registering at all.
    final result = await BarangayService.fetchBarangays();
    if (!mounted) return;
    setState(() {
      _all = result.names;
      _filtered = _filterList(result.names, _search.text);
      _isOffline = result.isOffline;
      _isLoading = false;
    });
  }

  /// Shown when the live registry was unreachable and the bundled snapshot
  /// is standing in. Informational, not an error: the list below is complete
  /// and selectable, it just may not reflect a very recent PSGC change.
  Widget _offlineNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Icon(Icons.cloud_off_rounded, color: AppTheme.muted, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Showing a saved list — we couldn\'t reach the registry.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12)),
        ),
        TextButton(
          onPressed: _load,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('Retry',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  List<String> _filterList(List<String> source, String query) {
    if (query.isEmpty) return source;
    return source
        .where((b) => b.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Widget _buildBody(ScrollController ctrl) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2));
    }
    if (_filtered.isEmpty) {
      return Center(
          child: Text('No barangay matches your search',
              style: TextStyle(color: AppTheme.muted, fontSize: 13)));
    }
    return ListView.builder(
      controller: ctrl,
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final b = _filtered[i];
        final sel = b == widget.selected;
        return ListTile(
          dense: true,
          title: Text(b,
              style: TextStyle(
                  color: sel ? AppTheme.accentText : AppTheme.textPrimary,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14)),
          trailing: sel
              ? const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accent, size: 20)
              : null,
          onTap: () => Navigator.pop(context, b),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('Select Barangay',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary),
            onChanged: (q) =>
                setState(() => _filtered = _filterList(_all, q)),
            decoration: InputDecoration(
              hintText: 'Search barangay...',
              hintStyle: TextStyle(color: AppTheme.muted),
              prefixIcon:
                  Icon(Icons.search_rounded, color: AppTheme.muted, size: 20),
              filled: true,
              fillColor: AppTheme.bg,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_isOffline && !_isLoading) _offlineNotice(),
        Expanded(child: _buildBody(ctrl)),
      ]),
    );
  }
}
