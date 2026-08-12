import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';

/// Upload assinado: a assinatura é gerada pelo backend próprio
/// (`GET /fazendas/:fazendaId/upload/assinar`), que exige usuário
/// autenticado. O API secret do Cloudinary nunca fica no app.
class CloudinaryService {
  static Future<String> upload(File file, {required String fazendaId, ApiClient? apiClient}) async {
    final client = apiClient ?? ApiClient();
    final assinatura = await client.get('/fazendas/$fazendaId/uploads/assinar') as Map<String, dynamic>;

    final uri = Uri.parse(assinatura['uploadUrl'] as String);
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = assinatura['apiKey'] as String
      ..fields['timestamp'] = '${assinatura['timestamp']}'
      ..fields['folder'] = assinatura['folder'] as String
      ..fields['signature'] = assinatura['signature'] as String
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    if (streamed.statusCode != 200) {
      throw Exception('Cloudinary upload falhou: ${streamed.statusCode}');
    }
    final body = await streamed.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;
    if (url == null) throw Exception('Cloudinary: secure_url ausente na resposta');
    return url;
  }
}
