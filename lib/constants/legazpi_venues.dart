// lib/constants/legazpi_venues.dart

class LegazpiVenue {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String type;

  const LegazpiVenue({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
  });
}

const List<LegazpiVenue> kLegazpiVenues = [
  // ── Major Sports Facilities ──────────────
  LegazpiVenue(
    name:    'Legazpi Sports Complex',
    address: 'Legazpi City Sports Complex, Legazpi City, Albay',
    lat:     13.1420,
    lng:     123.7391,
    type:    'Sports Complex',
  ),
  LegazpiVenue(
    name:    'Legazpi City Astrodome',
    address: '12 Doña Aurora St, Old Albay District, Legazpi City, Albay',
    lat:     13.1399186,
    lng:     123.7349998,
    type:    'Indoor Arena',
  ),
  LegazpiVenue(
    name:    'Ibalong Centrum for Recreation',
    address: 'Legazpi Port District, Legazpi City, Albay',
    lat:     13.144195,
    lng:     123.746363,
    type:    'Indoor Arena',
  ),
  LegazpiVenue(
    name:    'Peñaranda Park',
    address: 'Peñaranda Park, Legazpi City, Albay',
    lat:     13.1403,
    lng:     123.7438,
    type:    'Park',
  ),

  // ── Barangay Courts & Gyms ───────────────
  LegazpiVenue(
    name:    'Sagumbayan Basketball Court',
    address: 'Sagumbayan, Legazpi City, Albay',
    lat:     13.1310,
    lng:     123.7450,
    type:    'Basketball Court',
  ),
  LegazpiVenue(
    name:    'Bonot Covered Court',
    address: 'Bonot, Legazpi City, Albay',
    lat:     13.1280,
    lng:     123.7480,
    type:    'Covered Court',
  ),
  LegazpiVenue(
    name:    'Rawis Sports Center',
    address: 'Rawis, Legazpi City, Albay',
    lat:     13.1270,
    lng:     123.7500,
    type:    'Sports Center',
  ),
  LegazpiVenue(
    name:    'Gogon Gymnasium',
    address: 'Gogon, Legazpi City, Albay',
    lat:     13.1500,
    lng:     123.7360,
    type:    'Gymnasium',
  ),
  LegazpiVenue(
    name:    'Taysan Gymnasium',
    address: 'Taysan, Legazpi City, Albay',
    lat:     13.1450,
    lng:     123.7460,
    type:    'Gymnasium',
  ),
  LegazpiVenue(
    name:    'Cabangan Sports Center',
    address: 'Cabangan, Legazpi City, Albay',
    lat:     13.1330,
    lng:     123.7520,
    type:    'Sports Center',
  ),
  LegazpiVenue(
    name:    'Landing Sports Complex',
    address: 'Landco, Legazpi City, Albay',
    lat:     13.1370,
    lng:     123.7420,
    type:    'Sports Complex',
  ),
  LegazpiVenue(
    name:    'Buyuan Covered Court',
    address: 'Buyuan, Legazpi City, Albay',
    lat:     13.1250,
    lng:     123.7350,
    type:    'Covered Court',
  ),
  LegazpiVenue(
    name:    'Bigaa Sports Center',
    address: 'Bigaa, Legazpi City, Albay',
    lat:     13.1180,
    lng:     123.7420,
    type:    'Sports Center',
  ),
  LegazpiVenue(
    name:    'Arimbay Covered Court',
    address: 'Arimbay, Legazpi City, Albay',
    lat:     13.1460,
    lng:     123.7480,
    type:    'Covered Court',
  ),
  LegazpiVenue(
    name:    'Kawit Gymnasium',
    address: 'Kawit, Legazpi City, Albay',
    lat:     13.1100,
    lng:     123.7350,
    type:    'Gymnasium',
  ),
  LegazpiVenue(
    name:    'Pawa Basketball Court',
    address: 'Pawa, Legazpi City, Albay',
    lat:     13.1550,
    lng:     123.7310,
    type:    'Basketball Court',
  ),
  LegazpiVenue(
    name:    'Dita Covered Court',
    address: 'Dita, Legazpi City, Albay',
    lat:     13.1480,
    lng:     123.7530,
    type:    'Covered Court',
  ),
  LegazpiVenue(
    name:    'Estancia Sports Area',
    address: 'Estancia, Legazpi City, Albay',
    lat:     13.1390,
    lng:     123.7580,
    type:    'Sports Area',
  ),
  LegazpiVenue(
    name:    'Linao Sports Area',
    address: 'Linao, Legazpi City, Albay',
    lat:     13.1520,
    lng:     123.7400,
    type:    'Sports Area',
  ),

  // ── Schools & Universities ───────────────
  LegazpiVenue(
    name:    'Divine Word College of Legazpi Gym',
    address: 'Divine Word College, Legazpi City, Albay',
    lat:     13.1397,
    lng:     123.7356,
    type:    'School Gymnasium',
  ),
  LegazpiVenue(
    name:    'Aquinas University Gymnasium',
    address: 'Aquinas University, Legazpi City, Albay',
    lat:     13.1402,
    lng:     123.7441,
    type:    'School Gymnasium',
  ),
  LegazpiVenue(
    name:    'Legazpi City National High School Court',
    address: 'LCNHS, Legazpi City, Albay',
    lat:     13.1360,
    lng:     123.7445,
    type:    'School Court',
  ),
];