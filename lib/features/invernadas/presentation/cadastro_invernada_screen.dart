import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../data/invernada.dart';
import '../data/invernada_local_repository.dart';
import '../data/invernada_remote_repository.dart';
import '../invernadas_provider.dart';

class CadastroInvernadaScreen extends StatefulWidget {
  const CadastroInvernadaScreen({super.key});

  @override
  State<CadastroInvernadaScreen> createState() =>
      _CadastroInvernadaScreenState();
}

class _CadastroInvernadaScreenState extends State<CadastroInvernadaScreen> {
  String? _uid;
  int? _invernadaId;
  bool _carregando = false;

  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  Invernada? _invernadaOriginal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _uid = context.read<AuthProvider>().currentUser?.uid;
      _invernadaId = ModalRoute.of(context)?.settings.arguments as int?;
      if (_invernadaId != null) await _carregar();
    });
  }

  Future<void> _carregar() async {
    if (_uid == null || _invernadaId == null) return;
    final db = await AppDatabase.instance.instanceFor(_uid);
    final inv = await InvernadaLocalRepository(db).buscarPorId(_invernadaId!);
    if (inv == null || !mounted) return;
    _invernadaOriginal = inv;
    setState(() {
      _descricaoCtrl.text = inv.descricao;
      _obsCtrl.text = inv.observacoes ?? '';
    });
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uid == null) return;

    setState(() => _carregando = true);
    try {
      final db = await AppDatabase.instance.instanceFor(_uid);
      final repo = InvernadaLocalRepository(db);

      final descricao = _descricaoCtrl.text.trim();
      final obs = _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim();

      Invernada invernada;
      if (_invernadaId == null) {
        final nova = Invernada.criar(descricao: descricao).copyWith();
        // Use full constructor to include observacoes
        invernada = Invernada(
          syncId: nova.syncId,
          descricao: descricao,
          observacoes: obs,
        );
        final newId = await repo.inserir(invernada);
        invernada = invernada.copyWith(id: newId);
      } else {
        invernada = Invernada(
          id: _invernadaId,
          syncId: _invernadaOriginal!.syncId,
          descricao: descricao,
          urlFoto: _invernadaOriginal?.urlFoto,
          observacoes: obs,
        );
        await repo.atualizar(invernada);
      }

      if (mounted) {
        InvernadaRemoteRepository(
          uid: _uid!,
          sync: context.read<SyncStatusService>(),
        ).salvar(invernada);
        context.read<InvernadasProvider>().recarregar();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _invernadaId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar invernada' : 'Nova invernada'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _descricaoCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fence_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a descrição.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obsCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _carregando ? null : _salvar,
                icon: _carregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isEdit ? 'Atualizar' : 'Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
