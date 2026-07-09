// lib/screens/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────
// Enum
// ─────────────────────────────────────────────

enum UserSport { basketball, volleyball, badminton }

// ─────────────────────────────────────────────
// OnboardingScreen
// ─────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  static const int _totalPages = 2;

  int        _currentPage  = 0;
  UserSport? _selectedSport;

  // ── Navigation ────────────────────────────

  void _onContinue() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve:    Curves.easeInOut,
      );
    } else {
      _onGetStarted();
    }
  }

  void _onSkip() {
    _pageController.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 400),
      curve:    Curves.easeInOut,
    );
  }

  Future<void> _onGetStarted() async {
    if (_selectedSport != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_sport', _selectedSport!.name);
    }
    Get.offAllNamed('/register');
  }

  String get _buttonLabel =>
      _currentPage == 0 ? 'Continue' : 'Get Started';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller:    _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  const _FeaturesPage(),
                  _SportSelectionPage(
                    selectedSport:   _selectedSport,
                    onSportSelected: (s) =>
                        setState(() => _selectedSport = s),
                  ),
                ],
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DotIndicator(
                    total:   _totalPages,
                    current: _currentPage,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width:  double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      child: Text(_buttonLabel),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_currentPage < _totalPages - 1)
                    GestureDetector(
                      onTap: _onSkip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color:      AppTheme.sub,
                          fontSize:   14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Page 1 — Features
// ─────────────────────────────────────────────

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  final List<_FeatureItem> _features = const [
    _FeatureItem(
      emoji:       '📊',
      color:       Color(0xFF2E1F00),
      title:       'Performance Dashboard',
      description: 'Track your game stats and see your growth with visual analytics.',
    ),
    _FeatureItem(
      emoji:       '🏆',
      color:       Color(0xFF1A1200),
      title:       'Talent Discovery',
      description: 'Get ranked by coaches through our Point-Based scoring system.',
    ),
    _FeatureItem(
      emoji:       '📍',
      color:       Color(0xFF0D1A2E),
      title:       'Game Directory',
      description: 'Find games and venues near you with our Venue Locator.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'HOMEGROWN',
            style: TextStyle(
              color:         AppTheme.accent,
              fontSize:      11,
              fontWeight:    FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Your Digital\nAthletic Identity',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:         AppTheme.textPrimary,
              fontSize:      28,
              fontWeight:    FontWeight.w900,
              height:        1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Track your performance, get discovered by coaches, and find games near you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    AppTheme.sub,
              fontSize: 14,
              height:   1.6,
            ),
          ),
          const SizedBox(height: 32),

          ..._features.map((f) => _FeatureCard(item: f)),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final String emoji;
  final Color  color;
  final String title;
  final String description;

  const _FeatureItem({
    required this.emoji,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color:        item.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(item.emoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color:      AppTheme.textPrimary,
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color:    AppTheme.sub,
                    fontSize: 13,
                    height:   1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Page 2 — Sport Selection
// ─────────────────────────────────────────────

class _SportSelectionPage extends StatelessWidget {
  final UserSport?              selectedSport;
  final ValueChanged<UserSport> onSportSelected;

  const _SportSelectionPage({
    required this.selectedSport,
    required this.onSportSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'What sport do\nyou play?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:         AppTheme.textPrimary,
              fontSize:      28,
              fontWeight:    FontWeight.w900,
              height:        1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select your primary sport to personalize your experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    AppTheme.sub,
              fontSize: 14,
              height:   1.6,
            ),
          ),
          const SizedBox(height: 36),

          GridView.count(
            crossAxisCount:   2,
            shrinkWrap:       true,
            physics:          const NeverScrollableScrollPhysics(),
            mainAxisSpacing:  14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
            children: [
              _SportCard(
                emoji:      '🏀',
                label:      'Basketball',
                sport:      UserSport.basketball,
                isSelected: selectedSport == UserSport.basketball,
                onTap:      () => onSportSelected(UserSport.basketball),
              ),
              _SportCard(
                emoji:      '🏐',
                label:      'Volleyball',
                sport:      UserSport.volleyball,
                isSelected: selectedSport == UserSport.volleyball,
                onTap:      () => onSportSelected(UserSport.volleyball),
              ),
              _SportCard(
                emoji:      '🏸',
                label:      'Badminton',
                sport:      UserSport.badminton,
                isSelected: selectedSport == UserSport.badminton,
                onTap:      () => onSportSelected(UserSport.badminton),
              ),
              const _SportCardDisabled(),
            ],
          ),
        ],
      ),
    );
  }
}

class _SportCard extends StatelessWidget {
  final String     emoji;
  final String     label;
  final UserSport  sport;
  final bool       isSelected;
  final VoidCallback onTap;

  const _SportCard({
    required this.emoji,
    required this.label,
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentSurface : AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color:      isSelected ? AppTheme.accentText : AppTheme.textPrimary,
                fontSize:   14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to Select',
              style: TextStyle(
                color:    isSelected
                    ? AppTheme.accent.withValues(alpha: 0.7)
                    : AppTheme.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportCardDisabled extends StatelessWidget {
  const _SportCardDisabled();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppTheme.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('⏳', style: TextStyle(fontSize: 38)),
          SizedBox(height: 10),
          Text(
            'More Soon',
            style: TextStyle(
              color:      AppTheme.muted,
              fontSize:   14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Coming soon',
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dot Indicator
// ─────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int total;
  final int current;

  const _DotIndicator({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeInOut,
          margin:   const EdgeInsets.symmetric(horizontal: 4),
          width:    active ? 24 : 8,
          height:   8,
          decoration: BoxDecoration(
            color:        active ? AppTheme.accent : AppTheme.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}