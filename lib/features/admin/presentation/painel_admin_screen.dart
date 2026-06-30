import 'package:flutter/material.dart';

import '../data/assinatura_service.dart';
import '../data/usuario_assinatura.dart';

class PainelAdminScreen extends StatefulWidget {
  const PainelAdminScreen({super.key});

  @override
  State<PainelAdminScreen> createState() => _PainelAdminScreenState();
}

class _PainelAdminScreenState extends State<PainelAdminScreen> {
  List<UsuarioAssinatura> _usuarios = [];
  bool _carregando = true;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final lista = await AssinaturaService.listarTodos();
    if (mounted) setState(() { _usuarios = lista; _carregando = false; });
  }

  List<UsuarioAssinatura> get _filtrados {
    if (_busca.isEmpty) return _usuarios;
    final t = _busca.toLowerCase();
    return _usuarios
        .where((u) =>
            u.nome.toLowerCase().contains(t) ||
            u.email.toLowerCase().contains(t))
        .toList();
  }

  Future<void> _abrirAtivar(UsuarioAssinatura u) async {
    final planos = ['Mensal', 'Trimestral', 'Semestral', 'Anual'];
    String planoSel = planos.first;
    DateTime vencimento = DateTime.now().add(const Duration(days: 30));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Ativar acesso — ${u.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: planoSel,
                decoration: const InputDecoration(
                  labelText: 'Plano',
                  border: OutlineInputBorder(),
                ),
                items: planos
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setSt(() {
                    planoSel = v;
                    vencimento = DateTime.now().add(Duration(
                      days: switch (v) {
                        'Trimestral' => 90,
                        'Semestral'  => 180,
                        'Anual'      => 365,
                        _            => 30,
                      },
                    ));
                  });
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vencimento'),
                subtitle: Text(
                  '${vencimento.day.toString().padLeft(2, '0')}/'
                  '${vencimento.month.toString().padLeft(2, '0')}/'
                  '${vencimento.year}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: vencimento,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDatePickerMode: DatePickerMode.day,
                  );
                  if (d != null) setSt(() => vencimento = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ativar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    await AssinaturaService.ativar(
      uid: u.uid,
      plano: planoSel,
      vencimento: vencimento,
    );
    await _carregar();
  }

  Future<void> _bloquear(UsuarioAssinatura u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear usuário'),
        content: Text('Bloquear o acesso de ${u.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AssinaturaService.bloquear(u.uid);
    await _carregar();
  }

  Future<void> _toggleAdmin(UsuarioAssinatura u) async {
    final acao = u.isAdmin ? 'remover admin de' : 'tornar admin';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${u.isAdmin ? 'Remover' : 'Promover'} admin'),
        content: Text('Deseja $acao ${u.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AssinaturaService.toggleAdmin(u.uid, !u.isAdmin);
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _busca = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou e-mail…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  '${_filtrados.length} usuário${_filtrados.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _UsuarioCard(
                        usuario: _filtrados[i],
                        onAtivar: () => _abrirAtivar(_filtrados[i]),
                        onBloquear: () => _bloquear(_filtrados[i]),
                        onToggleAdmin: () => _toggleAdmin(_filtrados[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  final UsuarioAssinatura usuario;
  final VoidCallback onAtivar;
  final VoidCallback onBloquear;
  final VoidCallback onToggleAdmin;

  const _UsuarioCard({
    required this.usuario,
    required this.onAtivar,
    required this.onBloquear,
    required this.onToggleAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = usuario;
    final status = u.statusEfetivo;

    final (statusLabel, statusColor) = switch (status) {
      StatusAssinatura.ativo     => ('Ativo', const Color(0xFF2E7D32)),
      StatusAssinatura.pendente  => ('Pendente', const Color(0xFFE65100)),
      StatusAssinatura.bloqueado => ('Bloqueado', cs.error),
      StatusAssinatura.vencido   => ('Vencido', cs.error),
    };

    String? subtitulo;
    if (status == StatusAssinatura.ativo && u.vencimento != null) {
      final dias = u.diasParaVencer;
      subtitulo = dias <= 7
          ? '⚠️ Vence em $dias dia${dias == 1 ? '' : 's'}'
          : 'Vence em ${u.vencimento!.day.toString().padLeft(2, '0')}/'
              '${u.vencimento!.month.toString().padLeft(2, '0')}/'
              '${u.vencimento!.year}  ·  ${u.plano}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              u.nome.isEmpty ? u.email : u.nome,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (u.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u.email,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _AcaoBtn(
                  label: status == StatusAssinatura.ativo ? 'Renovar' : 'Ativar',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF2E7D32),
                  onTap: onAtivar,
                ),
                const SizedBox(width: 8),
                if (status != StatusAssinatura.bloqueado)
                  _AcaoBtn(
                    label: 'Bloquear',
                    icon: Icons.block_outlined,
                    color: cs.error,
                    onTap: onBloquear,
                  ),
                const Spacer(),
                IconButton(
                  tooltip: u.isAdmin ? 'Remover admin' : 'Tornar admin',
                  icon: Icon(
                    u.isAdmin ? Icons.shield : Icons.shield_outlined,
                    size: 20,
                    color: u.isAdmin ? cs.primary : cs.onSurfaceVariant,
                  ),
                  onPressed: onToggleAdmin,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AcaoBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AcaoBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
