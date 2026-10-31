/// A deliberately coarse distance label. Exact distances can be used to locate
/// a person, so the UI only ever shows bands.
String approximateDistanceLabel(int km) {
  if (km <= 1) return 'Less than 1 km away';
  if (km <= 5) return 'Within 5 km';
  final band = ((km + 4) ~/ 5) * 5;
  return 'Within $band km';
}
