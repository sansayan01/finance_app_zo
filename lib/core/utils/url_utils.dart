import 'url_utils_stub.dart'
    if (dart.library.html) 'url_utils_web.dart' as platform;

/// Replaces the browser URL without reload (web) or no-op (mobile).
void replaceUrl(String url) => platform.replaceUrl(url);
