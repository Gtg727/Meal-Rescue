import 'package:url_launcher/url_launcher.dart';

/// Opens the pickup location in the user's maps app / browser.
/// No location permission is needed: the address is passed as a search query.
Future<bool> openInMaps({
  required String address,
  double? latitude,
  double? longitude,
}) async {
  final query = (latitude != null && longitude != null)
      ? '$latitude,$longitude'
      : Uri.encodeComponent(address);
  final uri =
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
