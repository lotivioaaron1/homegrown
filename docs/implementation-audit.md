# Homegrown — Current Implementation Audit

**Purpose.** This document describes what the Homegrown application *actually does today*,
traced to source. It exists so the manuscript's diagrams, flowcharts and database tables
can be corrected against the shipped system rather than against an earlier design intent.

**Status.** Audit only. No application source file was modified to produce it.

**Repository state at audit time.** Branch `docs/implementation-audit`, taken from `main`
at commit `846235a` ("Fix chip row alignment that only showed on real devices").
App version `1.0.0+5` (`pubspec.yaml`).

---

## 0. How to read this document

### Evidence tiers

Every factual claim below carries one of three tiers. Please preserve the distinction when
copying material into the manuscript.

| Tier | Meaning |
|---|---|
| *(plain, with a file path)* | **Read directly from the current source.** The cited file and function were opened and the behaviour confirmed. |
| `[test]` | **Pinned by an automated test.** Stronger than a source citation: it states the intended contract, not just the current code. |
| `[per working copy]` | **Second-hand.** Taken from `Homegrown_Manuscript_Revision_Working_Copy_2.docx`, used only for statements about *what a manuscript figure currently depicts* — those figures are images with no extractable text layer, so they could not be re-verified here. |
| **NOT WIRED** | A model, widget or field exists in the codebase but **nothing writes to it or renders it**. Do not document these as working features. |

### Source documents consulted

| Document | Date | Role in this audit |
|---|---|---|
| `C:\Users\ADMIN\Downloads\HOMEGROWN - THESIS.pdf` | 2026-09-15 08:33 | The current manuscript. Text extracted with `pdftotext -layout`. Supplies Figures 1–8 and Tables 3.1–3.29, Scope & Delimitation, and Chapter 4. |
| `C:\Users\ADMIN\Downloads\Homegrown_Manuscript_Revision_Working_Copy_2.docx` | 2026-09-15 09:23 | An earlier correction pass. Supplies descriptions of what Figures 4–8 currently draw. |
| `C:\flutter\homegrown\` | working tree | The application itself — the primary source for everything else. |

### One numbering warning before you start

The working-copy DOCX refers to the Class Diagram as **Figure 9**. The current manuscript
PDF numbers it **Figure 8** — there is no Figure 9 in the PDF. This document uses the
**PDF's numbering throughout**. Check the figure number before pasting any correction, or
class-diagram edits will land on the sequence diagram.

---

## 1. Current user roles

There are **four** roles, not three. The `role` field on `users/{uid}` is the single source
of truth, and `lib/utils/auth_routing.dart` branches on it.

| Role | String value | How it is obtained | Landing route |
|---|---|---|---|
| Athlete | `athlete` | Self-selected at registration | `/home` |
| Coach | `coach` | Self-selected at registration | `/home` |
| Organizer | `organizer` | Self-selected at registration; then **requires admin approval** before it can do anything | `/home` |
| **Super-admin** | `admin` | **Not reachable through the app at all** — hand-set in the Firebase console | `/admin` |

A fifth transient state exists: a Google sign-in creates a user document with
`role: ''` (`lib/controllers/auth_controller.dart`, `signInWithGoogle`), which routes to
`/google-profile-setup` until a real role is chosen.

**Why `admin` cannot be self-assigned.** `firestore.rules:45-52` restricts the role on
create to `['athlete','coach','organizer','']`, and permits a role *change* only from `''`
to one of those same three. `'admin'` appears in neither list, so no client write can ever
produce one.

**Admin identity is checked two different ways and both must be maintained together:**
`firestore.rules:31-33` does a live `role == 'admin'` document lookup, while
`storage.rules` compares against a **hardcoded UID list** in `isAdminUid()` — a
cross-service `firestore.get()` from Storage rules returns `unauthorized` in this project.
Provisioning a second admin therefore requires editing and redeploying `storage.rules`.

> **Manuscript impact.** The manuscript describes "three main players, athletes, coaches
> and organizers" (Figure 5 narration) and never uses the words *admin* or *administrator*
> — a word-boundary search over the extracted PDF text returns **zero** occurrences. The
> entire fourth role and its console are undocumented. See §17.

---

## 2. Authentication flow

### 2.1 Registration — three separate role wizards

`/register` is a role picker only (`lib/screens/auth/register_screen.dart`); it routes to
one of three **3-step wizards**. All three share the same step-1 field set and password
policy, and diverge from step 2 onward.

**Password policy, enforced identically in all three** (e.g.
`lib/screens/auth/athlete_register_screen.dart:360-370`): non-empty, at least 8
characters, at least one uppercase letter (`RegExp(r'[A-Z]')`), at least one digit
(`RegExp(r'[0-9]')`), plus a matching confirm field. The rules are stated up front in a
hint rather than only on failure.

| | Athlete | Coach | Organizer |
|---|---|---|---|
| Step 1 | First, Last, Email, Barangay, Password, Confirm | same | same **+ Phone Number (required)** |
| Step 2 | Sports (**multi**-select), Position (from catalog), Years of Playing, Height, Weight | Sport (**single**-select), Coaching Level, Years of Experience, Team/Organization | Organization Name, Organization Type, Sports Organized (multi) |
| Step 3 | Photo, Bio, Open to Recruitment | Photo, Coaching Bio, Certifications | Photo, Bio, Credentials, **Verification Photo** |
| Writes `role` | `athlete` | `coach` | `organizer` **+ `organizerStatus: 'pending'`** |
| Extra fields | `points: 0`, `isPublic: true`, `openToRecruitment` | — | notifies every admin |

**Position is picked from a closed catalog, never typed.** `lib/constants/sport_positions.dart`
defines Basketball {Point Guard, Shooting Guard, Small Forward, Power Forward, Center},
Volleyball {Setter, Outside Hitter, Opposite Hitter, Middle Blocker, Libero, Defensive
Specialist}, Badminton {Singles, Doubles, Mixed Doubles}, with deliberately **no "Other"**
entry. `[test]` `test/constants/sport_positions_test.dart` pins that the catalog "covers
every sport the registration screens offer" and that free text is rejected.

**Barangay comes from a live registry, not a hardcoded list.** `BarangayService.fetchBarangays()`
queries the PSGC registry and falls back to a bundled snapshot when offline, showing the
notice *"Showing a saved list — we couldn't reach the registry."* with a Retry control
(`lib/widgets/barangay_picker_sheet.dart:66-90`). `[test]` `test/services/barangay_service_test.dart`
pins the fallback on non-200, on throw, and on an empty result.

**Registration is transactional, by hand.** `lib/utils/registration_rollback.dart` wraps
the Firestore writes so that a failure **deletes the just-created Auth account** and
rethrows the original error. Without it, an Auth account with no profile permanently
strands that email address behind `email-already-in-use`. `[test]`
`test/utils/registration_rollback_test.dart` pins that the account is deleted on failure,
that the original failure is rethrown rather than a rollback failure, and that the writes
run exactly once.

Inside the rollback (required): the `users/{uid}` document and `ContactService.write`.
Outside it (recoverable, failure is tolerated): avatar upload, verification document,
admin notifications, the onboarding flag, and the verification email.

### 2.2 Login

Two paths, both ending at the same routing function.

**Email/password** — `AuthController.signInWithEmail` (`lib/controllers/auth_controller.dart:39-81`):
sign in → mark onboarding complete → read `users/{uid}` once → `Get.offAllNamed(landingRoute(...))`.

**Google** — `AuthController.signInWithGoogle` (`:145-237`) returns the role, or `null` for
*both* "brand-new account" and "failure/cancel". A new account gets a minimal user
document (`role: ''`, `authProvider: 'google'`) and is routed to `/google-profile-setup`.

**Error messages are deliberately non-enumerating.** `lib/utils/error_messages.dart:86-102`
collapses `invalid-credential`, `wrong-password` and `user-not-found` into a single
message — *"Wrong email or password. If you signed up with Google, use Continue with
Google below."* — so the screen cannot be used to discover which email addresses have
accounts.

### 2.3 The landing decision — one pure function

`landingRoute()` in `lib/utils/auth_routing.dart:33-64` is the **only** place post-auth
routing is decided. Three call sites use it and therefore cannot drift apart:
`lib/screens/splash_screen.dart:260-266`, `lib/controllers/auth_controller.dart:61-67`,
`lib/screens/auth/login_screen.dart:107-113`.

**The branch order is load-bearing:**

```
1.  role == 'admin'                        → /admin
2.  suspended                              → /suspended
3.  !emailVerified && hasPasswordProvider  → /verify-email
4.  otherwise                              → /home
```

`[test]` `test/utils/auth_routing_test.dart` pins this ordering.

Why each gate sits where it does, per the source comments:

- **Admin is resolved first, ahead of even suspension.** The role cannot be obtained
  in-app, so gating it buys no security — while a suspended admin would be locked out of
  the very console that lifts suspensions.
- **Suspension precedes verification** because verifying an email does nothing for a
  suspended account; `/suspended` is the more actionable dead end.
- **Verification only applies to password accounts.** A Google-only account holds no
  password credential, so `sendEmailVerification` would do nothing and the screen's single
  action would be a dead end.

**Both the email-verification gate and the suspension gate are in-app UX gates, not
security boundaries.** This is stated explicitly at `lib/utils/auth_routing.dart:50-55`: a
script holding the same credentials still reads and writes whatever the Firestore rules
allow. Enforcing suspension in the rules would add a `get()` on the user document to every
write in the app. What actually protects private data is the data layout — see §13.2.

### 2.4 Email verification — `lib/screens/auth/email_verification_screen.dart`

- **Auto-polls** every 3 seconds via `user.reload()`, and navigates to `/home` by itself
  once verified. Failures inside the poll are swallowed, because the poll runs precisely
  when the user has switched to their mail app and the OS has cut the connection.
- **"I've Verified — Continue"** performs the same check on demand.
- **Resend** with a **30-second cooldown**, labelled "Resend available in {n}s".
- **"Use a different account"** signs out. Note this calls `FirebaseAuth.signOut()`
  directly and therefore, unlike `AuthController.signOut()`, does **not** call
  `GoogleSignIn().signOut()`.

### 2.5 Password reset — `lib/screens/auth/forgot_password_screen.dart`

`user-not-found` is deliberately **treated as success**, and the resend cooldown (60s) is
restarted in that branch too, specifically so repeated taps cannot be timed to distinguish
a real account from a non-existent one. The success view warns explicitly: *"Signed up with
Google? No email will arrive — go back and use Continue with Google."*

### 2.6 Suspension — `lib/screens/auth/suspended_screen.dart`

A live `StreamBuilder` on the user's own document, so a reinstatement lands without the
user guessing when to retry. While loading it assumes *still suspended*. Shows the admin's
`suspendedReason` verbatim when one was given. **The only available action in either state
is sign out** — there is no appeal form and no route to any other screen.

### 2.7 Account deletion — `lib/services/account_deletion_service.dart`

Present because Google Play requires it. Requires re-authentication plus typing the word
`DELETE`. **Ordering is load-bearing:** all Firestore and Storage work happens *before*
`user.delete()`, because once the Auth account is gone `request.auth` is null and every
rule denies, which would strand the data permanently.

| Phase | What happens |
|---|---|
| Confirming it's you | Re-authenticate (password credential, or re-open the Google picker) |
| Deleting your photos | `profile_photos/{uid}/photo.jpg`, `organizer_verification/{uid}/document.jpg`, and the folders `profile_media/{uid}`, `team_logos/{uid}` |
| Deleting your activity | Subcollections `media`, `ratingHistory`, **`private`**; then `notifications where userId`, `teamMemberships` on both sides. Chunked at 400 per batch |
| Removing your profile | `_tombstone()` — a **full-document `set()`** leaving only `uid`, `role`, `deleted: true`, `deletedAt`, `fullName: 'Deleted user'` |
| Closing your account | `user.delete()` |

**What survives deletion, on purpose:** `matches`, `stats`, `events`, `tournaments` and
reports. Erasing those would destroy other players' game history and delete events other
people joined; the retained records no longer identify the person.

> **Manuscript impact.** Zero occurrences of *verification*, *suspend*, *delete* or
> *Google Sign* appear anywhere in the manuscript text. The entire authentication flow
> documented in this section is represented in the manuscript by a single Table 3.16 row
> ("Athlete login credentials → validates through Firebase Authentication → redirected to
> the Home Dashboard").

---

## 3. Onboarding flow

`lib/screens/onboarding/onboarding_screen.dart` — **4 pages** in one `PageView`
(`_sportPanelCount = 3`, `_totalPages = 4`).

| Page | Content |
|---|---|
| 1 | Basketball panel — "Every Shot Tells a Story" |
| 2 | Volleyball panel — "Rise Above The Net" |
| 3 | Badminton panel — "Precision. Speed. Grit." |
| 4 | Features page — Performance Dashboard, Talent Discovery, Game Directory |

- **Skip** appears on the three sport panels only; **Get Started** appears on the Features
  page only. Both land in the same place: `/register`.
- **Onboarding never asks which sport the user plays.** `[test]`
  `test/onboarding_screen_test.dart` — *"never asks which sport the user plays"* and
  *"writes no user_sport key"*. Sport selection belongs to registration, not the intro.
- **Onboarding records nothing itself.** `_onGetStarted()` is only a navigation call. The
  flag is set at sign-in/registration instead, because setting it here stranded anyone who
  watched the intro and then abandoned registration — the splash CTA is the only route
  back. `[test]` pins that both Skip and the intro itself *"do not mark onboarding
  complete"*.
- The flag is `SharedPreferences` key **`'onboarding_complete'`**
  (`lib/utils/onboarding_flag.dart`). `[test]` `test/utils/onboarding_flag_test.dart`
  pins the exact key name and that *"reading does not write"*.
- The only route into `/onboarding` is the splash "Get Started" CTA, plus a `kDebugMode`-only
  row in Settings.

### Splash routing decision tree — `lib/screens/splash_screen.dart`

The splash holds a **2200 ms brand moment** and resolves the destination *underneath* it
concurrently (`Future.wait`), so a fast connection waits only for the hold.

```
_restoredUser()
  ├─ FirebaseAuth.currentUser, else
  └─ authStateChanges().firstWhere(u => u != null).timeout(1200ms → null)

user == null
  └─ isOnboardingComplete()
       ├─ true  → '/login'
       └─ false → (no navigation) → show "Get Started" + "Sign in" CTAs

user != null
  ├─ markOnboardingComplete()                    [backstop]
  ├─ user.reload()        — on failure, fall back to the cached flag
  ├─ read users/{uid} → role, suspended
  │     on failure → role='', suspended=false   (an unreachable Firestore
  │                                              must not pin a user here)
  └─ landingRoute(...) → /admin | /suspended | /verify-email | /home
```

Any throw anywhere in this path resolves to the CTA state rather than stranding the user
on the splash forever.

> **Manuscript impact.** Onboarding appears once in the entire manuscript, as the phrase
> "app onboarding for athletes, coaches, and organizers" inside a maintenance table. There
> is no onboarding flow diagram and no splash/session-restore logic documented anywhere.

---

## 4. Profile system

### 4.1 Self-view vs public view are different screens

This distinction matters for the diagrams, because they are genuinely separate code paths
with different capabilities.

| | Self | Public |
|---|---|---|
| Route | `/profile` (`profile_screen.dart`) | `/profile/athlete`, `/profile/coach`, `/profile/organizer` |
| Who | The signed-in user, any role | Anyone signed in, viewing anyone |
| Media | Upload and delete | View only — the delete control is **absent**, not disabled |
| Quota counts | Shown ("3 / 20") | **Hidden** — someone else's allowance is not the viewer's business |
| Report control | No | Yes, hidden only on your own profile |
| Contact details | No | No — they are not readable by peers at all |

Additionally, **bottom-sheet variants** exist (`lib/widgets/athlete_profile_sheet.dart`,
`coach_profile_sheet.dart`) used for quick previews from Scout, the leaderboard, rosters
and event details. The athlete sheet shows a **4-item highlights teaser** (capped so a
23-item portfolio isn't downloaded to render four thumbnails) and a "View Full Profile"
button.

**Profile viewing is not sport-scoped.** Any signed-in user may open any other user's
profile regardless of role or sport; sport-scoping applies only to *recruiting actions*
(see §6).

### 4.2 Role-conditional content on the self profile

- **Athlete only** — Edit Profile + a *"Coach's view"* button that previews exactly what a
  scouting coach sees; and the entire media portfolio.
- **Coach only** — team card, roster grid, Manage Roster and Scout Players buttons.
- **Organizer only** — organization card, approval-status badge, Events Created count,
  Create Event button.

A coach's bio is **suppressed** on the profile screen (`profile_screen.dart:85`) so a
legacy `bio` value cannot render as a second bio alongside `coachingBio`. Edit Profile goes
further and actively clears it with `FieldValue.delete()` on save.

### 4.3 The media portfolio — an undocumented shipped feature

`lib/services/media_service.dart` backs photo and video highlights on athlete profiles.

| | Photos | Videos |
|---|---|---|
| Cap | 20 | 3 |
| Size cap | 5 MB | 25 MB |
| Duration | — | 60 s (with a 1500 ms grace for phones reporting 60.02 s) |
| Processing | Compressed to JPEG 1920/q80 | Transcoded with `VideoCompress` at MediumQuality |
| Storage | `profile_media/{uid}/{uuid}.jpg` | `profile_media/{uid}/{id}.mp4` + `{id}_thumb.jpg` poster frame |

Categories are a closed set: Game, Team, Tournament, Award, Training. Quota is checked
*before* the picker opens. Uploads report progress per phase ("Compressing…" /
"Uploading…").

> **Manuscript impact.** The media portfolio appears nowhere in the manuscript — not in
> the Class Diagram, not in the Database Design, not in the feature scope.

---

## 5. Admin console — entirely undocumented

Route `/admin` → `lib/screens/admin/admin_shell_screen.dart`, a **five-tab** console over
an `IndexedStack` (so each tab keeps its listeners and scroll position).

| Tab | Screen | What it does |
|---|---|---|
| Overview | `admin_overview_screen.dart` | Ten parallel `count()` aggregations; pending-approvals card; attention rows shown only when non-zero; recent activity feed |
| Users | `admin_users_screen.dart` → `admin_user_detail_screen.dart` | Account directory with role filter and client-side search; suspend / reinstate |
| Content | `admin_content_screen.dart` | Events and Tournaments; **cancel only, never delete** |
| Reports | `admin_reports_screen.dart` | Moderation queue — Open / Closed, Resolve or Dismiss |
| Approvals | `admin_review_screen.dart` | Organizer verification — Approve / Reject / Revoke / Restore |

### 5.1 What an admin may write is deliberately narrow

The **security rules, not the UI, are the boundary.** Across another user's document an
admin can change exactly two things:

| Target | Permitted keys | Rule |
|---|---|---|
| Another user | `organizerStatus` | `firestore.rules:72-75` |
| Another user | `suspended`, `suspendedAt`, `suspendedReason` | `firestore.rules:88-91` |
| An event | `status` (in practice, cancelling) | `firestore.rules:154-156` |
| A tournament | `status` | `firestore.rules:287-289` |
| A report | `status`, `resolvedBy`, `resolvedAt` | `firestore.rules:357-360` |

Everything else — roles, profile fields, stats, another user's notifications or rating
history — is denied to an admin exactly as it is to anyone else. The approval rule and the
suspension rule are kept as **two separate rules** rather than one widened key list, so the
approval path retains its narrow guarantee.

### 5.2 Three structural decisions worth documenting

1. **There is no admin-side account deletion.** Without Cloud Functions the app cannot
   remove a Firebase Auth account, and deleting only the Firestore document would leave a
   working login attached to nothing. Real removal is an operator task via
   `functions/scripts/purge-orphaned-profiles.js`.
2. **Admins cannot be suspended from the console.** The UI replaces the button with an
   explanatory note: an admin who could be locked out would have no way back into the
   console, since lifting a suspension happens on that very screen.
3. **Resolving a report is not the same act as punishing the person.** Suspension is a
   separate, explicit decision made on the account's own screen. Bundling them would make
   it far too easy to suspend someone as a side effect of tidying a list.

### 5.3 Reports — the moderation subsystem

`reports/{reportId}`, filed from one shared sheet (`showReportDialog` in
`lib/widgets/report_dialog.dart`) reachable from all three public profile screens and from
event detail. Reasons are a closed list (`lib/models/report.dart:53-60`): fake/impersonated
account, harassment, inappropriate content, spam/scam, misleading information, something
else.

The collection is **effectively write-only for ordinary users**: they may create a report
attributed to themselves and read back only their own, so nobody but the admin can see the
queue or learn who reported whom (`firestore.rules:349-352`). Nothing deletes a report — a
dismissed one stays on the Closed tab as the record that somebody looked at it and decided.

### 5.4 Organizer approval — the gate that actually enforces itself

An organizer registers with `organizerStatus: 'pending'` and **cannot create events until
an admin approves them.** This is enforced in the rules, not the UI:
`firestore.rules:25-29` (`isApprovedOrganizer`) gates event creation, tournament creation,
and cross-user points/ratings writes.

The verification document is fetched with `getData(10 MB)` rather than `getDownloadURL()`
on purpose (`lib/services/storage_service.dart:67-73`): a download URL is a token-bearing
public link that bypasses Storage rules for anyone who obtains it, which is wrong for a
document that may contain a government ID.

> **Manuscript impact.** None of §5 exists in the manuscript. There is no admin actor, no
> approval workflow, no moderation queue and no `reports` collection in any figure or
> table.

---

## 6. Feature matrix by role

Legend: ● full access · ◐ partial/conditional · ○ none.

| Feature | Athlete | Coach | Organizer | Admin |
|---|:--:|:--:|:--:|:--:|
| Home dashboard | ● | ● | ● | ○ (lands on `/admin`) |
| Notification bell | ● | ● | ● | ○ (never reaches `/home`) |
| Performance dashboard | ● | ○ | ○ | ○ |
| Leaderboard | ● | ● | ● | ○ |
| Scout (search athletes) | ○ | ◐ only their own sports | ○ | ○ |
| Venue locator / Game Directory | ● | ● | ● | ○ |
| Media portfolio (upload) | ● | ○ | ○ | ○ |
| View any profile | ● | ● | ● | ● |
| Report a user or event | ● | ● | ● | n/a |
| Receive team invite | ● | ○ | ○ | ○ |
| Send team invite | ○ | ◐ same-sport only | ○ | ○ |
| Manage roster | ○ | ● | ○ | ○ |
| Create/edit event | ○ | ○ | ◐ **approved only** | ○ |
| Create tournament / bracket | ○ | ○ | ◐ **approved only** | ○ |
| Record match result | ○ | ○ | ● own events | ○ |
| Submit game statistics | ○ | ○ | ● own events | ○ |
| Cancel event / tournament | ○ | ○ | ● own | ● any (status only) |
| Suspend / reinstate account | ○ | ○ | ○ | ● |
| Approve / revoke organizer | ○ | ○ | ○ | ● |
| Resolve reports | ○ | ○ | ○ | ● |

**Two rows are the most important corrections for the manuscript:** *Submit game statistics*
belongs to the **Organizer**, not the Athlete (`lib/screens/stats/add_stats_screen.dart`
queries `events where organizerId == currentUid` — an athlete has no path to self-report
anywhere in the app), and *Record match result* is a **separate Organizer use case** that
does not exist in the manuscript at all.

---

## 7. Screens and routes that currently exist

All routes are declared as named `GetPage`s in [lib/main.dart:194-234](../lib/main.dart#L194-L234).
**35 named routes**, plus two screens reached by direct push.

| # | Route | Screen file | Reached by | Arguments |
|---|---|---|---|---|
| 1 | `/splash` | `screens/splash_screen.dart` | app launch (`initialRoute`) | — |
| 2 | `/onboarding` | `screens/onboarding/onboarding_screen.dart` | splash CTA | — |
| 3 | `/login` | `screens/auth/login_screen.dart` | splash, sign-out | — |
| 4 | `/verify-email` | `screens/auth/email_verification_screen.dart` | `landingRoute` gate | — |
| 5 | `/suspended` | `screens/auth/suspended_screen.dart` | `landingRoute` gate | — |
| 6 | `/google-profile-setup` | `screens/auth/google_profile_setup_screen.dart` | first Google sign-in | — |
| 7 | `/forgot-password` | `screens/auth/forgot_password_screen.dart` | login link | — |
| 8 | `/register` | `screens/auth/register_screen.dart` | onboarding, login link | — |
| 9 | `/register/athlete` | `screens/auth/athlete_register_screen.dart` | role picker | — |
| 10 | `/register/coach` | `screens/auth/coach_register_screen.dart` | role picker | — |
| 11 | `/register/organizer` | `screens/auth/organizer_register_screen.dart` | role picker | — |
| 12 | `/home` | `screens/home/home_screen.dart` | `landingRoute` | — |
| 13 | `/events` | `screens/events/my_events_screen.dart` | organizer nav tab 2 | — |
| 14 | `/events/create` | `screens/events/create_event_screen.dart` | home, my events | — |
| 15 | `/events/detail` | `screens/events/event_detail_screen.dart` | lists, notifications, reminders | `{eventId}` |
| 16 | `/events/edit` | `screens/events/edit_event_screen.dart` | event detail (organizer) | `{eventId}` |
| 17 | `/events/edit-teams` | `screens/events/edit_teams_screen.dart` | event detail (organizer) | `{eventId}` |
| 18 | `/matches/record` | `screens/events/record_match_screen.dart` | event detail, bracket, home | `{eventId}` optional |
| 19 | `/stats/add` | `screens/stats/add_stats_screen.dart` | organizer nav tab 1 | — |
| 20 | `/tournaments` | `screens/tournaments/tournament_list_screen.dart` | home "View All" | — |
| 21 | `/tournaments/create` | `screens/tournaments/create_tournament_screen.dart` | tournament list | — |
| 22 | `/tournaments/detail` | `screens/tournaments/tournament_bracket_screen.dart` | list, home, event detail | `{tournamentId}` |
| 23 | `/leaderboard` | `screens/leaderboard/leaderboard_screen.dart` | nav tab 2 (athlete/coach) | — |
| 24 | `/dashboard` | `screens/dashboard/performance_dashboard_screen.dart` | nav tab 1 (athlete) | — |
| 25 | `/scout` | `screens/scout/scout_screen.dart` | nav tab 1 (coach) | — |
| 26 | `/venues` | `screens/venues/venue_locator_screen.dart` | **nav tab 3, all roles** | — |
| 27 | `/profile` | `screens/profile/profile_screen.dart` | nav tab 4 | — |
| 28 | `/profile/athlete` | `screens/profile/athlete_profile_view_screen.dart` | sheets, leaderboard | `{athleteId}` |
| 29 | `/profile/coach` | `screens/profile/coach_profile_view_screen.dart` | invite card, team views | `{coachId}` |
| 30 | `/profile/organizer` | `screens/profile/organizer_profile_view_screen.dart` | event byline | `{organizerId}` |
| 31 | `/team/invites` | `screens/team/team_invites_screen.dart` | home, notifications | `{inviteId}` optional |
| 32 | `/team/roster` | `screens/team/my_team_screen.dart` | coach profile, home | — |
| 33 | `/team/mine` | `screens/team/athlete_team_screen.dart` | home team deck | `{coachId, coachName, teamName}` |
| 34 | `/admin` | `screens/admin/admin_shell_screen.dart` | `landingRoute` (admin only) | — |
| 35 | `/account/delete` | `screens/settings/delete_account_screen.dart` | settings link | — |

**Not named routes** — pushed directly:
- `SettingsScreen` (`screens/settings/settings_screen.dart`) — `Get.to()` from the gear icon on `/profile`.
- `VenueMapPickerScreen` (`screens/events/venue_map_picker_screen.dart`) — `Navigator.push<Venue>` from create-event, edit-event and create-tournament.

**Inside `/admin`**, five tab screens live in an `IndexedStack` with no routes of their own:
`admin_overview_screen.dart`, `admin_users_screen.dart`, `admin_content_screen.dart`,
`admin_reports_screen.dart`, `admin_review_screen.dart`, plus `admin_user_detail_screen.dart`
pushed from the Users tab.

> **There is no route-level role guard anywhere.** No GetX middleware is registered on any
> page. Role restriction is achieved three other ways: which navigation item is drawn, a
> blocking screen inside the destination (e.g. create-event's approval gate), or an empty
> query result. The real boundary is `firestore.rules`. This is worth stating in the
> manuscript rather than drawing the diagram as though the router enforces roles.

### Bottom navigation differs per role

`lib/screens/home/home_screen.dart:1990-2017` — five tabs, of which only 0, 3 and 4 are shared.

| Index | Athlete | Coach | Organizer |
|---|---|---|---|
| 0 | Home | Home | Home |
| 1 | **Stats** → `/dashboard` | **Scout** → `/scout` | **Add Stats** → `/stats/add` |
| 2 | **Rankings** → `/leaderboard` | **Rankings** → `/leaderboard` | **Events** → `/events` |
| 3 | Games → `/venues` | Games → `/venues` | Venues → `/venues` |
| 4 | Profile | Profile | Profile |

---

## 8. Athlete workflow

```
Register (3 steps) → verify email → Home
     │
     ├─ Home: points hero + city rank, My Team deck, Recent Activity, Upcoming Games
     ├─ Receive team invite  → /team/invites → Accept/Decline → /team/mine
     ├─ Organizer adds them to an event (no self-registration)
     ├─ Local OS reminder fires 18:00 the night before, and 1 hour before
     ├─ Organizer records the match result, then submits per-player stats
     │      └─ athlete receives a `stats_added` notification, points increase
     ├─ /dashboard: points, city rank, games, chart of last 6 games, game history
     ├─ /leaderboard: city ranking by points (All) or Elo rating (per sport)
     ├─ /profile: upload up to 3 videos and 20 photos; "Coach's view" preview
     └─ /venues: browse upcoming public events on a map, get driving directions
```

**The athlete is a passive participant in every data-producing flow.** They cannot create an
event, join an event, submit a statistic, or record a result. What they control is their
profile, their media portfolio, their recruitment flag, and whether to accept a team invite.

Key screens: `home_screen.dart`, `performance_dashboard_screen.dart`,
`leaderboard_screen.dart`, `profile_screen.dart`, `team_invites_screen.dart`,
`athlete_team_screen.dart`, `venue_locator_screen.dart`.

---

## 9. Coach / scouting workflow

```
Register (single sport) → verify email → Home
     │
     ├─ /scout: browse athletes whose primarySports overlap the coach's own
     │     ├─ filter: sport tab · skill sort · "Open to Recruitment only" · name search
     │     └─ tap athlete → profile sheet → **Invite to Team**
     │            └─ TeamService.sendInvite → athlete gets `team_invite` notification
     ├─ /team/roster: rename team, upload team logo, remove players, cancel invites
     ├─ Organizer picks the coach's team into an event or a tournament entrant
     │     └─ coach gets `event_added`: "Your team has an upcoming game"
     └─ /leaderboard: header reads "TAP ATHLETE TO SCOUT"; rows gain a recruitment line
```

### Scout is strictly sport-scoped — three enforcement layers

1. **Query** — `users where role == 'athlete' where primarySports arrayContainsAny <coachSports>`
   (`lib/screens/scout/scout_screen.dart:184-204`). "All Sports" means *all of the sports I
   coach*, never every sport in the app.
2. **Service** — `TeamService.sendInvite` throws `SportMismatchException` unless
   `sportsOverlap(coachSports, athleteSports)`.
3. **Rules** — `firestore.rules:219-223` requires
   `userData(coach).primarySports.hasAny(userData(athlete).primarySports)`.

`[test]` `test/utils/sports_test.dart` pins that overlap (not equality) is the rule, and that
**an empty sport list on either side matches nobody** — the safe direction, so a coach who
has not set their sports scouts no one rather than everyone.

A coach with no sports set gets a blocking empty state: *"Choose the sports you coach."*

### Ranking inside Scout

Default sort is lifetime `points` descending, with **ties sharing a rank** and zero-point
athletes marked unranked (`'—'`). Selecting a skill chip re-sorts by that skill's average
from the `stats` collection; athletes with no data for that skill fall below a divider
reading *"No <skill> stats yet · N"* **with no rank number at all**.

`kScoutSkills` (`lib/utils/stat_scoring.dart:116-136`) deliberately **excludes basketball
turnovers** — the sort is highest-first, so offering it would rank the most careless
ball-handlers at the top. `[test]` `test/utils/stats_view_test.dart` pins this exclusion.

### The invite lifecycle — this replaces "Add to Roster"

One document, `teamMemberships/{coachId}_{athleteId}`, is **both the invite and the
membership**. There is no separate roster collection.

```
Coach taps Invite
   → sportsOverlap check          (else SportMismatchException)
   → already accepted?            (no-op)
   → athlete already on a team in this sport?  (else AlreadyOnTeamException)
   → coach roster >= 15?          (else TeamFullException)
   → write {status: 'pending'} + `team_invite` notification
Athlete opens /team/invites
   → Accept  → re-check one-team-per-sport and roster cap → {status: 'accepted'}
   │             └─ if roster now full, every OTHER pending invitee gets `team_full`
   └─ Decline → delete the document
```

Decline, cancel, remove and leave are **all the same delete** (`team_service.dart:198-208`).
Roster cap is **15** (`TeamService.maxPlayers`). An athlete may hold **one team per sport**,
re-checked at both send and accept because two coaches can invite before either is answered.

> **Manuscript impact.** Figure 5's "Add to Roster" as a unilateral Coach action is wrong,
> and Table 3.28's "Crew Collection" (`crewID`, `crewName`, `roster` array) does not exist.
> The real shape is one document per coach–athlete pair, with the composite key as its id.

---

## 10. Organizer / event and tournament workflow

### 10.1 The approval gate comes first

An organizer registers with `organizerStatus: 'pending'` and **can do nothing** until an
admin approves them. Both `CreateEventScreen` and `CreateTournamentScreen` render a
full-screen block before any form appears (`create_event_screen.dart:1002-1025`):

1. `organizerStatus != 'approved'` → *"Your organizer account isn't currently approved."*
   No way forward.
2. `sportsOrganized.isEmpty` → *"You haven't set which sports you organize yet"* + an
   "Update My Sports" button.

Event creation is additionally **restricted to the organizer's declared sports** — the sport
chips are drawn from `sportsOrganized`, and the rules enforce approval independently
(`firestore.rules:139-141`).

### 10.2 Create Event — 3 steps

| Step | Contents |
|---|---|
| 1 — Event Info + Schedule & Venue | Name (required), Description, **Sport** (from `sportsOrganized`), **Event Type** (Tournament / Friendly / League), **Date** (required), **Time** (optional, defaults 00:00), **Venue** (required) |
| 2 — Teams & Players | Pick **Team A** and **Team B** from coaches whose `primarySports` contains the event sport; each pick pulls that coach's accepted roster in whole; players can be removed individually |
| 3 — Review & Publish | Read-back of every field, the full player list, a Public/Private toggle, then **Publish Event** or **Save as Draft** |

Changing the sport after teams are picked prompts *"Switch to <sport>? This clears the teams
and players you've picked."*

**Venue selection is live, not a stored catalogue** — see §11.

**On publish**, one `WriteBatch` writes `events/{uuid}` plus one `event_added` notification
per rostered player and one per head coach (deduplicated, so a coach on both sides gets one).
Drafts write the event only — `if (!draft)` guards the whole notification block.

**There is no join, RSVP or self-registration anywhere in the app.** Rosters are assembled
exclusively by the organizer from coach teams. A repo-wide search for
`rsvp|joinEvent|registerForEvent` returns nothing. `maxPlayers` is written as `null` at
creation, can only be set later in Edit Event, and **nothing validates the roster against
it** — it is a display-only cap.

### 10.3 Editing, cancelling, deleting

- **Edit Event** — a single form, not a wizard. The **sport is locked once any player is
  assigned**, because per-sport Elo has already been written under that sport key. Saving
  notifies the whole audience with `event_updated`. The roster is never touched here.
- **Edit Teams** — names the two sides and assigns each player A or B. Both Add Stats and
  Record Match read that `team` field. No notification.
- **Danger zone** (`event_detail_screen.dart:421-465`) resolves to exactly one of three:
  any finalized match → *"This game has recorded results and can't be cancelled or
  deleted"*; matches exist but none finalized → **Cancel Event**; no matches → **Delete
  Event**. Hidden entirely for bracket matches.

### 10.4 Record Match → Submit Stats → Elo (the chain that matters)

This two-stage chain is the single most under-documented mechanism in the app.

```
1. RECORD MATCH  (/matches/record, organizer only)
   picks an event → assigns each player to side A or B → enters both scores
   (scoreA != scoreB enforced; none of the three sports draw)
        │
        └─► writes matches/{autoId} with status: 'pending'
            sets events/{eventId}.hasMatchData = true
            ✗ no notification, ✗ no rating change yet

2. SUBMIT STATS  (/stats/add, organizer only, one athlete at a time)
   picks event → team → player → per-sport stat fields
   optional dropdown: "Link to Match"  ◄── THE CRITICAL STEP
        │
        └─► writes stats/{uuid}
            users/{athleteId}.points += pointsAwarded
            `stats_added` notification to the athlete
            then: if matchId was linked AND every participant now has a stats doc
                     → RatingService.finalizeMatch(matchId)

3. FINALIZE (automatic, inside one transaction)
        └─► per-sport Elo recalculated for every participant
            users/{uid}.ratings.<sport> updated
            users/{uid}/ratingHistory/{matchId} written
            matches/{matchId}.status = 'finalized'
```

**Elo therefore never runs unless the organizer uses the optional "Link to Match" dropdown
for every single participant.** Miss one player and the match stays `'pending'` forever and
no rating ever moves. There is no Cloud Function, no retry and no other trigger.

### 10.5 The two scoring systems are different and must not be conflated

| | Homegrown Points | Match Rating (Elo/MMR) |
|---|---|---|
| Stored at | `users/{uid}.points` (single int) | `users/{uid}.ratings.<sport>` (map) |
| Produced by | Every stats submission | Only a finalized match |
| Scope | Lifetime cumulative, all sports | Per sport |
| Starting value | 0 | **1000** (`kStartingRating`) |
| Drives | City Rank, leaderboard "All" tab, Scout default sort | Leaderboard per-sport tabs |
| History | none | `users/{uid}/ratingHistory/{matchId}` |

**Points formula** (`lib/utils/stat_scoring.dart:9-39`), clamped to ≥ 0 and rounded:

```
Basketball: points×1.0 + assists×1.5 + rebounds×1.0 + steals×2.0 + blocks×2.0 − turnovers×1.0
Volleyball: kills×2.0 + aces×2.0 + assists×1.0 + digs×1.0 + blocks×2.0
Badminton : (matchWon ? 10.0 : 0) + setsWon×3.0 + pointsScored×0.5
```

`[test]` `test/utils/stat_scoring_test.dart` pins each formula, the match-won bonus, the
clamp to zero, that missing fields count as zero, and that an unrecognised sport returns 0.

**Elo formula** (`lib/utils/elo_calculator.dart`): K factor **32**, floor **100**, expectation
from each side's *average* rating, and an individual multiplier bounded to **±30%** based on
how that player's Homegrown points compare to their own side's average for that game.

### 10.6 Tournaments — single-elimination brackets

4 to 16 entrants (`Tournament.minEntrants` / `maxEntrants`). Entrants are coach teams, seeded
in list order; **each entrant carries a frozen roster snapshot** so a mid-tournament roster
change cannot rewrite a semifinal teamsheet.

`generateBracket` (`lib/utils/bracket.dart`) builds every slot of every round up front using
classic recursive seeding (`[1,8,4,5,2,7,3,6]` for 8), so seeds 1 and 2 can only meet in the
final. Byes are resolved in the same pass. `[test]` `test/utils/bracket_test.dart`.

Slot lifecycle: `awaiting → ready → scheduled → completed` (or `bye`). Scheduling a ready
slot **spawns a real `events/{id}` document** carrying `tournamentId` and `tournamentSlotId`
back-pointers, and notifies both rosters. Recording that match stages the result *and* the
bracket advance onto **one batch**, so the bracket can never disagree with the recorded
match.

Two protections are enforced in rules rather than UI: a slot whose status is `completed` or
`bye` **can never be updated** (closing the double-record race), and a bracket's child event
**cannot be deleted** (`!('tournamentId' in resource.data)`).

> **Manuscript impact.** Tournaments exist in the manuscript only as Table 3.24, with a
> `date` and a `venueID` that the real collection does not have. The entire bracket
> subsystem — `tournaments/{id}/slots`, seeding, byes, advancement, champion — is absent.

---

## 11. Venue locator workflow

### 11.1 The screen is titled "Game Directory" and plots events, not venues

`lib/screens/venues/venue_locator_screen.dart` — subtitle *"Legazpi City · Upcoming events"*.

**This is the single most misdescribed feature in the manuscript.** What it actually does:

```
open  → Firestore: events where status == 'upcoming' AND isPublic == true, limit 200
      → client filter: isEventUpcoming()  (drops cancelled and past)
      → plot one marker per event at its stored venueLat/venueLng
      → sport filter chips: All / Basketball / Volleyball / Badminton
tap a marker or list row
      → bottom sheet: venue, address, date & time, "N on the roster"
      → **Get Directions**
             → NOW read GPS via Geolocator
             → Google Directions API (origin = device, destination = venue)
             → draw polyline, show distance + duration
```

Three specific corrections follow from this:

1. **There is no proximity or "nearby venues" search.** Every upcoming public event loads
   regardless of distance. No haversine, no radius query, no distance sort anywhere.
2. **GPS is used only as the origin of a directions request** — never to find or rank
   venues. `_startLocationUpdates()` deliberately does not call `setState`; the position is
   read on demand inside `_getDirections`.
3. **There is no venue availability of any kind.** `lib/models/venue.dart` has exactly four
   fields plus a type; a repo-wide search for `availability` returns nothing.

There is also **no text search** on this screen — only the four sport chips.

Distance and duration exist **only after** a successful Directions call; there is no
straight-line distance anywhere in the app.

### 11.2 Venue data is resolved live and inlined — there is no Venues collection

```
Create Event / Edit Event               Create Tournament
        │                                       │
   type ≥3 chars                                │
        │ (400ms debounce)                      │
        ▼                                       │
  Places API (New) Text Search                  │
  POST places:searchText                        │
  biased to Legazpi, radius 15km                │
        │                                       │
        ├── found → pick a result               │
        └── "Can't find it? Drop a pin" ────────┴──► VenueMapPickerScreen
                                                       tap map (500ms debounce)
                                                       → Geocoding API reverse lookup
                                                       → prefill an editable name
                                                            │
                                                            ▼
                                        Venue{name, address, lat, lng, type}
                                                            │
                                     inlined onto the event/tournament document as
                                venue, venueAddress, venueLat, venueLng, venueType
```

The manual pin fallback exists because informal barangay courts are precisely the venues
Google does not index. This replaced an earlier hand-typed `kLegazpiVenues` list whose
guessed coordinates proved unreliable — a mid-city venue was off by hundreds of metres, and
free-text geocoding of small local venues by name produced results hundreds of kilometres
wrong.

**Consequence for the ERD: there is no `venueID` foreign key anywhere, because there is
nothing to point at.** An event whose coordinates are missing falls back to the city centre
(`13.1391, 123.7438`), which the list tile marks with a small green GPS icon.

> **Manuscript impact.** Table 3.23 `Venues Collection` (with `venueID`, `sportType`,
> `availability`) does not exist. Figure 7's GPS steps ("Get Device GPS Coordinates →
> Request Nearby Venues via GPS") describe a proximity search the app does not perform.
> Scope & Delimitation and Chapter 4 both promise real-time court availability, which is
> not implemented.

---

## 12. Data flow: Flutter → Firebase Auth → Firestore → Storage → Google APIs

### 12.1 There is no application server

Every call is made from the device. `functions/` is scaffolded but **exports nothing** —
`functions/src/index.ts` is an `initializeApp()` and a commented-out example. The
`cloud_functions` package is declared in `pubspec.yaml` but never imported anywhere in
`lib/`. Confirmed three ways: zero exports in the TypeScript source, no `FirebaseFunctions`
import anywhere, and `README.md:111-113` stating it plainly.

```
┌──────────────────────── Flutter (Android) ────────────────────────┐
│  GetX: controllers → services → models                            │
│  ConnectivityService · ThemeController · AuthController (global)  │
└───┬──────────────┬──────────────┬───────────────┬─────────────────┘
    │              │              │               │
    ▼              ▼              ▼               ▼
┌────────┐   ┌───────────┐   ┌─────────┐   ┌──────────────────────┐
│Firebase│   │   Cloud   │   │ Firebase│   │ Google Maps Platform │
│  Auth  │   │ Firestore │   │ Storage │   │  (called DIRECTLY,   │
│        │   │           │   │         │   │   not via Firebase)  │
│email/pw│   │8 top-level│   │4 path   │   │ Places (New) · Geo-  │
│ Google │   │+4 sub-    │   │prefixes │   │ coding · Directions  │
│        │   │collections│   │         │   │ · Maps SDK Android   │
└────────┘   └───────────┘   └─────────┘   └──────────────────────┘
    │                                              │
    │                                       ┌──────────────┐
    ▼ (one-way, fire-and-forget)            │ PSGC registry│ ← barangay list
┌──────────────┐                            │ (non-Google) │
│  Crashlytics │                            └──────────────┘
└──────────────┘
```

**Two separate Google API keys**, a detail the architecture diagram should show:

| Key | Supplied via | Used by | Restricted to |
|---|---|---|---|
| Web services | `dart_defines.json` → `--dart-define=MAPS_API_KEY` | Places, Geocoding, Directions | those three APIs + daily quota caps |
| Maps SDK for Android | `android/local.properties` → Gradle manifest placeholder | the `GoogleMap` widget | Android package name + signing certificate |

Both files are gitignored. The web-services key ships inside the APK and can be extracted;
what actually bounds the damage is the server-side API restriction and quota cap. Moving
these calls behind a Cloud Function is the stated durable fix, and is why `functions/`
exists at all.

### 12.2 Cost control is entirely client-side

Because there is no backend, every ceiling lives in the app. This is a genuine architectural
theme worth a paragraph in the manuscript:

- `kMaxListQuery = 100`, `kMaxMapQuery = 200` (`lib/constants/query_limits.dart`) — Firestore
  bills per document read.
- `count()` aggregations instead of document fetches: `RankingService.cityRank`,
  `AdminStatsService` (10 parallel counts), `TeamService.rosterCountFor`, `MediaService.countOf`.
- `ApiCache` (`lib/services/api_cache.dart`) — a bespoke in-memory LRU+TTL cache, max 50
  entries, process-lifetime only. **Only successful responses are cached**; caching a failure
  would turn one transient blip into minutes of a falsely broken venue search.

| Service | TTL | Cache key |
|---|---|---|
| Places | 30 min | lowercased, trimmed query |
| Geocoding | 1 hour | lat/lng rounded to 4 dp (≈ 11 m) |
| Directions | 30 min | origin→destination, both at 4 dp |

- Debouncing (400 ms search, 500 ms geocode) and a 3-character minimum query, so keystrokes
  do not each become a billable request.
- Media quotas and pre-upload compression, since Storage bills for what is stored *and*
  again for every download.

### 12.3 Denormalisation map — important for the ERD

Data is deliberately copied across documents in seven places. An ERD drawn purely from
foreign keys will miss these.

| From → To | Copied field(s) | Reason |
|---|---|---|
| `matches` → `events` | `hasMatchData: true` | The delete rule cannot cheaply ask "does any document reference this event" |
| `slots` → `tournaments` | `hasMatchData: true` | Same |
| `tournaments` → `slots` | `organizerId` | A rules `get()` sees pre-batch state, and a batch allows only 20 document accesses |
| `users` → `teamMemberships` | `athleteName`, `athletePhotoUrl`, `coachName`, `teamName` | Invite-time snapshot; live identity is re-read separately |
| `users` → `tournaments.entrants[].players` | `fullName`, `position` | Frozen roster so a bracket stays stable for its whole run |
| `events` → `stats` | `eventName`, `venue`, `eventDate` | The stats row reads on its own without a join |
| target → `reports` | `targetLabel` | The queue must still name a target that has since been deleted |

### 12.4 Batches and transactions

- **`WriteBatch` threading** — `NotificationService.create` and `RatingService.recordMatch`
  both accept an optional batch, so a notification can never exist if the write it describes
  failed. `TournamentService.stageAdvance` is staged and not committed, so the bracket
  advance lands in the very same commit as the match result.
- **`runTransaction`** is used in exactly one place: `RatingService.finalizeMatch`, which
  reads every participant's current rating, computes the Elo update, writes each new rating
  and history entry, and flips the match to `'finalized'`.

---

## 13. Firestore data model — the ERD source of truth

**8 top-level collections + 4 subcollections.** The default-deny catch-all at
`firestore.rules:369-371` (`match /{document=**} { allow read, write: if false; }`) confirms
nothing else exists — a collection not enumerated below is unreachable.

```
users/{uid}
  ├── private/contact          (email, phone — owner + admin only)
  ├── media/{mediaId}          (portfolio photos and videos)
  ├── ratingHistory/{matchId}  (Elo audit trail, owner-readable)
  └── achievements/{id}        ⚠ MODELLED ONLY — no rule, no reader, no writer
events/{eventId}
matches/{matchId}
stats/{statId}
teamMemberships/{coachId}_{athleteId}
notifications/{autoId}
tournaments/{tournamentId}
  └── slots/r{round}m{slot}    (the bracket)
reports/{reportId}
```

### 13.1 Relationship summary for the ERD

| From | To | Cardinality | Via |
|---|---|---|---|
| `users` (organizer) | `events` | 1 → 0..* | `events.organizerId` |
| `users` (athlete) | `events` | 0..* ↔ 0..* | `events.playerUids[]`, `events.players[]` |
| `users` (coach) | `events` | 0..* ↔ 0..* | `events.teamACoachId` / `teamBCoachId` |
| `events` | `matches` | 1 → 0..* | `matches.eventId` |
| `events` | `stats` | 1 → 0..* | `stats.eventId` |
| `users` (athlete) | `stats` | 1 → 0..* | `stats.athleteId` |
| `matches` | `stats` | 0..1 → 0..* | `stats.matchId` (**optional**) |
| `matches` | `ratingHistory` | 1 → 0..* | subcollection doc id **is** the matchId |
| `users` (coach) ↔ `users` (athlete) | `teamMemberships` | 0..* ↔ 0..* | composite document id |
| `tournaments` | `slots` | 1 → 0..* | subcollection |
| `tournaments` | `events` | 1 → 0..* | `events.tournamentId` (bracket children only) |
| `slots` | `events` | 0..1 → 0..1 | `slots.eventId` |
| `slots` | `matches` | 0..1 → 0..1 | `slots.matchId` |
| `users` | `notifications` | 1 → 0..* | `notifications.userId` (recipient) |
| `users` | `reports` | 1 → 0..* | `reports.reporterUid` |

Note especially: **a `MatchResult` is not required to belong to a Tournament** (only bracket
play links one), and **a stat's link to a match is optional** — which is exactly why Elo can
silently never fire (§10.4).

### 13.2 `users/{uid}`

**Readable by every signed-in account.** This is deliberate and load-bearing: leaderboards,
Scout, rosters and profile sheets all legitimately show a stranger's name, role, sport and
barangay, and Firestore read rules are **document-level** — there is no way to serve some
fields and withhold others. Contact details therefore live in a subcollection.

> **Never add `email`, `phoneNumber` or anything private to this document.** Anything placed
> here is visible to the entire signed-in population.

| Group | Fields |
|---|---|
| Common | `uid`, `firstName`, `lastName`, `fullName`, `role`, `barangay`, `photoUrl`, `createdAt` |
| Athlete & Coach | `primarySports` (array) |
| Athlete only | `position`, `yearsOfPlaying`, `heightCm` *(string)*, `weightKg` *(string)*, `bio`, `isPublic`, `openToRecruitment`, `points` (int), `ratings` (map sport→int) |
| Coach only | `coachingLevel`, `yearsOfExperience`, `teamOrganization`, `coachingBio`, `teamLogoUrl` |
| Organizer only | `organizerStatus`, `organization`, `organizationType`, `sportsOrganized` (array) |
| Coach & Organizer | `certifications` |
| Athlete & Organizer | `bio` |
| Added later | `authProvider`, `updatedAt`, `suspended`, `suspendedAt`, `suspendedReason`, `deleted`, `deletedAt` |
| Legacy | `email`, `phoneNumber` (migrating out), `profileImageUrl` (superseded by `photoUrl`), `teamName` (**read in two places, never written**) |

**No `password` field exists.** Firebase Authentication owns credentials; Firestore never
sees one. Table 3.18 must drop it.

**Four fields are stored as free-text strings rather than numbers** — `heightCm`, `weightKg`,
`yearsOfPlaying`, `yearsOfExperience` — because their forms collect open text. Worth
flagging to the panel as something to tighten.

**Account deletion is a full-document overwrite**, not a flag: `_tombstone()` replaces the
whole document with only `uid`, `role`, `deleted: true`, `deletedAt`, and
`fullName: 'Deleted user'`. Every other field is gone, not hidden.

**Write permissions** — one self rule and three narrowly field-restricted cross-user rules:

| Who | May change |
|---|---|
| Self | anything, provided `role` is unchanged (or `''` → a real role, once) |
| Approved organizer, on another user | `points`, `ratings` **only** |
| Admin, on another user | `organizerStatus` **only** |
| Admin, on another user | `suspended`, `suspendedAt`, `suspendedReason` **only** |

### 13.3 `users/{uid}/private/contact`

`email`, `phoneNumber`, `updatedAt`. Read: **owner or super-admin only** (the admin needs an
applicant's contact details to vet an organizer application). Write: owner only — the admin
reviews these, never edits them. Written by all three registration screens (email alone for
athletes and coaches; email **plus phone** for organizers), by Google profile setup, and read
only by the two admin screens.

### 13.4 `users/{uid}/media/{mediaId}`

`type`, `url`, `thumbnailUrl`, `category`, `caption`, `sizeBytes`, `durationSeconds`
*(videos only — the key is omitted entirely for a photo)*, `createdAt`. Read: any signed-in
user. Write: owner only. Quotas are app-side because Firestore rules cannot count a
subcollection.

### 13.5 `users/{uid}/ratingHistory/{matchId}`

`matchId`, `sport`, `oldRating`, `newRating`, `delta`, `result` (`'win'`/`'loss'`),
`createdAt`. The **document id is the match id**, so a re-finalize overwrites rather than
duplicates. Read: **owner only** — unlike `media`. Write: approved organizers, self-writes
deliberately excluded. Delete: owner only, so account deletion can clear it.

### 13.6 `events/{eventId}`

`eventId` *(must equal the document id — the `matches` and `stats` rules read it back)*,
`organizerId`, `name`, `description`, `sport`, `eventType`, `venue`, `venueAddress`,
`venueLat`, `venueLng`, `venueType`, `eventDate`, `teamAName`, `teamBName`, `players[]`
*(each `{uid, fullName, position, team}`)*, `playerUids[]`, `playerCount`, `maxPlayers`
*(**always written as `null`** — reserved, never populated)*, `isPublic`, `teamACoachId`,
`teamBCoachId`, `status`, `createdAt`, `hasMatchData` *(added later)*, `tournamentId`?,
`tournamentSlotId`?.

> **`status` is only ever written once at creation and is never updated when a game
> finishes.** It cannot be used to ask "is this game done". `isEventUpcoming()` in
> `lib/utils/firestore_helpers.dart:51` is the single source of truth, keyed off `eventDate`,
> with `'cancelled'` as the one status that overrides the date.

This collection replaces both Table 3.25 (`GameSchedule`) and Table 3.26 (`Participants`) —
a game's date and its roster are fields on this one document.

### 13.7 `matches/{matchId}`

`eventId`, `sport`, `sideA[]`, `sideB[]`, `scoreA`, `scoreB`, `winner`, `status`
(`'pending'`/`'finalized'`), `recordedBy`, `createdAt`, `finalizedAt`.

**`matchId` is not a stored field** — the document's identity is its Firestore id alone. The
same is true of `notifications` and `reports`. `tournaments` is the one collection in this
schema that *does* duplicate its own id into a field, which is why this needs checking per
collection rather than assumed as one rule for all.

`update` is restricted to `['status','finalizedAt']`; `delete` is not granted at all.

### 13.8 `stats/{statId}`

`statId`, `eventId`, `eventName`, `organizerId`, `athleteId`, `athleteName`, `sport`,
`venue`, `eventDate`, `notes`, `pointsAwarded`, `matchId`?, `createdAt`, plus a nested
**`stats` map keyed by sport**:

| Sport | Keys inside the `stats` map |
|---|---|
| Basketball | `points`, `assists`, `rebounds`, `steals`, `blocks`, `turnovers` |
| Volleyball | `kills`, `aces`, `assists`, `digs`, `blocks` |
| Badminton | `pointsScored`, `setsWon`, `matchWon` (bool) |

The per-sport fields are **nested under one `stats` field**, not flat columns on the
document. `update` and `delete` are both `if false` — stats are append-only.

Note the field is `eventDate`, not `gameDate`. And the manuscript's
`smashes` / `ralliesWon` / `servicePoints` / `errors` / `wins` / `losses` match no sport the
app records.

### 13.9 `teamMemberships/{coachId}_{athleteId}`

`coachId`, `athleteId`, `coachName`, `teamName`, `athleteName`, `athletePhotoUrl`, `status`,
`createdAt`, `respondedAt`. One document per coach–athlete pair; the **document id is itself
the composite key**. A coach's roster is simply every accepted membership with that
`coachId`. **There is no `sport` field** — the sport is read live off the coach's profile.

### 13.10 `tournaments/{tournamentId}` and `/slots`

Tournament: `tournamentId` *(genuinely duplicated into the document)*, `organizerId`, `name`,
`description`, `sport`, `status`, `isPublic`, `venue`, `venueAddress`, `venueLat`,
`venueLng`, `venueType`, `entrantCount`, `roundCount`, `entrants[]`, `championCoachId`,
`championTeamName`, `hasMatchData`, `createdAt`, `completedAt`. **No tournament-level date**
(dates belong to individual matches) and **no `venueID`** — venue is inlined as everywhere
else.

Slot (`slots/r{round}m{slot}`): `organizerId` *(denormalised from the parent)*, `round`,
`slot`, `entrantA`, `entrantB`, `nextSlotId`, `nextSlotSide`, `status`, `eventId`?,
`matchId`?, `scoreA`, `scoreB`, `winnerCoachId`, `completedAt`. Named `slots` rather than
`matches` specifically so it can never be confused with the top-level `matches` collection.

### 13.11 `notifications/{autoId}`

`userId` (recipient), `fromUid` (sender, never shown to the recipient — it exists purely so
forgery is checkable server-side), `type`, `title`, `body`, `relatedId`?, `read`,
`createdAt`. Read, update and delete are **owner-only**.

**Eight allowed type strings** (`NotificationService.kTypes`, mirrored exactly in the rules):
`event_added`, `event_cancelled`, `event_updated`, `organizer_pending`, `organizer_status`,
`stats_added`, `team_full`, `team_invite`.

⚠ Two mismatches worth documenting rather than glossing:
- `NotificationType` declares **nine** enum values, two of which — `eventReminder` and
  `rankChange` — have **no writer anywhere** and are absent from both the allowlist and the
  rules. `eventReminder` is deliberate (reminders are OS notifications, not documents);
  `rankChange` is simply unimplemented.
- `organizer_pending` and `organizer_status` are in the allowlist but have **no enum case**,
  so they render with the generic bell icon.

### 13.12 `reports/{reportId}`

`reporterUid`, `reporterName`, `targetType` (`'user'`/`'event'`), `targetId`, `targetLabel`,
`reason`, `details`, `status`, `createdAt`, `resolvedBy`, `resolvedAt`. Create requires
truthful attribution and `status == 'open'`; read is admin **or your own reports only**;
update is admin-only and restricted to the three status fields; **delete is `if false`**.

### 13.13 `users/{uid}/achievements/{id}` — NOT WIRED

`lib/models/achievement.dart` documents the path and `lib/screens/profile/widgets/achievements_list.dart`
renders it, but **nothing anywhere writes to it, nothing instantiates the widget, and it has
no security rule** — so it currently falls through to deny-all. Verified against every screen
that could plausibly show or edit one.

**Recommendation:** flag this to the panel directly as scaffolded-but-unshipped (a data model
and its UI exist; the write path that would make it real does not) rather than either
silently dropping it or documenting it as working.

---

## 14. Firebase Storage, indexes, and the rule boundary

### 14.1 Storage layout — 4 path prefixes

| Path | Contents | Read | Size cap |
|---|---|---|---|
| `profile_photos/{uid}/photo.jpg` | single avatar (overwritten, never accumulates) | any signed-in | 10 MB rule / 5 MB client |
| `team_logos/{coachId}/logo.jpg` | single team logo | any signed-in | 10 MB |
| `organizer_verification/{uid}/document.jpg` | proof of legitimacy | **owner or admin only** | 10 MB |
| `profile_media/{uid}/{id}.jpg\|.mp4\|{id}_thumb.jpg` | portfolio photos, highlight videos, poster frames | any signed-in | 25 MB |
| `{allPaths=**}` | — | **denied** | — |

Two details worth a line in the manuscript: the verification document is fetched with
`getData()` rather than `getDownloadURL()`, because a download URL is a token-bearing public
link that bypasses Storage rules entirely — wrong for a document that may contain a
government ID. And every path needs an **explicit separate `delete` rule**, because
`allow write` conditions guard on `request.resource.size`, which is null on a delete and so
can never hold.

`storage.rules` identifies admins from a **hardcoded UID list**, whereas `firestore.rules`
does a live `role == 'admin'` lookup. This is a known, documented divergence: provisioning a
second admin requires editing and redeploying `storage.rules` too.

### 14.2 Composite indexes — 10 declared

`firestore.indexes.json`:

| Collection | Fields | Serves |
|---|---|---|
| `users` | `role` ASC, `points` ASC | `RankingService.cityRank` |
| `users` | `role` ASC, `primarySports` CONTAINS | Leaderboard by sport; Scout default |
| `users` | `role` ASC, `primarySports` CONTAINS, `openToRecruitment` ASC | Scout with the recruitment toggle |
| `stats` | `athleteId` ASC, `createdAt` DESC | Recent activity, stat averages |
| `media` | `type` ASC, `createdAt` DESC | Portfolio filtered to photos or videos |
| `events` | `status` ASC, `isPublic` ASC | **Venue locator** |
| `tournaments` | `organizerId` ASC, `createdAt` DESC | Organizer tournament list |
| `notifications` | `userId` ASC, `read` ASC | Unread badge, mark-all-read |
| `notifications` | `userId` ASC, `createdAt` DESC | Notification sheet, admin activity |
| `reports` | `status` ASC, `createdAt` DESC | Admin report queue, both tabs |

---

## 15. APIs, services and packages currently in use

### 15.1 External APIs — four, of which three are Google

| API | Endpoint | Used by | Cache |
|---|---|---|---|
| **Places API (New)** Text Search | `POST places.googleapis.com/v1/places:searchText` | venue search in create/edit event | 30 min |
| **Geocoding API** | `GET maps.googleapis.com/maps/api/geocode/json` | reverse-geocode a dropped map pin | 1 hour |
| **Directions API** | `GET maps.googleapis.com/maps/api/directions/json` | driving route from the venue locator | 30 min |
| **Maps SDK for Android** | native widget | both map screens | n/a |
| **PSGC registry** (non-Google) | `GET psgc.gitlab.io/api/.../barangays/` | the barangay picker | permanent, live results only |

The Places request carries a **field mask** (`places.displayName,places.formattedAddress,places.location,places.primaryType`)
which is what bounds the billing SKU tier, and is biased to a 15 km circle around Legazpi.
The Directions request omits `departure_time`, so no live traffic is requested — which is
what justifies the 30-minute cache.

The PSGC registry falls back to a bundled 70-barangay snapshot on any failure. `[test]`
`test/services/barangay_service_test.dart` and `test/constants/` pin the fallback behaviour
and the snapshot's completeness.

### 15.2 Firebase products — five

`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`,
`firebase_crashlytics`. Crashlytics classifies a failed image load as non-fatal
(`lib/utils/crash_classification.dart`) so it does not bury real crashes.

### 15.3 Notable Flutter packages

`get` (state, DI, routing, snackbars) · `google_maps_flutter` · `geolocator` ·
`flutter_local_notifications` + `timezone` (event reminders) · `video_compress` +
`video_player` (highlights) · `image_picker` + `flutter_image_compress` ·
`cached_network_image` · `fl_chart` (dashboard) · `shared_preferences` · `connectivity_plus` ·
`google_sign_in` · `uuid` · `intl` · `url_launcher` · `google_fonts`, `iconsax`,
`lucide_icons_flutter`.

### 15.4 Platform services

- **Local event reminders** — `flutter_local_notifications` schedules OS alarms at **18:00
  the day before** and **1 hour before kickoff**, with a 2-minute minimum lead. Nothing is
  written to Firestore. Scheduling is deliberately **inexact** so `SCHEDULE_EXACT_ALARM` is
  never needed; the timezone is pinned to `Asia/Manila`; the service no-ops off Android/iOS.
  The Android manifest needs `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` and **two
  receivers** — without the receivers a reminder is accepted silently and never shown.
  `[test]` `test/utils/event_reminders_test.dart`.
- **Connectivity** — `ConnectivityService` combines `connectivity_plus` with a **real DNS
  lookup**, because an adapter reporting "connected" is not the same as internet access. It
  distinguishes a captive portal from a plain outage. `NoInternetOverlay` wraps the entire
  app from `GetMaterialApp.builder`; it is the only offline treatment in the project.
- **Crash reporting** — `runZonedGuarded` plus `FlutterError.onError` plus
  `PlatformDispatcher.instance.onError`, with a dedicated startup-failure screen if Firebase
  itself cannot initialise.
- **Theming** — light/dark with semantic colour getters, persisted to `SharedPreferences` and
  resolved *before* `runApp` so the first frame is already correct. Brand colour is gold
  `#FFB800`.
- **Text scaling** — clamped app-wide to 1.2× because every screen hardcodes font sizes.

---

## 16. Important relationships between features

These are the couplings a diagram must preserve; breaking one silently breaks the other.

1. **Record Match → Submit Stats → Elo.** A match stays `'pending'` until *every*
   participant has a stats document linked to it via the optional dropdown. Only then does
   `finalizeMatch` run. Miss one player and no rating ever changes. (§10.4)
2. **Stats → Points → City Rank → Leaderboard "All" tab → Scout default sort.** One
   `pointsAwarded` value propagates through all five.
3. **Elo → `ratings.<sport>` → Leaderboard per-sport tabs → Dashboard rating trend.**
   Entirely separate from the points chain above.
4. **Coach `primarySports` → Scout results → invite permission → event team picker.** A
   coach's declared sport gates who they can see, who they can invite, and which events they
   can be picked into.
5. **Organizer `organizerStatus: 'approved'` → event creation → tournament creation →
   cross-user points/ratings writes.** One admin decision unlocks the entire organizer
   surface, and it is enforced in rules, not UI.
6. **Tournament slot → spawned event → match → bracket advance.** Scheduling a ready slot
   creates a real event; recording its match stages the result and the advance in one batch.
7. **`hasMatchData` → delete permission.** Set on both events and tournaments the moment a
   result is recorded; it is what lets the rules refuse a delete without a collection query.
8. **Event write → notification fan-out.** Publishing, updating or cancelling an event
   notifies the roster *and* both head coaches, via `eventAudienceUids()`. Coaches are
   deliberately kept **out** of `playerUids`, because that array drives the athlete "my
   games" query and `playerCount`.
9. **Home `initState` → reminder resync.** The whole schedule is cancelled and rebuilt each
   time the home screen opens, so a moved or cancelled event needs no bookkeeping — at the
   cost that reminders only refresh while the app is open.
10. **Contact PII split → admin review.** Because contact details live in a subcollection,
    the admin's approval screen is the only place in the app that can read another user's
    email or phone.

---

## 17. GAP A — Implemented, but absent from the manuscript

Verified by word-boundary search over the extracted manuscript text. Occurrence counts are
for the entire document.

| # | Feature | Manuscript hits | Evidence in code |
|---|---|---|---|
| A1 | **Super-admin role and 5-tab console** | `admin` 0, `administrator` 0 | `lib/screens/admin/*` (8 files), `firestore.rules:31-33` |
| A2 | **Reports / content moderation** | — | `lib/models/report.dart`, `report_service.dart`, `report_dialog.dart`, `admin_reports_screen.dart` |
| A3 | **Organizer approval workflow** | — | `organizerStatus`, `admin_review_screen.dart`, `firestore.rules:25-29` |
| A4 | **Account suspension** | `suspend` 0 | `admin_user_service.dart`, `suspended_screen.dart` |
| A5 | **Email verification gate** | `verification` 0 | `email_verification_screen.dart`, `auth_routing.dart:61` |
| A6 | **Google Sign-In** | `Google Sign` 0 | `auth_controller.dart:145-237`, `google_profile_setup_screen.dart` |
| A7 | **Account deletion (Play requirement)** | `delete` 0 | `account_deletion_service.dart`, `delete_account_screen.dart` |
| A8 | **Elo / MMR match-rating engine** | `Elo` 0, `MMR` 0 | `rating_service.dart`, `elo_calculator.dart`, `rating_history_entry.dart` |
| A9 | **Team invite / accept lifecycle** | `invite` 0 | `team_service.dart`, `team_invite.dart`, `team_invites_screen.dart` |
| A10 | **Onboarding flow (4 panels)** | 1 passing mention | `onboarding_screen.dart`, `onboarding_flag.dart` |
| A11 | **Media portfolio (photo/video highlights)** | — | `media_service.dart`, `media_item.dart`, `media_section.dart` |
| A12 | **Local OS event reminders** | — | `event_reminder_service.dart`, `event_reminders.dart` |
| A13 | **In-app notification subsystem** | 4 hits, all survey/future-facing | `notification_service.dart`, `app_notification.dart` |
| A14 | **Offline detection + full-screen overlay** | `offline` 0 | `connectivity_service.dart`, `no_internet_overlay.dart` |
| A15 | **Crashlytics + global error handling** | `Crashlytics` 0 | `main.dart:90-113`, `crash_classification.dart` |
| A16 | **Light/dark theming** | `dark mode` 0 | `app_theme.dart`, `theme_controller.dart` |
| A17 | **Tournament brackets (seeding, byes, advancement)** | `bracket` 4, never as a data structure | `bracket.dart`, `bracket_slot.dart`, `tournament_service.dart` |
| A18 | **Contact-PII split into a private subcollection** | — | `contact_service.dart`, `firestore.rules:108-117` |
| A19 | **Live barangay registry (PSGC) with offline fallback** | — | `barangay_service.dart`, `legazpi_barangays_fallback.dart` |
| A20 | **Record Match as a distinct organizer use case** | — | `record_match_screen.dart` |
| A21 | **Match `Splash`/session-restore routing** | — | `splash_screen.dart:222-272`, `auth_routing.dart` |

**Twenty-one shipped capabilities with no representation in the manuscript.** A1–A4 together
constitute an entire fourth actor with its own subsystem, which is the single largest
documentation gap.

---

## 18. GAP B — In the manuscript, but NOT implemented

Each row was confirmed by reading the cited code, not inferred.

| # | Manuscript claim | Where it appears | Reality |
|---|---|---|---|
| B1 | **Community Hub / "The Crew"** — "enabled social networking, matchmaking, and team formation" | Ch. 4 Findings 2.c; Recommendation 5; Table 3.28 `Crew Collection`; Figure 8 `Crew` class | **Does not exist.** No social feed, no matchmaking, no inter-team challenge, no "create a crew" action. The nearest real feature is a coach→athlete invite (`team_service.dart`). `crewID`/`crewName`/`roster` match nothing. |
| B2 | **Real-time court availability** | Scope & Delimitation; Table 3.16 ("availability"); Ch. 4 Findings 2.c; Recommendation 4 | **Not implemented.** `lib/models/venue.dart` has no availability field; repo-wide search for `availability` returns nothing. Google Places does not supply court booking state. |
| B3 | **Athletes submit their own game statistics** | Table 3.16 (Control column: "Athlete / Organizer"); Figure 5; Figure 6 | **Organizer-only.** `add_stats_screen.dart` queries `events where organizerId == currentUid`; every stats document is written with `organizerId` set to the submitter. An athlete has no path to self-report anywhere. |
| B4 | **Participant registration / "register for games"** | Figure 5 narration; Ch. 4 Findings 2.c; Table 3.26 `Participants Collection` | **No join or RSVP exists.** Search for `rsvp\|joinEvent\|registerForEvent` returns nothing. Rosters are assembled exclusively by the organizer from coach teams. *(Note: `my_events_screen.dart:159` contains stale copy saying "athletes can register for it" — UI text only, no backing code.)* |
| B5 | **Proximity / "nearby venues" GPS search** | Table 3.16 ("Venue search request with GPS coordinates → fetches nearby sports facilities"); Figure 7 | **No proximity search.** Every upcoming public event loads regardless of distance. GPS is read only as the *origin* of a directions request. |
| B6 | **Announcements** | Ch. 4 "Notification and Announcement features" | **No announcement feature.** Search returns nothing. Notifications exist, but only as the 8 allowlisted event/team/stats types. |
| B7 | **`Venues` collection** (Table 3.23) | Table 3.23; Figure 8 `Venue` class with `locateVenue()`, `updateInfo()`, `availability`, `sportType` | **Not a collection.** `Venue` is a 5-field value object resolved live from Places or a map pin and inlined onto the event. No id, no persistence methods, no Firestore import in the model at all. |
| B8 | **`GameSchedule` collection** (Table 3.25) | Table 3.25 | **Not a collection.** `eventDate` is a field on `events`. |
| B9 | **`Participants` collection** (Table 3.26) | Table 3.26 | **Not a collection.** `players[]` and `playerUids[]` are fields on `events`; `entrants[]` on `tournaments`. |
| B10 | **`Leaderboard` collection** (Table 3.27) | Table 3.27 | **Never persisted.** `RankingService.cityRank` computes rank live with a Firestore `count()` query. |
| B11 | **`PointingSystem` collection** (Table 3.29) | Table 3.29 | **Not a collection.** Points are a single int on `users`; the closest analogue to a scoring engine is Elo, whose history lives in `users/{uid}/ratingHistory`. |
| B12 | **`password` field on Users** (Table 3.18) | Table 3.18; Figure 8 `User` class | **Never stored.** Firebase Authentication owns credentials; Firestore never sees a password. |
| B13 | **Athletes/Coaches/Organizers as four separate collections** | Tables 3.18–3.21 | **One `users` collection.** Which fields a document carries depends on its `role`. |
| B14 | **`GameStats` field set** (Table 3.22) | Table 3.22 | Field names do not match: `smashes`, `ralliesWon`, `servicePoints`, `errors`, `wins`, `losses` correspond to no sport the app records. Badminton is actually `pointsScored` / `setsWon` / `matchWon`. Also `gameDate` → the real field is `eventDate`. |
| B15 | **Tournaments carry a `date` and a `venueID`** (Table 3.24) | Table 3.24 | Neither exists. Dates belong to individual matches; venue is inlined, not a foreign key. |

**Six of the twelve documented collections do not exist** (B7–B11 plus B1's Crew), and four
of the remaining six are materially wrong about their fields.

---

## 19. GAP C — Present in both, but described incorrectly

| # | Subject | Manuscript says | Code does |
|---|---|---|---|
| C1 | **Actors** | Three: Athlete, Coach, Organizer | Four: plus `admin`, whose console gates the organizer role itself |
| C2 | **Game Directory vs Venue Locator** | Two separate flows on two lifelines *(Figure 7)* `[per working copy]` | **One screen.** `venue_locator_screen.dart` is titled "Game Directory" and shows the list and the map together |
| C3 | **"Post to Game Directory"** as a step | A distinct publish action *(Figure 7)* `[per working copy]` | Not a step. Any event with `isPublic: true` appears automatically |
| C4 | **Add to Roster** | A single unilateral Coach action *(Figures 5 and 6)* `[per working copy]` | A two-party asynchronous exchange: coach sends → validation (sport overlap, roster cap, one-team-per-sport) → athlete notified → athlete accepts |
| C5 | **Firebase as one opaque box** | A single unlabelled "Firebase" between Frontend and Firestore *(Figure 4)* `[per working copy]` | Four distinct products: Auth, Firestore, Storage, Crashlytics — plus Google Maps Platform called **directly from the client**, not through Firebase |
| C6 | **Scoring** | One "Pointing System" | **Two independent systems**: cumulative Homegrown points (per stats submission) and per-sport Elo rating (per finalized match). They rank different leaderboard tabs |
| C7 | **Stats submission triggers the dashboard** | Direct, immediate *(Table 3.16)* | True for points; but the *rating* half requires the optional "Link to Match" step for every participant, or it never fires at all |
| C8 | **Coaches search "by sport, performance metrics, and barangay"** | Ch. 4 Findings 2.b | Sport ✓ and performance ✓ (skill sort), but **barangay is displayed, never filterable**. There is also no time/season window anywhere |
| C9 | **Class count** | "17 individual classes" *(Figure 8)* | The real model set is larger and differently shaped: `MatchResult`, `TeamInvite`, `BracketSlot`, `Tournament`, `AppNotification`, `MediaItem`, `RatingHistoryEntry`, `Report`, `Venue`, `Achievement` |
| C10 | **Figure numbering** | Working copy calls the Class Diagram "Figure 9" | The current PDF numbers it **Figure 8**; there is no Figure 9. Check before pasting corrections |

---

## 20. DOCUMENTATION UPDATE PLAN

Ordered by how much a panel is likely to probe it. Each item names the exact change and the
audit section holding the evidence.

### ⬛ Priority 1 — claims that are factually wrong

**20.1 Figure 5 — Use Case Diagram** → §6, §10
- **Move** "Submit Game Statistics" from Athlete to **Organizer**. *(This was flagged by your
  own researchers and is confirmed: B3.)*
- **Add** a new Organizer use case: **"Record Match Result"** — a distinct screen from
  per-player stat entry, and the thing that triggers bracket advancement and Elo.
- **Replace** "Add to Roster" with a **"Send Team Invite"** (Coach) / **"Accept or Decline
  Team Invite"** (Athlete) pair.
- **Remove** "register for games" from the Athlete's list (B4).
- **Add** a fourth actor, **Super-Admin**, with: Approve/Revoke Organizer, Suspend/Reinstate
  Account, Resolve Report, Cancel Event or Tournament.
- **Add** Athlete use cases currently missing: Manage Media Portfolio, View Own Profile.

**20.2 Tables 3.18–3.29 — Database Design** → §13 (the whole section is the replacement text)
- **Merge** Tables 3.18–3.21 into **one `users` collection** with fields grouped by role
  (B13), and **delete the `password` field** (B12).
- **Delete** Tables 3.23 (Venues), 3.25 (GameSchedule), 3.26 (Participants), 3.27
  (Leaderboard), 3.28 (Crew), 3.29 (PointingSystem) — none is a real collection (B7–B11).
- **Add** five previously undocumented collections/subcollections: `events`, `matches`,
  `teamMemberships`, `notifications`, `reports`, plus the subcollections
  `users/{uid}/private`, `users/{uid}/media`, `users/{uid}/ratingHistory`, and
  `tournaments/{id}/slots`.
- **Correct** Table 3.22 (GameStats → `stats`): `gameDate` → `eventDate`; replace the
  invented badminton fields; show the per-sport fields **nested under a `stats` map**.
- **Correct** Table 3.24 (Tournaments): remove `date` and `venueID`; add the real field list.
- **Do not** give `matches`, `notifications` or `reports` a self-referencing id field — those
  documents' identity is their Firestore id alone. `tournaments` is the one that genuinely
  duplicates its id.
- **Leave `achievements` out**, or mark it explicitly unshipped (§13.13).
- Final count: **8 top-level collections + 4 subcollections = 12**.

**20.3 Scope & Delimitation (Ch. 1) and Findings (Ch. 4)** → §18
- **Remove or reword** "check the availability of sports venues" (B2). Suggested: "locate
  sports venues and get directions to them."
- **Reword** Ch. 4 Findings 2.c, which currently states the Community Hub (The Crew) was
  delivered (B1). It was not. Either describe what shipped — coach-led team formation via
  an invite/accept workflow — or move it to Recommendations as future work.
- Note the internal contradiction worth fixing either way: **Recommendations 4 and 5 advise
  "continuing" work on court availability and the Community Hub, which the Findings section
  claims were already delivered.** Aligning these two sections removes an easy line of
  questioning.
- **Remove** "participant registration" from the Game Directory description (B4).

### ⬛ Priority 2 — diagrams that are structurally out of date

**20.4 Figure 4 — System Architecture** → §12.1 (diagram included there)
- Split the single "Firebase" box into **Authentication, Cloud Firestore, Storage,
  Crashlytics**.
- Draw **Google Maps Platform as a direct client call**, not routed through Firebase.
- Show **two separate API keys** with different restrictions.
- Add the **PSGC registry** as a fourth external dependency.
- Show Crashlytics as **one-way, fire-and-forget**, not request/response.
- Optionally note that there is **no application server** — `functions/` exports nothing.

**20.5 Figure 8 — Class Diagram** (⚠ the working copy calls this Figure 9 — C10) → §13
- **Remove** `password` from `User`.
- **Replace** `Crew` with `TeamInvite` (coachId, athleteId, status, createdAt, respondedAt;
  invite/accept lifecycle; cap 15; one team per sport).
- **Reduce** `Venue` to its real five fields with **no** persistence methods, no id, no
  availability, no sportType.
- **Correct** the three sport-stats classes' field names (B14).
- **Add** `MatchResult`, linked 0..1 to Tournament (only bracket play links one) and 1→0..*
  to stat entries.
- Carry full UML multiplicity at both ends, per §13.1.
- **Recommended:** draw a *second, supplementary* class diagram for Admin, Report,
  AppNotification, MediaItem and RatingHistoryEntry rather than overloading Figure 8.

**20.6 Figure 7 — Sequence: Game Management & Venue Locator** → §11, §10.4
- **Merge** Game Directory and Venue Locator into **one lifeline** (C2).
- **Correct the GPS steps**: GPS is the *origin of a directions request*, not a proximity
  search (B5).
- **Remove** "Post to Game Directory" as a step — `isPublic: true` is sufficient (C3).
- **Add** the organizer post-game block: Record Match → (Elo + bracket advance) → Submit
  Stats per player → points awarded + athlete notified.

**20.7 Figure 6 — Sequence: Athlete Performance & Scouting** → §9
- **Remove** the athlete stats-submission step; point to Figure 7 instead (B3).
- **Replace** the direct "Add to Roster" call with: Send Invite → validate (sport overlap,
  roster cap, one-team-per-sport) → notify athlete → athlete accepts → confirm (C4).

### ⬛ Priority 3 — new material to add

**20.8 New: Authentication & Onboarding flowchart** → §2, §3
Nothing in the manuscript covers this today. It should show: splash session-restore →
`landingRoute` four-branch gate (admin / suspended / unverified / home) → onboarding → role
picker → three registration wizards → email verification. The decision tree in §3 can be
transcribed directly.

**20.9 New: Administration & Moderation section** → §5
An actor description, the five console tabs, the organizer approval lifecycle
(pending → approved / rejected / revoked → restore), the suspension flow, and the report
queue. State clearly that the admin role is **provisioned manually in the Firebase console**
and is unreachable from the app.

**20.10 New: the two scoring systems** → §10.5
A short subsection distinguishing Homegrown Points from the Elo match rating, with both
formulas. This directly serves Recommendation 2, which asks for continued work on "the
underlying Pointing System algorithm" — right now the manuscript does not state what that
algorithm is.

**20.11 Table 3.16 — Functional Requirements** → §6
- Change the Control column for Game Statistics from "Athlete / Organizer" to **Organizer**.
- Change Venue Search: remove "availability", remove "nearby"; the Storage column should read
  *Events collection in Firestore + Google Maps Platform (Places, Directions, Geocoding)* —
  **not** "Venues Collection in Firestore".
- Change Tournament row storage from "Tournaments, GameSchedule, and Participants
  Collections" to **`tournaments` + `tournaments/{id}/slots` + spawned `events`**.
- Add rows for: Record Match Result, Send/Accept Team Invite, Organizer Approval, File a
  Report, Account Suspension.

**20.12 Optional but recommended: a UI flow / screen inventory** → §7
The manuscript has no screen map. §7's route table can be lifted directly. If you add one
diagram here, make it the **role-differentiated bottom navigation**, since it is the clearest
single illustration that the app is genuinely role-based.

### ⬛ Items to decide, not just fix

1. **"Crew" naming.** Decide whether to keep Crew as the thesis's conceptual name for team
   formation (with a note that it ships as "Team" in the UI), or rename to Team throughout.
   Do not leave both.
2. **Free-text numeric fields.** `heightCm`, `weightKg`, `yearsOfPlaying` and
   `yearsOfExperience` are stored as strings. Worth either tightening before final
   submission or documenting as a known limitation.
3. **Achievements.** Model and display widget exist; no write path does. Declare it as
   future work rather than leaving it ambiguous.
4. **`maxPlayers`.** Written as `null` at creation and never enforced. Either document it as
   display-only or remove it from the tables.

---

## 21. Verification method used for this audit

1. Every field list was traced to the literal `.set()` / `.update()` / `.add()` /
   `batch.set()` call that writes it — **not** inferred from `firestore.rules`, which
   validates only a handful of keys per collection and is silent on the rest.
2. `firestore.rules` was used for exactly two things: enumerating which collections exist
   (via the default-deny catch-all) and establishing who may read or write each one.
3. Where an automated test pins a behaviour, the test is cited in preference to the
   implementation, because it states the intended contract.
4. Absence claims ("X is not implemented") were established by repo-wide search, with the
   search term recorded in §18 so they can be re-run.
5. Manuscript claims were read from `pdftotext -layout` output of the current thesis PDF.
   Statements about what a *figure depicts* are marked `[per working copy]` because the
   figures are images with no text layer.

**Not covered by this audit:** the ISO/IEC 25010 evaluation results, survey data (Tables
3.1–3.17), hardware/software requirement tables, and Chapters 1–2 literature. Those were
out of scope.
