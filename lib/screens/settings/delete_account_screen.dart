// lib/screens/settings/delete_account_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/account_deletion_service.dart';
import '../../theme/app_theme.dart';

const _kDanger = Color(0xFFFF5C5C);
const _kConfirmWord = 'DELETE';

/// Permanent account deletion. Reachable from Settings, and required by
/// Google Play for any app that lets people create an account.
///
/// The screen is deliberately explicit about what survives deletion. Match
/// results and events are shared records — other people appear in them too —
/// so hiding that they remain would be the kind of surprise that reads as
/// dishonest once someone notices their old game still listed.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isDeleting = false;
  bool _obscure = true;
  String _status = '';
  String? _error;

  late final bool _needsPassword = AccountDeletionService.requiresPassword;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isDeleting) return false;
    if (_confirmCtrl.text.trim().toUpperCase() != _kConfirmWord) return false;
    if (_needsPassword && _passwordCtrl.text.isEmpty) return false;
    return true;
  }

  Future<void> _delete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
      _status = '';
    });

    try {
      await AccountDeletionService.deleteAccount(
        password: _needsPassword ? _passwordCtrl.text : null,
        onProgress: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      // The Auth user is gone, so the app's auth listener will route away on
      // its own; clearing the stack here avoids a frame of dead UI first.
      Get.offAllNamed('/login');
      Get.snackbar(
        'Account deleted',
        'Your account and personal data have been removed.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.card,
        colorText: AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _status = '';
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _status = '';
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppTheme.textPrimary),
          onPressed: _isDeleting ? null : () => Get.back(),
        ),
        title: Text('Delete Account',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _header(),
            const SizedBox(height: 20),
            _panel(
              title: 'What gets deleted',
              tone: _kDanger,
              icon: LucideIcons.trash2,
              items: const [
                'Your name, email, phone and barangay',
                'Your profile photo and portfolio media',
                'Your organizer verification document',
                'Your rating history and notifications',
                'Your team membership',
                'Your sign-in — you will not be able to log back in',
              ],
            ),
            const SizedBox(height: 12),
            _panel(
              title: 'What stays',
              tone: AppTheme.muted,
              icon: LucideIcons.history,
              items: const [
                'Match results and stats from games you played',
                'Events you organized, and their results',
              ],
              footnote:
                  'These involve other players too, so removing them would erase '
                  'their history as well. Your name is replaced with "Deleted user".',
            ),
            const SizedBox(height: 24),
            if (_needsPassword) ...[
              _label('Confirm your password'),
              const SizedBox(height: 8),
              _passwordField(),
              const SizedBox(height: 18),
            ] else ...[
              Text(
                'You will be asked to confirm with Google before deletion.',
                style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
            ],
            _label('Type $_kConfirmWord to confirm'),
            const SizedBox(height: 8),
            _confirmField(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBox(_error!),
            ],
            if (_isDeleting && _status.isNotEmpty) ...[
              const SizedBox(height: 14),
              _progressBox(_status),
            ],
            const SizedBox(height: 24),
            _deleteButton(),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _isDeleting ? null : () => Get.back(),
                child: Text('Keep my account',
                    style: TextStyle(
                        color: AppTheme.sub, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pieces ───────────────────────────────────────

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorText.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LucideIcons.triangleAlert, color: AppTheme.errorText, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This cannot be undone',
                style: TextStyle(
                    color: AppTheme.errorText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Deleting your account is permanent. There is no way to recover '
              'it, and signing up again will not restore your data.',
              style:
                  TextStyle(color: AppTheme.sub, fontSize: 12.5, height: 1.55),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _panel({
    required String title,
    required Color tone,
    required IconData icon,
    required List<String> items,
    String? footnote,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: tone, size: 16),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        ...items.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: tone, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(t,
                        style: TextStyle(
                            color: AppTheme.sub, fontSize: 12.5, height: 1.45))),
              ]),
            )),
        if (footnote != null) ...[
          const SizedBox(height: 4),
          Text(footnote,
              style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11.5,
                  height: 1.5,
                  fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700));

  InputDecoration _fieldDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.muted),
      filled: true,
      fillColor: AppTheme.card,
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kDanger, width: 1.5)),
    );
  }

  Widget _passwordField() {
    return TextField(
      controller: _passwordCtrl,
      obscureText: _obscure,
      enabled: !_isDeleting,
      style: TextStyle(color: AppTheme.textPrimary),
      onChanged: (_) => setState(() {}),
      decoration: _fieldDecoration(
        'Your password',
        suffix: IconButton(
          icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff,
              color: AppTheme.muted, size: 18),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  Widget _confirmField() {
    return TextField(
      controller: _confirmCtrl,
      enabled: !_isDeleting,
      textCapitalization: TextCapitalization.characters,
      style: TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 1.5),
      onChanged: (_) => setState(() {}),
      decoration: _fieldDecoration(_kConfirmWord),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorText.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(LucideIcons.circleAlert, color: AppTheme.errorText, size: 16),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    color: AppTheme.errorText, fontSize: 12.5, height: 1.4))),
      ]),
    );
  }

  Widget _progressBox(String status) {
    return Row(children: [
      const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppTheme.accent),
      ),
      const SizedBox(width: 12),
      Text('$status…',
          style: TextStyle(color: AppTheme.sub, fontSize: 12.5)),
    ]);
  }

  Widget _deleteButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _canSubmit ? _delete : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kDanger,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.cardNested,
          disabledForegroundColor: AppTheme.muted,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          _isDeleting ? 'Deleting…' : 'Delete my account permanently',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }
}
