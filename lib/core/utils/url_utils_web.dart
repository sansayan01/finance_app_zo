// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation: replaces the browser URL without reload.
void replaceUrl(String url) {
  html.window.history.replaceState(null, '', url);
}
