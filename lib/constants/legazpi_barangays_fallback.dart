// lib/constants/legazpi_barangays_fallback.dart
//
// Offline snapshot of the Legazpi City barangay list from the Philippine
// Standard Geographic Code registry (PSGC city code 050506000), captured
// 2026-08-26. 70 barangays, in PSGC code order.
//
// BarangayService fetches the live list at runtime and falls back to this
// only when that fetch fails. The fallback exists because registration
// requires a barangay: without it, a user with no connection - or any
// outage at psgc.gitlab.io - cannot create an account at all, which is a
// real risk for a community app used on patchy mobile data.
//
// This is generated data, not hand-typed. The hand-typed catalog this
// replaced was missing barangays and misspelled others, which is what
// motivated the move to PSGC. Refresh it by re-fetching the endpoint,
// not by editing entries individually.

const List<String> kLegazpiBarangaysFallback = <String>[
  'Bgy. 47 - Arimbay',
  'Bgy. 64 - Bagacay',
  'Bgy. 48 - Bagong Abre',
  'Bgy. 66 - Banquerohan',
  'Bgy. 1 - Em\'s Barrio (Pob.)',
  'Bgy. 11 - Maoyod Pob.',
  'Bgy. 12 - Tula-tula (Pob.)',
  'Bgy. 13 - Ilawod West Pob.',
  'Bgy. 14 - Ilawod Pob.',
  'Bgy. 15 - Ilawod East Pob.',
  'Bgy. 16 - Kawit-East Washington Drive (Pob.)',
  'Bgy. 17 - Rizal Street., Ilawod (Pob.)',
  'Bgy. 19 - Cabagñan',
  'Bgy. 2 - Em\'s Barrio South (Pob.)',
  'Bgy. 18 - Cabagñan West (Pob.)',
  'Bgy. 21 - Binanuahan West (Pob.)',
  'Bgy. 22 - Binanuahan East (Pob.)',
  'Bgy. 23 - Imperial Court Subd. (Pob.)',
  'Bgy. 20 - Cabagñan East (Pob.)',
  'Bgy. 25 - Lapu-lapu (Pob.)',
  'Bgy. 26 - Dinagaan (Pob.)',
  'Bgy. 27 - Victory Village South (Pob.)',
  'Bgy. 28 - Victory Village North (Pob.)',
  'Bgy. 29 - Sabang (Pob.)',
  'Bgy. 3 - Em\'s Barrio East (Pob.)',
  'Bgy. 36 - Kapantawan (Pob.)',
  'Bgy. 30 - Pigcale (Pob.)',
  'Bgy. 31 - Centro-Baybay (Pob.)',
  'Bgy. 33 - PNR-Peñaranda St.-Iraya (Pob.)',
  'Bgy. 34 - Oro Site-Magallanes St. (Pob.)',
  'Bgy. 35 - Tinago (Pob.)',
  'Bgy. 37 - Bitano (Pob.)',
  'Bgy. 39 - Bonot (Pob.)',
  'Bgy. 4 - Sagpon Pob.',
  'Bgy. 5 - Sagmin Pob.',
  'Bgy. 6 - Bañadero Pob.',
  'Bgy. 7 - Baño (Pob.)',
  'Bgy. 8 - Bagumbayan (Pob.)',
  'Bgy. 9 - Pinaric (Pob.)',
  'Bgy. 67 - Bariis',
  'Bgy. 49 - Bigaa',
  'Bgy. 41 - Bogtong',
  'Bgy. 53 - Bonga',
  'Bgy. 69 - Buenavista',
  'Bgy. 51 - Buyuan',
  'Bgy. 70 - Cagbacong',
  'Bgy. 40 - Cruzada',
  'Bgy. 57 - Dap-dap',
  'Bgy. 45 - Dita',
  'Bgy. 55 - Estanza',
  'Bgy. 38 - Gogon',
  'Bgy. 62 - Homapon',
  'Bgy. 65 - Imalnod',
  'Bgy. 54 - Mabinit',
  'Bgy. 63 - Mariawa',
  'Bgy. 61 - Maslog',
  'Bgy. 50 - Padang',
  'Bgy. 44 - Pawa',
  'Bgy. 59 - Puro',
  'Bgy. 42 - Rawis',
  'Bgy. 68 - San Francisco',
  'Bgy. 46 - San Joaquin',
  'Bgy. 32 - San Roque',
  'Bgy. 43 - Tamaoyan',
  'Bgy. 56 - Taysan',
  'Bgy. 52 - Matanag',
  'Bgy. 10 - Cabugao',
  'Bgy. 24 - Rizal Street',
  'Bgy. 58 - Buragwis',
  'Bgy. 60 - Lamba',
];
