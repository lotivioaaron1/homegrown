// lib/widgets/report_dialog.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/report.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';

/// Opens the "report this" sheet for a user or an event.
///
/// A single entry point on purpose: the screens that offer reporting are large
/// and already working, so what they gain is one call rather than a form. Add
/// a new target type by passing a different [targetType] — the model, the
/// queue and the rules already treat it generically.
///
/// [targetLabel] is stored with the report so the admin can tell what was
/// reported even if the target is later deleted.
Future<void> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
  required String targetLabel,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String targetLabel;

  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String get _noun => widget.targetType == Report.targetEvent
      ? 'this event'
      : 'this account';

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet clear of the keyboard once the details field focuses.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Report $_noun',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  'This goes to the Homegrown administrators. '
                  '${widget.targetLabel} is not told who reported them.',
                  style: TextStyle(
                      color: AppTheme.sub, fontSize: 12.5, height: 1.5)),
              const SizedBox(height: 18),
              ...Report.reasons.map(_reasonTile),
              const SizedBox(height: 14),
              TextField(
                controller: _details,
                maxLength: 300,
                maxLines: 3,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Anything else the admins should know (optional)',
                  hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.inputFill,
                  counterStyle:
                      TextStyle(color: AppTheme.muted, fontSize: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.accent)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _reason == null || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.buttonFg,
                    disabledBackgroundColor: AppTheme.cardNested,
                    disabledForegroundColor: AppTheme.muted,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.buttonFg))
                      : const Text('Submit report',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reasonTile(String reason) {
    final selected = _reason == reason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _reason = reason),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentSurface : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.border),
          ),
          child: Row(children: [
            Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 17,
                color: selected ? AppTheme.accent : AppTheme.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(reason,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      // Checked at submit rather than on open, so the sheet costs nothing to
      // dismiss. Filing the same complaint twice adds noise to the queue
      // without adding information.
      if (await ReportService.hasOpenReport(widget.targetId)) {
        if (!mounted) return;
        Navigator.pop(context);
        Get.snackbar('Already reported',
            "You've already reported this. The admins are looking into it.");
        return;
      }

      await ReportService.submit(
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetLabel: widget.targetLabel,
        reason: _reason!,
        details: _details.text,
      );

      if (!mounted) return;
      Navigator.pop(context);
      Get.snackbar('Report sent',
          'Thanks — an administrator will take a look at this.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      Get.snackbar('Something went wrong',
          "Your report didn't send. Check your connection and try again.");
    }
  }
}
