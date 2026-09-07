// lib/widgets/member_profiles.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/team_service.dart';

/// Hydrates the live `users/{uid}` doc for each of [uids] and hands them to
/// [builder], keyed by uid.
///
/// Membership docs carry `athleteName`/`athletePhotoUrl` copied at invite
/// time, so any roster rendered straight from them keeps showing whoever the
/// athlete used to be. Wrapping the list in this widget and passing each row
/// through [resolveMemberIdentity] keeps the displayed identity current.
///
/// [builder] is called immediately with whatever is loaded so far (`{}` on the
/// first frame) rather than being gated behind a spinner — callers already
/// have the membership snapshot to fall back on, so the list renders at once
/// and sharpens when the profiles land.
class MemberProfilesBuilder extends StatefulWidget {
  final List<String> uids;
  final Widget Function(
      BuildContext context, Map<String, Map<String, dynamic>> profiles) builder;

  const MemberProfilesBuilder({
    super.key,
    required this.uids,
    required this.builder,
  });

  @override
  State<MemberProfilesBuilder> createState() => _MemberProfilesBuilderState();
}

class _MemberProfilesBuilderState extends State<MemberProfilesBuilder> {
  Map<String, Map<String, dynamic>> _profiles = {};

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(MemberProfilesBuilder old) {
    super.didUpdateWidget(old);
    // Only refetch when the membership set actually changes. The enclosing
    // StreamBuilder rebuilds on every roster tick, and refetching on each one
    // would put a read storm behind an unchanged list.
    if (!setEquals(old.uids.toSet(), widget.uids.toSet())) _hydrate();
  }

  Future<void> _hydrate() async {
    if (widget.uids.isEmpty) return;
    try {
      final fetched = await TeamService.fetchMemberProfiles(widget.uids);
      if (!mounted) return;
      // Merge rather than replace: a member whose doc is unreadable keeps
      // whatever we already had instead of reverting to the stale snapshot.
      setState(() => _profiles = {..._profiles, ...fetched});
    } catch (_) {
      // A failed hydrate is not an error state — every caller falls back to
      // the membership snapshot, which is stale but displayable.
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _profiles);
}
