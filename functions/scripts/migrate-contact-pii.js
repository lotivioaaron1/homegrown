#!/usr/bin/env node
/**
 * Backfills users/{uid}/private/contact from the legacy top-level `email` and
 * `phoneNumber` fields on users/{uid}.
 *
 * Those fields sat on a document every signed-in account can read. They now
 * live in a subcollection that only the owner and the super-admin can read
 * (see firestore.rules), but existing documents still carry the old copies,
 * and deleting them is what actually closes the exposure — the backfill alone
 * only adds a second copy.
 *
 * Run it in two passes, not one:
 *
 *   1. node scripts/migrate-contact-pii.js --apply
 *        Copies contact details into the subcollection. Old fields stay put,
 *        so clients that predate this release keep working.
 *
 *   2. ...once the new build is live for everyone...
 *      node scripts/migrate-contact-pii.js --apply --delete-legacy
 *        Removes the top-level copies. This is the step that closes the hole.
 *
 * Splitting it this way matters because an old client reading a user document
 * still expects `email` on it. Deleting before the rollout finishes shows
 * blank contact details in the admin queue for anyone still on the old build.
 *
 * Without --apply the script only reports what it would do.
 *
 * Auth: point GOOGLE_APPLICATION_CREDENTIALS at a service-account key for
 * homegrown-app-b71d1. The Admin SDK bypasses security rules by design, which
 * is why this cannot run from the Flutter client — the new rule correctly
 * forbids one user writing another user's private subcollection.
 */

const admin = require("firebase-admin");

const apply = process.argv.includes("--apply");
const deleteLegacy = process.argv.includes("--delete-legacy");

if (deleteLegacy && !apply) {
  console.error("--delete-legacy requires --apply. Refusing to run.");
  process.exit(1);
}

admin.initializeApp({credential: admin.credential.applicationDefault()});
const db = admin.firestore();

// Firestore caps a batch at 500 writes; deleting legacy fields costs a second
// write per user, so stay well under it.
const BATCH_LIMIT = 200;

async function main() {
  const snap = await db.collection("users").get();
  console.log(`Scanning ${snap.size} user document(s).`);
  console.log(
      apply ?
        (deleteLegacy ?
          "Mode: APPLY + DELETE LEGACY FIELDS" :
          "Mode: APPLY (backfill only)") :
        "Mode: DRY RUN — nothing will be written. Pass --apply to commit.");

  let backfilled = 0;
  let cleared = 0;
  let skipped = 0;
  let batch = db.batch();
  let pending = 0;

  const flush = async () => {
    if (apply && pending > 0) await batch.commit();
    batch = db.batch();
    pending = 0;
  };

  for (const doc of snap.docs) {
    const data = doc.data();
    const email = typeof data.email === "string" ? data.email : "";
    const phone = typeof data.phoneNumber === "string" ? data.phoneNumber : "";

    if (!email && !phone) {
      skipped++;
      continue;
    }

    const contactRef = doc.ref.collection("private").doc("contact");

    // Never clobber a subcollection document the app has already written —
    // a user who edited their profile after the release has fresher data
    // here than the legacy fields do.
    const existing = await contactRef.get();
    if (!existing.exists) {
      batch.set(contactRef, {
        email,
        phoneNumber: phone,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      pending++;
      backfilled++;
    }

    if (deleteLegacy) {
      batch.update(doc.ref, {
        email: admin.firestore.FieldValue.delete(),
        phoneNumber: admin.firestore.FieldValue.delete(),
      });
      pending++;
      cleared++;
    }

    if (pending >= BATCH_LIMIT) await flush();
  }

  await flush();

  console.log(`  backfilled : ${backfilled}`);
  console.log(`  legacy cleared : ${cleared}`);
  console.log(`  no contact data : ${skipped}`);
  if (!apply) console.log("Dry run only — re-run with --apply to commit.");
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
