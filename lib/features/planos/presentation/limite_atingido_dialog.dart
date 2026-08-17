import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';

/// Mostrado quando o produtor tenta cadastrar um animal além do limite do
/// plano. Os animais já cadastrados nunca são tocados -- só o próximo
/// cadastro é bloqueado (a checagem de verdade é sempre do backend; isso
/// aqui só evita criar localmente algo que o servidor rejeitaria depois).
Future<void> mostrarLimiteAtingidoDialog(BuildContext context, {required int limite}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.workspace_premium_outlined, color: Theme.of(ctx).colorScheme.primary),
      title: const Text('Você atingiu o limite do seu plano'),
      content: Text(
        'Seu plano atual permite gerenciar até $limite animais. Faça upgrade do seu plano '
        'para continuar cadastrando animais e tenha mais liberdade para gerenciar seu rebanho.',
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pushNamed(context, AppRoutes.planos);
          },
          child: const Text('Ver planos'),
        ),
      ],
    ),
  );
}
