// lib/widgets/organizer_profile_parts.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';

/// The pieces an organizer's public identity is built from, following the
/// [athlete_profile_parts.dart] precedent.
///
/// Split this way on purpose: [OrganizerApprovedBadge] and
/// [OrganizerBylineCard] touch no Firebase, so they can be widget-tested,
/// while [OrganizerByline] is the thin Firestore wrapper around them. The
/// badge carries the one real branching decision on the whole feature and is
/// the piece most worth a test.

/// The "this organizer is vetted" pill — rendered **only** for an approved
/// organizer, and rendered as nothing for every other value.
///
/// Deliberately not the same widget as `_organizerStatusBadge` in
/// [ProfileScreen], which labels anything unrecognised "Pending Review". That
/// is right on your own profile and wrong on a public one, for two reasons:
/// 'pending' / 'rejected' / 'revoked' are internal moderation states that a
/// stranger has no business reading, and `organizerStatus` is simply **absent**
/// on every Google-signup organizer (google_profile_setup_screen.dart never
/// writes it), who would otherwise be branded "Pending Review" permanently.
///
/// A stranger's question is only ever "is this organizer vetted?" — absence is
/// the answer "no", and the honest signal survives either way, since the track
/// record below shows real event and tournament counts regardless.
class OrganizerApprovedBadge extends StatelessWidget {
  final String? status;
  const OrganizerApprovedBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status != 'approved') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: AppTheme.successSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.successText)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_rounded, color: AppTheme.successText, size: 13),
        const SizedBox(width: 5),
        Text('Approved Organizer',
            style: TextStyle(
                color: AppTheme.successText,
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// The inline verified tick that sits immediately after an approved
/// organizer's name in a profile header.
///
/// Same rule as [OrganizerApprovedBadge], and for the same reasons: only
/// 'approved' renders anything, and every other value — 'pending', 'rejected',
/// 'revoked', and the absent field every Google-signup organizer has — renders
/// nothing at all. A tick is a claim about someone, so it is only ever shown
/// when the claim is true.
///
/// Kept separate from the pill rather than replacing it: the pill says which
/// state you are in, which is what you want on your own profile, while the
/// tick reads at a glance next to the name.
class OrganizerVerifiedTick extends StatelessWidget {
  final String? status;
  const OrganizerVerifiedTick({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status != 'approved') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      // successText, not success: AppTheme notes the raw success colour is
      // 2.3:1 on white and fails contrast for anything this small.
      child:
          Icon(Icons.verified_rounded, color: AppTheme.successText, size: 17),
    );
  }
}

/// The presentational half of the byline — no Firestore, so it renders the
/// same whether the name came from a live doc, a tombstone or a placeholder.
///
/// [onTap] being null is what marks the card inert: it also drops the chevron,
/// so a card that cannot be opened never advertises that it can.
class OrganizerBylineCard extends StatelessWidget {
  final String name;
  final bool approved;
  final String? photoUrl;
  final VoidCallback? onTap;

  const OrganizerBylineCard({
    super.key,
    required this.name,
    this.approved = false,
    this.photoUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // No organizer-logo field exists anywhere in the app, so an organizer with
    // no avatar falls back to the same business glyph ProfileScreen uses.
    final avatar = (photoUrl != null && photoUrl!.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: photoUrl!,
            fit: BoxFit.cover,
            memCacheWidth: 110,
            errorWidget: (_, __, ___) =>
                Icon(Icons.business_rounded, color: AppTheme.muted, size: 18),
          )
        : Icon(Icons.business_rounded, color: AppTheme.muted, size: 18);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppTheme.cardNested,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border)),
            child: ClipOval(child: avatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ORGANIZED BY',
                      style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                    if (approved) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.verified_rounded,
                          color: AppTheme.successText, size: 14),
                    ],
                  ]),
                ]),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }
}

/// Resolves `users/{organizerId}` and hands it to [OrganizerBylineCard].
///
/// A one-shot `.get()` rather than a stream: a byline needs no live updates,
/// and this costs exactly one document read per event opened. The alternative
/// — denormalising `organizerName` onto event docs — would need writing at
/// three separate call sites, would still only cover documents created after
/// the change (so this fetch would ship anyway), and goes stale on rename, a
/// problem this codebase has already been bitten by twice.
///
/// Fetching identity per widget has precedent in the screen this is used from:
/// `_TeamBlock` in event_detail_screen.dart already opens a `users/{coachId}`
/// listener purely to read a team logo.
class OrganizerByline extends StatefulWidget {
  final String organizerId;
  const OrganizerByline({super.key, required this.organizerId});

  @override
  State<OrganizerByline> createState() => _OrganizerBylineState();
}

class _OrganizerBylineState extends State<OrganizerByline> {
  late Future<DocumentSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.organizerId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          // Inert while loading, so the row never flashes as tappable before
          // there is anything to open.
          return const OrganizerBylineCard(name: '…');
        }
        final org = snap.data?.data() as Map<String, dynamic>?;

        // The in-app deletion flow leaves a tombstone rather than removing the
        // document (`deleted: true`, fullName 'Deleted user'), and events keep
        // their organizerId on purpose, so a live-looking doc here may be a
        // deleted account. Opening its profile would show an empty shell.
        if (org == null || org['deleted'] == true) {
          return const OrganizerBylineCard(name: 'Deleted account');
        }

        final identity =
            resolveMemberIdentity(org, fallbackName: 'Organizer');
        return OrganizerBylineCard(
          name: identity.name,
          photoUrl: identity.photoUrl,
          approved: org['organizerStatus'] == 'approved',
          onTap: () => Get.toNamed('/profile/organizer',
              arguments: {'organizerId': widget.organizerId}),
        );
      },
    );
  }
}
