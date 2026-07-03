import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

/// Upload assinado: a assinatura é gerada pela Cloud Function
/// `assinarUploadCloudinary`, que exige usuário logado. O API secret
/// do Cloudinary nunca fica no app.
class CloudinaryService {
  static const _cloudName = 'duseg2d1m';

  static Future<String> upload(File file) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'southamerica-east1',
    ).httpsCallable('assinarUploadCloudinary');

    final res = await callable.call().timeout(const Duration(seconds: 30));
    final assinatura = Map<String, dynamic>.from(res.data as Map);

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
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
