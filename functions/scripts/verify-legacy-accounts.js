#!/usr/bin/env node
/**
 * Marks pre-existing Firebase Auth accounts as email-verified.
 *
 * Email verification is now enforced at sign-in (see lib/utils/auth_routing.dart).
 * Every account created before that shipped is almost certainly unverified, so
 * on their next sign-in those people are held on the verification screen.
 *
 * Most can get themselves out: the screen has a Resend Email button, and it
 * polls every few seconds, so a real person with a real inbox just taps resend
 * and clicks the link. This script is for the ones that cannot — test accounts
 * on addresses nobody owns, which would otherwise be permanently unusable, and
 * early real users you would rather not make re-verify.
 *
 * There is no "mark verified" control in the Firebase console; only the Admin
 * SDK can set this flag, which is why this exists as a script.
 *
 *   node scripts/verify-legacy-accounts.js --before 2026-09-03
 *       Dry run. Lists accounts created before that date that would be flipped.
 *
 *   node scripts/verify-legacy-accounts.js --before 2026-09-03 --apply
 *       Commits it.
 *
 *   node scripts/verify-legacy-accounts.js --email ed@gmail.com --apply
 *       Just the named accounts. Repeat --email for several.
 *
 * One of --before, --email or --all is required: verifying every account in the
 * project is a decision that should have to be spelled out, not something you
 * get by forgetting an argument.
 *
 * Auth: point GOOGLE_APPLICATION_CREDENTIALS at a service-account key for
 * homegrown-app-b71d1.
 */

// firebase-admin 13+ dropped the old `admin.auth()` / `admin.credential`
// namespace in favour of these subpath exports. Importing the root package and
// reaching for .credential fails with an unhelpful "cannot read properties of
// undefined" before any of your arguments are even parsed.
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

const argv = process.argv.slice(2);
const apply = argv.includes("--apply");
const all = argv.includes("--all");

const valueFor = (flag) => {
  const i = argv.indexOf(flag);
  return i === -1 ? null : argv[i + 1];
};
const valuesFor = (flag) => {
  const out = [];
  argv.forEach((a, i) => {
    if (a === flag && argv[i + 1]) out.push(argv[i + 1].toLowerCase());
  });
  return out;
};

const beforeRaw = valueFor("--before");
const emails = valuesFor("--email");

if (!all && !beforeRaw && emails.length === 0) {
  console.error(
      "Refusing to run without a filter. Pass --before <YYYY-MM-DD>, " +
      "--email <address> (repeatable), or --all.");
  process.exit(1);
}

let before = null;
if (beforeRaw) {
  before = new Date(beforeRaw);
  if (Number.isNaN(before.getTime())) {
    console.error(`--before: "${beforeRaw}" is not a date I can read.`);
    process.exit(1);
  }
}

initializeApp({credential: applicationDefault()});
const auth = getAuth();

async function main() {
  console.log(apply ?
    "Mode: APPLY" :
    "Mode: DRY RUN — nothing will change. Add --apply to commit.");
  if (before) console.log(`Filter: created before ${before.toISOString()}`);
  if (emails.length) console.log(`Filter: ${emails.length} named address(es)`);
  if (all) console.log("Filter: ALL accounts");

  let pageToken;
  let flipped = 0;
  let alreadyVerified = 0;
  let outsideFilter = 0;

  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      if (user.emailVerified) {
        alreadyVerified++;
        continue;
      }
      // An account with no email address has nothing to verify.
      if (!user.email) {
        outsideFilter++;
        continue;
      }

      const created = new Date(user.metadata.creationTime);
      const matches = all ||
        (emails.length > 0 && emails.includes(user.email.toLowerCase())) ||
        (before !== null && emails.length === 0 && created < before);

      if (!matches) {
        outsideFilter++;
        continue;
      }

      console.log(
          `  ${apply ? "verifying" : "would verify"}: ${user.email} ` +
          `(created ${created.toISOString().slice(0, 10)})`);
      if (apply) await auth.updateUser(user.uid, {emailVerified: true});
      flipped++;
    }
    pageToken = page.pageToken;
  } while (pageToken);

  console.log(`\n  ${apply ? "verified" : "would verify"} : ${flipped}`);
  console.log(`  already verified : ${alreadyVerified}`);
  console.log(`  skipped by filter : ${outsideFilter}`);
  if (!apply && flipped > 0) {
    console.log("\nDry run only — re-run with --apply to commit.");
  }
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
