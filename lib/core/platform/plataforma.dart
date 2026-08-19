import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// A Apple proíbe checkout externo (Mercado Pago) pra conteúdo digital
/// desbloqueado dentro do app (regra 3.1.1, "In-App Purchase") -- até
/// implementar Apple IAP de verdade, o iOS não oferece assinatura nova
/// dentro do app. Quem já assina pelo Android ou pelo site continua
/// usando o plano pago no iOS normalmente (a assinatura é da fazenda,
/// não do aparelho); só a tela de "assinar agora" fica escondida.
bool get ofereceCheckoutNoApp => kIsWeb || !Platform.isIOS;
