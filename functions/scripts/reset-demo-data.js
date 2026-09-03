#!/usr/bin/env node
/**
 * Clears accumulated activity so the app can be demoed from a blank slate.
 *
 * Deletes every document in the activity collections, wipes rating history,
 * and zeroes each athlete's points and rating. Accounts, profiles, avatars and
 * portfolio media are all left alone — this resets what people *did*, not who
 * they are, so every seeded role can still be signed into for the demo.
 *
 *   node scripts/reset-demo-data.js            Dry run. Reports what it would remove.
 *   node scripts/reset-demo-data.js --apply    Commits it.
 *
 * This is irreversible: Firestore has no undo, and the free plan keeps no
 * point-in-time backup. Read the dry run before adding --apply.
 *
 * Deliberately NOT touched:
 *   - Firebase Auth accounts, so nobody has to re-register
 *   - users/{uid} profiles, apart from the points and ratings fields
 *   - users/{uid}/media and Storage objects — portfolio content, not activity
 *   - users/{uid}/private — contact details, not activity
 *   - documents already tombstoned by the in-app account deletion flow, which
 *     exist so surviving references still resolve to "Deleted user"
 *
 * Auth: point GOOGLE_APPLICATION_CREDENTIALS at a service-account key.
 */

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const apply = process.argv.includes("--apply");

initializeApp({credential: applicationDefault()});
const db = getFirestore();

const ACTIVITY_COLLECTIONS = [
  "events",
  "matches",
  "stats",
  "teamMemberships",
  "notifications",
];

const BATCH = 400;

/** Deletes every document a snapshot holds, in batches under Firestore's cap. */
async function deleteAll(docs) {
  if (!apply) return;
  for (let i = 0; i < docs.length; i += BATCH) {
    const batch = db.batch();
    docs.slice(i, i + BATCH).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

async function main() {
  console.log(apply ?
    "Mode: APPLY — this permanently deletes data." :
    "Mode: DRY RUN — nothing will change. Add --apply to commit.");
  console.log("");

  let removed = 0;
  for (const name of ACTIVITY_COLLECTIONS) {
    const snap = await db.collection(name).get();
    console.log(`  ${name.padEnd(16)} ${String(snap.size).padStart(5)} ` +
      `${apply ? "deleted" : "would be deleted"}`);
    await deleteAll(snap.docs);
    removed += snap.size;
  }

  // ratingHistory lives under each user, so a collection-group query reaches
  // every one of them without walking the users collection twice.
  const history = await db.collectionGroup("ratingHistory").get();
  console.log(`  ${"ratingHistory".padEnd(16)} ${String(history.size).padStart(5)} ` +
    `${apply ? "deleted" : "would be deleted"}`);
  await deleteAll(history.docs);
  removed += history.size;

  // Zero the standings. Only documents actually carrying a non-zero value are
  // rewritten, so this does not churn every profile in the project.
  const users = await db.collection("users").get();
  const toReset = users.docs.filter((d) => {
    const u = d.data();
    const pts = typeof u.points === "number" ? u.points : 0;
    return pts > 0 || u.ratings !== undefined;
  });

  console.log(`\n  athletes carrying points or a rating: ${toReset.length}`);
  toReset.slice(0, 20).forEach((d) => {
    const u = d.data();
    console.log(`    ${apply ? "reset" : "would reset"}: ` +
      `${u.fullName || d.id} (points ${u.points ?? 0})`);
  });
  if (toReset.length > 20) {
    console.log(`    …and ${toReset.length - 20} more`);
  }

  if (apply) {
    for (let i = 0; i < toReset.length; i += BATCH) {
      const batch = db.batch();
      toReset.slice(i, i + BATCH).forEach((d) => {
        batch.update(d.ref, {
          points: 0,
          // Remove the field outright rather than writing an empty map, so a
          // reset profile is indistinguishable from one that never played.
          ratings: FieldValue.delete(),
        });
      });
      await batch.commit();
    }
  }

  console.log(`\n  ${apply ? "documents deleted" : "documents that would be deleted"}: ${removed}`);
  console.log(`  ${apply ? "profiles reset" : "profiles that would be reset"}: ${toReset.length}`);
  if (!apply) console.log("\nDry run only — re-run with --apply to commit.");
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
