#!/usr/bin/env node
/**
 * Creates ready-made demo teams so a tournament bracket can be run with many
 * entrants.
 *
 * A bracket entrant is a coach's team with an accepted roster (see
 * TournamentService.buildEntrant), so testing an 8-team bracket by hand means
 * registering 8 coaches and 40 athletes, verifying 48 inboxes and accepting 40
 * invites. This does all of it in one run: each demo coach gets a full roster
 * already accepted, every account is already email-verified, and they all
 * share one password so any of them can be signed into.
 *
 *   node scripts/seed-demo-teams.js                      Dry run: 8 Basketball teams.
 *   node scripts/seed-demo-teams.js --apply              Creates them.
 *   node scripts/seed-demo-teams.js --sport Volleyball --teams 4 --apply
 *   node scripts/seed-demo-teams.js --delete             Dry run of the cleanup.
 *   node scripts/seed-demo-teams.js --delete --apply     Removes every demo account.
 *
 *   --sport    Basketball | Volleyball | Badminton   (default Basketball)
 *   --teams    1-16                                  (default 8)
 *   --players  1-15 per team   (default: the sport's minimum per side,
 *              as in lib/constants/event_min_players.dart)
 *
 * Every address is on the reserved demo.homegrown.test domain, which nobody can
 * own and which never receives mail. --delete only ever touches Auth accounts
 * on that domain, so it cannot reach a real user.
 *
 * Re-running is safe: accounts are addressed deterministically (bb-coach-01@…,
 * bb-01-player-03@…), and one that already exists is reused and left as it is,
 * so ratings and points earned while testing survive. Raising --teams adds the
 * missing teams.
 *
 * Profiles carry the same fields the registration screens write, plus
 * isDemo: true, so the app treats them exactly like real accounts.
 *
 * Auth: point GOOGLE_APPLICATION_CREDENTIALS at a service-account key for
 * homegrown-app-b71d1.
 */

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const DOMAIN = "demo.homegrown.test";
const PASSWORD = "Demo1234";

// Mirrors lib/constants/event_min_players.dart and sport_positions.dart.
const SPORTS = {
  Basketball: {
    prefix: "bb",
    minPlayers: 5,
    positions: ["Point Guard", "Shooting Guard", "Small Forward",
      "Power Forward", "Center"],
  },
  Volleyball: {
    prefix: "vb",
    minPlayers: 6,
    positions: ["Setter", "Outside Hitter", "Opposite Hitter",
      "Middle Blocker", "Libero", "Defensive Specialist"],
  },
  Badminton: {
    prefix: "bm",
    minPlayers: 1,
    positions: ["Singles", "Doubles", "Mixed Doubles"],
  },
};

// Home barangays spelled exactly as lib/constants/legazpi_barangays_fallback.dart
// has them, so they match what the app's picker would have stored.
const TEAMS = [
  ["Rawis Rockets", "Bgy. 42 - Rawis"],
  ["Bitano Bulls", "Bgy. 37 - Bitano (Pob.)"],
  ["Bogtong Blazers", "Bgy. 41 - Bogtong"],
  ["Taysan Titans", "Bgy. 56 - Taysan"],
  ["Puro Pirates", "Bgy. 59 - Puro"],
  ["Bonot Bombers", "Bgy. 39 - Bonot (Pob.)"],
  ["Cruzada Crushers", "Bgy. 40 - Cruzada"],
  ["Tamaoyan Tigers", "Bgy. 43 - Tamaoyan"],
  ["Arimbay Aces", "Bgy. 47 - Arimbay"],
  ["Bagacay Barracudas", "Bgy. 64 - Bagacay"],
  ["Buyuan Blaze", "Bgy. 51 - Buyuan"],
  ["Estanza Eagles", "Bgy. 55 - Estanza"],
  ["Gogon Guardians", "Bgy. 38 - Gogon"],
  ["Homapon Hawks", "Bgy. 62 - Homapon"],
  ["Mabinit Mavericks", "Bgy. 54 - Mabinit"],
  ["Pawa Panthers", "Bgy. 44 - Pawa"],
];

const FIRST = ["Juan", "Miguel", "Paolo", "Carlo", "Mark", "Rafael", "Joshua",
  "Kevin", "Christian", "Jericho", "Angelo", "Renz", "Kyle", "Nathan",
  "Gabriel", "Ramon", "Arvin", "Jomar", "Erwin", "Dennis", "Ronald", "Jayson",
  "Allan", "Noel", "Bryan", "Lance", "Vince", "Marvin", "Enzo", "Adrian",
  "Jerome", "Ivan"];
const LAST = ["Dela Cruz", "Santos", "Reyes", "Bautista", "Garcia", "Mendoza",
  "Villanueva", "Ramos", "Aquino", "Castillo", "Rivera", "Navarro", "Lopez",
  "Morales", "Salazar", "Tolentino", "Buenaventura", "Oliva", "Brizuela",
  "Lorica", "Mirandilla", "Nieva", "Cabrera", "Moratalla", "Llorin", "Sayson",
  "Nuñez", "Bañares", "Rañola", "Ludovice", "Barrameda"];
const ATHLETE_YEARS = ["<1 Yr", "1-2 Yrs", "3-5 Yrs", "5+ Yrs"];
const COACH_YEARS = ["1-2 Yrs", "3-5 Yrs", "5-10 Yrs", "10+ Yrs"];

// ── Arguments ─────────────────────────────────────────

const argv = process.argv.slice(2);
const apply = argv.includes("--apply");
const deleteMode = argv.includes("--delete");
const valueFor = (flag) => {
  const i = argv.indexOf(flag);
  return i === -1 ? null : argv[i + 1];
};

const sportName = valueFor("--sport") || "Basketball";
const sport = SPORTS[sportName];
if (!deleteMode && !sport) {
  console.error(`--sport must be one of ${Object.keys(SPORTS).join(", ")}.`);
  process.exit(1);
}

const teamCount = Number(valueFor("--teams") || 8);
if (!Number.isInteger(teamCount) || teamCount < 1 || teamCount > TEAMS.length) {
  console.error(`--teams must be a whole number from 1 to ${TEAMS.length}.`);
  process.exit(1);
}

const playerCount = Number(valueFor("--players") || (sport && sport.minPlayers));
if (!deleteMode &&
    (!Number.isInteger(playerCount) || playerCount < 1 || playerCount > 15)) {
  // 15 is TeamService.maxPlayers; the app refuses a bigger roster.
  console.error("--players must be a whole number from 1 to 15.");
  process.exit(1);
}

initializeApp({credential: applicationDefault(), projectId: "homegrown-app-b71d1"});
const auth = getAuth();
const db = getFirestore();

// ── Helpers ───────────────────────────────────────────

const pad = (n) => String(n).padStart(2, "0");

/** Deterministic, so a re-run gives every account the same name. */
function nameFor(team, slot) {
  return {
    firstName: FIRST[(team * 7 + slot * 3) % FIRST.length],
    lastName: LAST[(team * 5 + slot * 11 + 3) % LAST.length],
  };
}

/** The Auth user for [email], or null if there isn't one. */
async function findUser(email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (err) {
    if (err.code === "auth/user-not-found") return null;
    throw err;
  }
}

/**
 * Creates the account and its profile, or reuses an existing one untouched.
 * Returns {uid, fullName, created}; uid is null on a dry run for a new account.
 */
async function ensureAccount(email, profile) {
  const fullName = `${profile.firstName} ${profile.lastName}`;
  const existing = await findUser(email);
  if (existing) return {uid: existing.uid, fullName, created: false};
  if (!apply) return {uid: null, fullName, created: true};

  const user = await auth.createUser({
    email,
    password: PASSWORD,
    emailVerified: true,
    displayName: fullName,
  });
  await db.collection("users").doc(user.uid).set({
    uid: user.uid,
    ...profile,
    fullName,
    photoUrl: "",
    isDemo: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  // Contact details live off the public profile — see contact_service.dart.
  await db.collection("users").doc(user.uid)
      .collection("private").doc("contact").set({
        email,
        phoneNumber: "",
        updatedAt: FieldValue.serverTimestamp(),
      });
  return {uid: user.uid, fullName, created: true};
}

// ── Seeding ───────────────────────────────────────────

async function seed() {
  console.log(apply ?
    "Mode: APPLY — creating accounts in homegrown-app-b71d1." :
    "Mode: DRY RUN — nothing will change. Add --apply to commit.");
  console.log(`${teamCount} ${sportName} team(s), ${playerCount} player(s) each\n`);

  let created = 0;
  let reused = 0;
  let joined = 0;

  for (let t = 0; t < teamCount; t++) {
    const [teamName, barangay] = TEAMS[t];
    const coachEmail = `${sport.prefix}-coach-${pad(t + 1)}@${DOMAIN}`;
    const coach = await ensureAccount(coachEmail, {
      ...nameFor(t, 0),
      role: "coach",
      barangay,
      // Always a one-element list: Scout and the team pickers query it as an
      // array, and a coach handles exactly one sport.
      primarySports: [sportName],
      coachingLevel: "Barangay",
      yearsOfExperience: COACH_YEARS[t % COACH_YEARS.length],
      teamOrganization: teamName,
      coachingBio: `Head coach of the ${teamName}. Demo account.`,
      certifications: "",
    });
    coach.created ? created++ : reused++;
    console.log(`  ${teamName} — coach ${coach.fullName} <${coachEmail}>` +
      `${coach.created ? "" : " (exists)"}`);

    for (let p = 0; p < playerCount; p++) {
      const email = `${sport.prefix}-${pad(t + 1)}-player-${pad(p + 1)}@${DOMAIN}`;
      const athlete = await ensureAccount(email, {
        ...nameFor(t, p + 1),
        role: "athlete",
        barangay,
        primarySports: [sportName],
        position: sport.positions[p % sport.positions.length],
        yearsOfPlaying: ATHLETE_YEARS[(t + p) % ATHLETE_YEARS.length],
        heightCm: String(165 + ((t * 3 + p * 5) % 26)),
        weightKg: String(58 + ((t * 5 + p * 7) % 30)),
        bio: "",
        isPublic: true,
        // Already on a team, so not listed as looking for one.
        openToRecruitment: false,
        points: 0,
      });
      athlete.created ? created++ : reused++;
      console.log(`      ${athlete.fullName} <${email}>` +
        `${athlete.created ? "" : " (exists)"}`);

      // Accepted membership, in the doc id and shape TeamService writes.
      if (apply && coach.uid && athlete.uid) {
        const ref = db.collection("teamMemberships")
            .doc(`${coach.uid}_${athlete.uid}`);
        const snap = await ref.get();
        if (!snap.exists || snap.data().status !== "accepted") {
          await ref.set({
            coachId: coach.uid,
            athleteId: athlete.uid,
            coachName: coach.fullName,
            teamName,
            athleteName: athlete.fullName,
            athletePhotoUrl: null,
            status: "accepted",
            createdAt: FieldValue.serverTimestamp(),
            respondedAt: FieldValue.serverTimestamp(),
          });
          joined++;
        }
      } else if (!apply) {
        joined++;
      }
    }
  }

  console.log(`\n  accounts ${apply ? "created" : "to create"}: ${created}`);
  console.log(`  accounts already there: ${reused}`);
  console.log(`  roster places ${apply ? "filled" : "to fill"}: ${joined}`);
  if (apply) {
    console.log(`\nSign in as any of them with password ${PASSWORD}.`);
  } else {
    console.log("\nDry run only — re-run with --apply to commit.");
  }
}

// ── Cleanup ───────────────────────────────────────────

async function removeAll() {
  console.log(apply ?
    "Mode: APPLY — deleting every demo account." :
    "Mode: DRY RUN — nothing will change. Add --apply to commit.");

  const demo = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) {
      if ((u.email || "").toLowerCase().endsWith(`@${DOMAIN}`)) demo.push(u);
    }
    pageToken = page.pageToken;
  } while (pageToken);

  demo.forEach((u) => console.log(`  ${apply ? "deleting" : "would delete"}: ${u.email}`));
  const uids = demo.map((u) => u.uid);

  // Memberships whose coach or athlete is a demo account. `in` takes at most
  // 30 values, so the uids go in chunks.
  const memberships = new Map();
  for (let i = 0; i < uids.length; i += 30) {
    const chunk = uids.slice(i, i + 30);
    for (const field of ["coachId", "athleteId"]) {
      const snap = await db.collection("teamMemberships")
          .where(field, "in", chunk).get();
      snap.docs.forEach((d) => memberships.set(d.id, d.ref));
    }
  }

  console.log(`\n  demo accounts: ${uids.length}`);
  console.log(`  team memberships: ${memberships.size}`);

  if (!apply) {
    if (uids.length) console.log("\nDry run only — re-run with --apply to commit.");
    return;
  }

  for (const ref of memberships.values()) await ref.delete();
  // recursiveDelete takes the profile's subcollections (private/contact,
  // ratingHistory, media) with it.
  for (const uid of uids) await db.recursiveDelete(db.collection("users").doc(uid));
  for (let i = 0; i < uids.length; i += 1000) {
    await auth.deleteUsers(uids.slice(i, i + 1000));
  }
  console.log("\nDone. Events and tournaments that used these teams are left " +
    "as they are; remove them in the app or with reset-demo-data.js.");
}

(deleteMode ? removeAll() : seed())
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
