#!/usr/bin/env node
/**
 * Tombstones `users/{uid}` documents whose Firebase Auth account is gone.
 *
 * Deleting an account from the Firebase console removes only the credential.
 * The profile document survives completely untouched — same `role`, same
 * `primarySports`, same `openToRecruitment` — so the person keeps appearing in
 * Scout as a recruitable athlete and on the Leaderboard as a ranked one, while
 * being impossible to sign in as. This script is the cleanup for accounts
 * removed that way.
 *
 * It does NOT hard-delete. A uid appears inside other people's records — the
 * `sideA`/`sideB` arrays on matches, `athleteId` on stats, `organizerId` on
 * events — and erasing the document outright would leave those dangling. Each
 * orphan is reduced to the same minimal tombstone the in-app deletion flow
 * writes (see lib/services/account_deletion_service.dart), so shared history
 * still resolves to "Deleted user" and nothing else breaks. The app's
 * isListableProfile guard (lib/utils/firestore_helpers.dart) keeps tombstones
 * out of every athlete list, so they render nowhere.
 *
 * Personal data is erased the same way the in-app flow erases it: the media,
 * ratingHistory and private subcollections, plus notifications and team
 * memberships, all go.
 *
 *   node scripts/purge-orphaned-profiles.js
 *       Dry run. Lists every profile it would tombstone.
 *
 *   node scripts/purge-orphaned-profiles.js --apply
 *       Commits it.
 *
 * This is irreversible: Firestore has no undo, and the free plan keeps no
 * point-in-time backup. Read the dry run before adding --apply — in
 * particular check the email column for anyone you did not mean to remove,
 * since an account deleted from the console is already unrecoverable but its
 * profile is the last copy of their data.
 *
 * Auth: point GOOGLE_APPLICATION_CREDENTIALS at a service-account key for
 * homegrown-app-b71d1.
 */

// firebase-admin 13+ dropped the old `admin.auth()` / `admin.credential`
// namespace in favour of these subpath exports.
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const apply = process.argv.includes("--apply");

initializeApp({credential: applicationDefault()});
const auth = getAuth();
const db = getFirestore();

/** Firestore caps a batch at 500 writes; stay under it with headroom. */
const BATCH = 400;

/** getUsers accepts at most 100 identifiers per call. */
const LOOKUP_CHUNK = 100;

/** Deletes every document a query matches, in batches under Firestore's cap. */
async function deleteQuery(query) {
  const snap = await query.get();
  if (!apply || snap.empty) return snap.size;
  for (let i = 0; i < snap.docs.length; i += BATCH) {
    const batch = db.batch();
    snap.docs.slice(i, i + BATCH).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  return snap.size;
}

/**
 * The uids among [uids] that have no Firebase Auth account.
 *
 * `getUsers` reports these in its own `notFound` list rather than throwing,
 * which is why this is one round trip per 100 rather than a lookup per user.
 */
async function findOrphanedUids(uids) {
  const orphaned = [];
  for (let i = 0; i < uids.length; i += LOOKUP_CHUNK) {
    const chunk = uids.slice(i, i + LOOKUP_CHUNK).map((uid) => ({uid}));
    const result = await auth.getUsers(chunk);
    result.notFound.forEach((id) => orphaned.push(id.uid));
  }
  return orphaned;
}

/** Erases one orphan's personal data and reduces the profile to a tombstone. */
async function tombstone(doc) {
  const uid = doc.id;

  await deleteQuery(doc.ref.collection("media"));
  await deleteQuery(doc.ref.collection("ratingHistory"));
  await deleteQuery(doc.ref.collection("private"));
  await deleteQuery(
      db.collection("notifications").where("userId", "==", uid));
  await deleteQuery(
      db.collection("teamMemberships").where("athleteId", "==", uid));
  await deleteQuery(
      db.collection("teamMemberships").where("coachId", "==", uid));

  // set(), not update(): overwriting the whole document means no personal
  // field can survive by being forgotten here. `role` is carried over because
  // firestore.rules keys other checks off it.
  await doc.ref.set({
    uid,
    role: doc.data().role || "",
    deleted: true,
    deletedAt: FieldValue.serverTimestamp(),
    fullName: "Deleted user",
  });
}

async function main() {
  console.log(apply ?
    "Mode: APPLY — this permanently erases data." :
    "Mode: DRY RUN — nothing will change. Add --apply to commit.");
  console.log("");

  const users = await db.collection("users").get();

  // Documents the in-app deletion flow already tombstoned are done; running
  // over them again would only rewrite deletedAt and lose the real date.
  const live = users.docs.filter((d) => d.data().deleted !== true);
  const alreadyTombstoned = users.size - live.length;

  const orphanedUids =
      new Set(await findOrphanedUids(live.map((d) => d.id)));
  const orphans = live.filter((d) => orphanedUids.has(d.id));

  console.log(`  profiles in users/        : ${users.size}`);
  console.log(`  already tombstoned        : ${alreadyTombstoned}`);
  console.log(`  with a live Auth account  : ${live.length - orphans.length}`);
  console.log(`  orphaned (no Auth account): ${orphans.length}`);

  if (orphans.length === 0) {
    console.log("\nNothing to do.");
    return;
  }

  console.log("");
  for (const doc of orphans) {
    const u = doc.data();
    const sports = Array.isArray(u.primarySports) ?
      u.primarySports.join("/") : "-";
    console.log(
        `  ${apply ? "tombstoning" : "would tombstone"}: ` +
        `${(u.fullName || "(no name)").padEnd(24)} ` +
        `${(u.email || "-").padEnd(34)} ` +
        `${(u.role || "-").padEnd(10)} ${sports}`);
  }

  if (apply) {
    for (const doc of orphans) {
      await tombstone(doc);
    }
    console.log(`\n  profiles tombstoned: ${orphans.length}`);
  } else {
    console.log(`\n  profiles that would be tombstoned: ${orphans.length}`);
    console.log("\nDry run only — re-run with --apply to commit.");
  }
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
