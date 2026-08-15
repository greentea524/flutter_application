// Big 2 (大老二) Player Stats & LocalStorage Persistence — #15
import 'dart:convert';
import 'package:localstorage/localstorage.dart';

class Big2Stats {
  int gamesPlayed;
  int gamesWon;

  Big2Stats({this.gamesPlayed = 0, this.gamesWon = 0});

  int get winRate => gamesPlayed > 0 ? ((gamesWon / gamesPlayed) * 100).round() : 0;

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
      };

  factory Big2Stats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Big2Stats();
    return Big2Stats(
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      gamesWon: json['gamesWon'] as int? ?? 0,
    );
  }

  static const String storageKey = 'big2_stats';

  static Big2Stats load() {
    try {
      final raw = localStorage.getItem(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return Big2Stats.fromJson(decoded);
        }
      }
    } catch (_) {}
    return Big2Stats();
  }

  void save() {
    try {
      localStorage.setItem(storageKey, jsonEncode(toJson()));
    } catch (_) {}
  }

  static void recordGame(bool isWin) {
    final stats = load();
    stats.gamesPlayed += 1;
    if (isWin) {
      stats.gamesWon += 1;
    }
    stats.save();
  }
}
