import 'package:shared_preferences/shared_preferences.dart';

import '../models/domain_models.dart';

class SessionStore {
  static const String _sessionKey = 'satelitrack_native_session_v1';

  Future<UserSession?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return UserSession.fromJsonString(prefs.getString(_sessionKey));
  }

  Future<void> save(UserSession session) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, session.toJsonString());
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
