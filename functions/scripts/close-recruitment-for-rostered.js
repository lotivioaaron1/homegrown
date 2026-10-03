#!/usr/bin/env node
/**
 * Switches `openToRecruitment` off for every athlete who is already on a team.
 *
 * Accepting a team invite now closes recruitment as part of the same write
 * (see TeamService.acceptInvite), but athletes who joined a team before that
 * change still carry `openToRecruitment: true` — so Scout shows them as open
 * to recruitment right next to "Already on Your Team". This brings those
 * existing profiles in line with the new rule. It only ever sets that one
 * field to false; nothing is deleted.
 *
 *   node scripts/close-recruitment-for-rostered.js           Dry run: lists who would change.
 *   node scripts/close-recruitment-for-rostered.js --apply   Writes the change.
 *
 * The dry run prints each athlete's name, uid and sign-in email so the list
 * can be checked against the real users' accounts before anything is written.
 *
 * Auth: point GOOGLE_APPLICATION_CREDENTIALS at a service-account key for
 * homegrown-app-b71d1. The Admin SDK bypasses security rules by design, which
 * is why this cannot run from the Flutter client — one user may not write
 * another user's profile.
 */

// firebase-admin 13+ dropped the old `admin.firestore()` / `admin.credential`
// namespace in favour of these subpath exports.
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const apply = process.argv.includes("--apply");

initializeApp({credential: applicationDefault()});
const db = getFirestore();
const auth = getAuth();

// Firestore caps a batch at 500 writes.
const BATCH_LIMIT = 200;

function displayName(data) {
  const joined = `${data.firstName || ""} ${data.lastName || ""}`.trim();
  return joined || data.fullName || "(no name)";
}

async function emailOf(uid) {
  try {
    return (await auth.getUser(uid)).email || "(no email)";
  } catch (err) {
    return err.code === "auth/user-not-found" ? "(no Auth account)" : "(lookup failed)";
  }
}

async function main() {
  const memberships = await db.collection("teamMemberships")
      .where("status", "==", "accepted")
      .get();
  const athleteIds = [...new Set(memberships.docs
      .map((d) => d.data().athleteId)
      .filter((id) => typeof id === "string" && id))];

  console.log(`${athleteIds.length} athlete(s) currently on a team.`);
  console.log(apply ?
    "Mode: APPLY" :
    "Mode: DRY RUN — nothing will be written. Pass --apply to commit.");

  let closed = 0;
  let alreadyClosed = 0;
  let missing = 0;
  let batch = db.batch();
  let pending = 0;

  const flush = async () => {
    if (apply && pending > 0) await batch.commit();
    batch = db.batch();
    pending = 0;
  };

  for (const uid of athleteIds) {
    const doc = await db.collection("users").doc(uid).get();
    if (!doc.exists) {
      missing++;
      continue;
    }
    const data = doc.data();
    if (data.openToRecruitment !== true) {
      alreadyClosed++;
      continue;
    }

    console.log(`  close: ${displayName(data)}  ${uid}  ${await emailOf(uid)}`);
    batch.update(doc.ref, {openToRecruitment: false});
    pending++;
    closed++;

    if (pending >= BATCH_LIMIT) await flush();
  }

  await flush();

  console.log(`  ${apply ? "closed" : "would close"} : ${closed}`);
  console.log(`  already closed : ${alreadyClosed}`);
  console.log(`  no profile doc : ${missing}`);
  if (!apply) console.log("Dry run only — re-run with --apply to commit.");
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
