/// Validates the configured API origin before any credentials are transmitted.
///
/// Local HTTP remains available for development previews, including phones
/// connecting to a developer's LAN machine. Release builds require HTTPS.
class ApiEndpointPolicy {
  ApiEndpointPolicy._();

  static Uri validate(String rawBase, {required bool releaseMode}) {
    final value = rawBase.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Invalid CampusOS API address.');
    }
    if (releaseMode && uri.scheme != 'https') {
      throw const FormatException('CampusOS release builds require an HTTPS API.');
    }
    // Do not accept URLs that could silently change the expected API route.
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const FormatException('CampusOS API address must be an origin only.');
    }
    return uri.replace(path: '', query: null, fragment: null);
  }
}
