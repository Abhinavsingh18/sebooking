import 'package:flutter/foundation.dart';

class Config {
  static const String _localUrl = "https://api.sebooking.in";
  static const String _prodUrl = "https://api.sebooking.in";

  static String get baseUrl => kReleaseMode ? _prodUrl : _localUrl;
}
