/// A venue's identity and exact map location — whether it came from
/// a Places API search result or a manually dropped map pin.
class Venue {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String type;

  const Venue({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
  });
}
