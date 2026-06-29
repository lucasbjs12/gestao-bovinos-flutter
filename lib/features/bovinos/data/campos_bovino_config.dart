import 'package:shared_preferences/shared_preferences.dart';

enum CampoBovino {
  nomeAnimal,
  raca,
  pesoAtual,
  dataNascimento,
  pelagem,
  origem,
  invernada,
  codigoEpc,
  codigoInterno,
  observacoes,
}

extension CampoBotinoLabel on CampoBovino {
  String get label => switch (this) {
        CampoBovino.nomeAnimal     => 'Nome do animal',
        CampoBovino.raca           => 'Raça',
        CampoBovino.pesoAtual      => 'Peso atual',
        CampoBovino.dataNascimento => 'Data de nascimento',
        CampoBovino.pelagem        => 'Pelagem',
        CampoBovino.origem         => 'Origem',
        CampoBovino.invernada      => 'Invernada',
        CampoBovino.codigoEpc      => 'Código EPC',
        CampoBovino.codigoInterno  => 'Código interno',
        CampoBovino.observacoes    => 'Observações',
      };
}

class CamposBovinoConfig {
  static const _prefix = 'campo_bovino_';

  static Future<Map<CampoBovino, bool>> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final c in CampoBovino.values)
        c: prefs.getBool('$_prefix${c.name}') ?? true,
    };
  }

  static Future<void> salvar(Map<CampoBovino, bool> config) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in config.entries) {
      await prefs.setBool('$_prefix${entry.key.name}', entry.value);
    }
  }

  static Future<void> restaurarPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in CampoBovino.values) {
      await prefs.remove('$_prefix${c.name}');
    }
  }
}
