import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ManejoRascunhoService {
  static const _key = 'manejo_rascunho';

  static Future<void> salvar({
    required String tipo,
    required String? data,
    required int? invernadaId,
    required String produto,
    required String dosagem,
    required String responsavel,
    required String observacoes,
    required List<int> bovinoIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'tipo': tipo,
        'data': data,
        'invernadaId': invernadaId,
        'produto': produto,
        'dosagem': dosagem,
        'responsavel': responsavel,
        'observacoes': observacoes,
        'bovinoIds': bovinoIds,
      }),
    );
  }

  static Future<Map<String, dynamic>?> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> limpar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<bool> temRascunho() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}
