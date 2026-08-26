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
  bool _failed = false;

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
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final names = await BarangayService.fetchBarangays();
      if (!mounted) return;
      setState(() {
        _all = names;
        _filtered = _filterList(names, _search.text);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
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
    if (_failed) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: AppTheme.muted, size: 32),
        const SizedBox(height: 10),
        Text('Something went wrong',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text("We couldn't load the barangay list just now.",
            style: TextStyle(color: AppTheme.muted, fontSize: 12)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _load,
          child: Text('Retry', style: TextStyle(color: AppTheme.accent)),
        ),
      ]));
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
              ? Icon(Icons.check_circle_rounded,
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
                      BorderSide(color: AppTheme.accent, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBody(ctrl)),
      ]),
    );
  }
}
