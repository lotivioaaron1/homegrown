// lib/widgets/no_internet_overlay.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';
import 'fill_viewport_scroll.dart';
import 'gradient_button.dart';

/// Key of the nth waiting dot, counting from zero.
///
/// Exists so a test can address one dot rather than the row: the bug this
/// screen's rewrite fixed left two of the three dots frozen while the first
/// kept pulsing, which no assertion about the row as a whole would notice.
@visibleForTesting
String dotKey(int index) => 'offline-dot-$index';

/// The full-screen offline gate. Wraps the whole app from
/// `GetMaterialApp.builder`, so it is the only offline treatment in the
/// project — don't add per-screen offline banners alongside it.
class NoInternetOverlay extends StatelessWidget {
  final Widget child;

  const NoInternetOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final service = ConnectivityService.to;

      // Both observables are read unconditionally, before the branch below, so
      // Obx registers the same dependencies whether or not the panel is shown.
      // Reading the second one only inside `if (!isConnected)` would mean the
      // connected build never subscribes to it.
      final isConnected = service.isConnected.value;
      final noInternetOnThisNetwork = service.hasNetworkButNoInternet.value;

      return Stack(children: [
        // ── Main app content ─────────────────
        child,

        // ── No internet overlay ───────────────
        if (!isConnected)
          Positioned.fill(
            child: _OfflinePanel(
              noInternetOnThisNetwork: noInternetOnThisNetwork,
            ),
          ),
      ]);
    });
  }
}

// ─────────────────────────────────────────────
// Offline panel
// ─────────────────────────────────────────────

class _OfflinePanel extends StatelessWidget {
  /// The adapter is up but nothing resolves — a captive portal, or a router
  /// with no upstream. "Check your Wi-Fi" is unhelpful advice to someone whose
  /// Wi-Fi is plainly connected, so the subtitle says something else.
  final bool noInternetOnThisNetwork;

  const _OfflinePanel({required this.noInternetOnThisNetwork});

  @override
  Widget build(BuildContext context) {
    final subtitle = noInternetOnThisNetwork
        ? "You're connected, but this network has no internet. "
            'Homegrown needs one to load events, stats and rankings.'
        : 'Homegrown requires an internet connection '
            'to load events, stats and rankings.';

    return Material(
      color: Colors.transparent,
      // Fade in rather than snapping over the app mid-tap. The subtree is
      // rebuilt from scratch each time the connection drops, so this plays on
      // every appearance.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        // The opaque fill is also what swallows taps meant for the app behind.
        child: Container(
          color: AppTheme.bg,
          child: SafeArea(
            // Centres when it fits, scrolls when it doesn't — landscape, or a
            // large system font scale, used to overflow this column.
            child: FillViewportScroll(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _RadarBeacon(),

                  const SizedBox(height: 32),

                  Semantics(
                    header: true,
                    child: Text('No Internet Connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:         AppTheme.textPrimary,
                        fontSize:      22,
                        fontWeight:    FontWeight.w900,
                        letterSpacing: -0.3)),
                  ),

                  const SizedBox(height: 10),

                  Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:  AppTheme.sub,
                      fontSize: 14,
                      height: 1.6)),

                  const SizedBox(height: 32),

                  // Pulsing waiting indicator
                  const _PulsingDots(),

                  const SizedBox(height: 20),

                  Text('Waiting for connection...',
                    style: TextStyle(
                      color:    AppTheme.muted,
                      fontSize: 13)),

                  const SizedBox(height: 40),

                  // Tips
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border)),
                    child: const Column(children: [
                      _TipRow(icon: Icons.wifi_rounded,
                          text: 'Check your Wi-Fi connection'),
                      SizedBox(height: 10),
                      _TipRow(
                          icon: Icons.signal_cellular_alt_rounded,
                          text: 'Check your mobile data'),
                      SizedBox(height: 10),
                      _TipRow(icon: Icons.airplane_ticket_rounded,
                          text: 'Make sure Airplane mode is off'),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // Retry button
                  const _RetryButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Radar beacon — the dish, with rings sweeping out behind it
// ─────────────────────────────────────────────

class _RadarBeacon extends StatefulWidget {
  const _RadarBeacon();

  @override
  State<_RadarBeacon> createState() => _RadarBeaconState();
}

class _RadarBeaconState extends State<_RadarBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync:    this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Whether the OS asked for no motion — same handling as [OrbitMark].
  /// Resolved here rather than in initState because MediaQuery is not
  /// available yet at that point.
  bool _reducedMotion = false;
  bool _started       = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_started) return;
    _started = true;

    // Left stopped at 0 the rings still paint, just as a static double halo
    // around the dish. Leaving a repeating controller running would also mean
    // no widget test pumping this screen could ever settle.
    if (!_reducedMotion) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rings first, so they sweep out from behind the dish. Isolated in a
          // RepaintBoundary — they repaint every frame and nothing else here
          // needs to come along.
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(
                  painter: _RadarRingsPainter(progress: _c.value),
                ),
              ),
            ),
          ),

          // The dish, unchanged — including its elastic entrance, which lands
          // instantly rather than bouncing when motion is turned off.
          TweenAnimationBuilder<double>(
            tween:    Tween(begin: 0.0, end: 1.0),
            duration: _reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve:    Curves.elasticOut,
            builder:  (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: AppTheme.card,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.border, width: 2),
              ),
              child: const Center(
                child: Text('📡',
                    style: TextStyle(fontSize: 48))),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarRingsPainter extends CustomPainter {
  final double progress;

  const _RadarRingsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint  = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Two rings half a cycle apart, so one is always mid-flight. Each leaves
    // the dish's edge and fades out as it travels.
    for (var i = 0; i < 2; i++) {
      final t = (progress + i * 0.5) % 1.0;
      paint.color = AppTheme.accent.withValues(alpha: (1 - t) * 0.35);
      canvas.drawCircle(center, 55 + (t * 43), paint);
    }
  }

  @override
  bool shouldRepaint(_RadarRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────
// Pulsing dots animation
// ─────────────────────────────────────────────

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  // One controller drives all three dots, with the stagger derived from the
  // shared clock. Three controllers used to be started with repeat(), then
  // nudged out of phase by calling forward() from a Future.delayed — but
  // forward() cancels the repeating simulation and runs a single pass, so dots
  // two and three froze at full opacity after about a second. The delayed
  // callbacks also had no mounted guard, so a connection that returned inside
  // 300ms called forward() on already-disposed controllers.
  late final AnimationController _c = AnimationController(
    vsync:    this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Stopped at 0 the three dots sit at their three resting opacities, which
    // still reads as a row of dots rather than as something broken.
    if (!MediaQuery.of(context).disableAnimations) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot runs the same swell, a fifth of a cycle behind the last.
            final t     = (_c.value - i * 0.18) % 1.0;
            final swell = (math.sin(t * 2 * math.pi) + 1) / 2;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                // Keyed so a test can assert each dot individually — the bug
                // this rewrite fixed left dots 1 and 2 frozen while dot 0 kept
                // going, which is invisible to any assertion on the row.
                key:    ValueKey(dotKey(i)),
                width:  10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(
                      alpha: 0.25 + (swell * 0.75)),
                  shape: BoxShape.circle)),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Retry button
// ─────────────────────────────────────────────

class _RetryButton extends StatefulWidget {
  const _RetryButton();

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _checking = false;

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() => _checking = true);
    try {
      // The DNS lookup behind this can take its full five-second timeout, which
      // is far too long to leave the button looking untouched.
      await ConnectivityService.to.retryConnection();
    } finally {
      // A successful retry flips isConnected, which tears the whole overlay
      // down before the await returns — so the guard is not optional.
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientButton(
      // Null both disables the tap and drops the button to its muted fill, so
      // it never looks tappable while the check is in flight.
      onPressed: _checking ? null : _retry,
      child: Row(mainAxisSize: MainAxisSize.min,
        children: [
          if (_checking)
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.muted))
          else
            const Icon(Icons.refresh_rounded,
                size: 20, color: AppTheme.buttonFg),
          const SizedBox(width: 10),
          Text(_checking ? 'Checking…' : 'Try Again'),
        ]),
    );
  }
}

// ─────────────────────────────────────────────
// Tip row widget
// ─────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String   text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color:        AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppTheme.muted, size: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(
        color:    AppTheme.sub,
        fontSize: 12))),
    ]);
  }
}
