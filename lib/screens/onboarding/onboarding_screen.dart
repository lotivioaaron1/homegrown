import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';

// ── Sport intro panel data ────────────────────────────────────────
// Drop your photos in at these paths. Until they exist, each panel
// falls back to a themed gradient + icon so nothing breaks.
class _SportPanelData {
  final String assetPath;
  final String eyebrow;
  final String headline;
  final String subtext;
  const _SportPanelData({
    required this.assetPath,
    required this.eyebrow,
    required this.headline,
    required this.subtext,
  });
}

const List<_SportPanelData> _sportPanels = [
  _SportPanelData(
    assetPath: 'assets/images/onboard_basketball.jpg',
    eyebrow:   'BASKETBALL',
    headline:  'Every Shot\nTells a Story',
    subtext:   'Track your stats, get scouted by coaches, and rise through '
        "Legazpi's basketball scene.",
  ),
  _SportPanelData(
    assetPath: 'assets/images/onboard_volleyball.jpg',
    eyebrow:   'VOLLEYBALL',
    headline:  'Rise Above\nThe Net',
    subtext:   'Find games, join local leagues, and build your athletic '
        'profile as a volleyball player.',
  ),
  _SportPanelData(
    assetPath: 'assets/images/onboard_badminton.jpg',
    eyebrow:   'BADMINTON',
    headline:  'Precision.\nSpeed. Grit.',
    subtext:   "Discover courts near you and connect with Legazpi's "
        'badminton community.',
  ),
];

/// Three full-bleed sport panels between the splash's Create Account and the
/// registration form.
///
/// A Features page used to follow them: a light page of three cards pitching
/// the dashboard, talent discovery and the venue locator. It was removed
/// because by then the same pitch had been made twice already — on the
/// splash's welcome screen and on the basketball panel — and because it made
/// someone who had tapped Create Account tap Get Started as well before
/// reaching the form. The last panel now carries Create Account itself.
///
/// A "What sport do you play?" page before that was removed too. It saved the
/// answer to SharedPreferences and nothing ever read it, so registration asked
/// for the sport again anyway — and because this runs before the role picker,
/// it asked coaches and organizers a question meant for athletes. The
/// role-specific registration screens own the question now.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  static final int _lastPage = _sportPanels.length - 1;

  int _currentPage = 0;

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // Deliberately records nothing. splash_screen.dart marks onboarding done
  // once it finds a signed-in user, because the splash's CTA is the only
  // route to this screen: setting the flag here stranded anyone who watched
  // the intro and then abandoned registration, since they were sent to the
  // login screen from then on and could never reach the intro again.
  void _onCreateAccount() => Get.offAllNamed('/register');

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The panels' own ink rather than the theme's background. Every page is
      // a dark photograph now, so a theme colour could only ever show as a
      // pale flash behind one while it loads or slides.
      backgroundColor: const Color(0xFF0A0A12),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              for (int i = 0; i < _sportPanels.length; i++)
                _SportPanel(
                  data: _sportPanels[i],
                  isLast: i == _lastPage,
                  onAdvance:
                      i == _lastPage ? _onCreateAccount : () => _goToPage(i + 1),
                ),
            ],
          ),

          // Skip, so wanting an account does not cost three pages of pitch.
          //
          // Hidden on the last panel, whose own button goes to the same place:
          // a Skip beside it would be two controls doing one job.
          if (_currentPage < _lastPage)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: _SkipButton(onTap: _onCreateAccount),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: _SportPanelDots(
              total: _sportPanels.length,
              current: _currentPage,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skip, sitting on top of a photograph.
///
/// It carries its own dark pill rather than plain white text. The sport
/// panels' scrim is fully transparent at the top and only starts darkening
/// at 45% down, so a bare label would sit on whatever each photograph
/// happens to be doing up there — light studio backdrop on one, a subject on
/// the next. The pill gives it a consistent ground on all three.
///
/// Padded rather than fixed-size so the box grows with the system text
/// setting instead of clipping, while still clearing the 48dp tap target at
/// the default size.
class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Skip',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Full-bleed sport intro panel ──────────────────────────────────
class _SportPanel extends StatelessWidget {
  final _SportPanelData data;

  /// The last panel's button is the way out of the intro rather than to the
  /// next panel, and says so.
  final bool isLast;
  final VoidCallback onAdvance;

  const _SportPanel({
    required this.data,
    required this.isLast,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Gold on the last panel, matching the splash's Create Account: it is the
    // same action, and the one place in the intro that commits to something.
    final buttonColor = isLast ? AppTheme.accent : Colors.white;
    final labelColor = isLast ? AppTheme.buttonFg : const Color(0xFF0A0A12);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          data.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1200), Color(0xFF0F0F1A)],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.sports_basketball_outlined,
                size: size.width * 0.28,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
              colors: [
                Colors.transparent,
                Color(0xCC0A0A12),
                Color(0xF20A0A12),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            size.width * 0.07,
            0,
            size.width * 0.07,
            bottomInset + 52, // leaves room for the dot row below it
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.eyebrow,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data.headline,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width * 0.088,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.subtext,
                style: const TextStyle(
                  color: Color(0xFFC7C7D6),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onAdvance,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  // "Next" on every panel but the last. It used to read
                  // "Swipe to start" — on a button you tap — and the last
                  // panel said "Get Started ✓" only to open a Features page
                  // with another Get Started, so the same promise appeared
                  // twice. Now the last panel's button is the real one.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLast ? 'Create Account' : 'Next',
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: labelColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SportPanelDots extends StatelessWidget {
  final int total;
  final int current;
  const _SportPanelDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
