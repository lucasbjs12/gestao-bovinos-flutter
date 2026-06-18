import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/storage/cloudinary_service.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../../core/utils/photo_service.dart';
import '../../auth/auth_provider.dart';
import '../../invernadas/data/invernada.dart';
import '../../invernadas/data/invernada_local_repository.dart';
import '../../invernadas/data/invernada_remote_repository.dart';
import '../../invernadas/data/movimentacao_invernada.dart';
import '../data/bovino.dart';
import '../data/bovino_local_repository.dart';
import '../data/bovino_remote_repository.dart';

class CadastroBovinoScreen extends StatefulWidget {
  const CadastroBovinoScreen({super.key});

  @override
  State<CadastroBovinoScreen> createState() => _CadastroBovinoScreenState();
}

class _CadastroBovinoScreenState extends State<CadastroBovinoScreen> {
  // ── Contexto ─────────────────────────────────────────────────────────────────
  String? _uid;
  int? _bovinoId;
  int? _idMaePrefilled;
  int? _idMaeExistente;
  bool _carregando = false;
  bool _maisDetalhes = false;

  // Muda para forçar recriação dos DropdownButtonFormField no modo edição
  Key _formBodyKey = const ValueKey(false);

  // ── Form ─────────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _brincoCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _racaCtrl = TextEditingController();
  final _epcCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _origemCtrl = TextEditingController();
  final _pelagemCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _dataCtrl = TextEditingController();

  String? _categoria;
  String? _sexo;
  String _status = 'Ativo';
  DateTime? _dataNascimento;
  bool _estaDeCria = false;

  // ── Invernada ─────────────────────────────────────────────────────────────────
  List<Invernada> _invernadas = [];
  int? _invernadaId;
  int? _invernadaIdOriginal;

  // ── Foto ──────────────────────────────────────────────────────────────────────
  File? _fotoLocal;
  String? _fotoExistente;
  bool _fotoRemovida = false;

  static const _categorias = [
    'Vaca', 'Novilha', 'Terneira', 'Terneiro(a)',
    'Terneiro', 'Novilho', 'Touro', 'Boi',
  ];
  static const _sexos = ['Fêmea', 'Macho'];
  static const _statusOpcoes = ['Ativo', 'Em quarentena'];

  bool get _ehFemea =>
      _sexo == 'Fêmea' ||
      (_categoria != null &&
          ['Vaca', 'Novilha', 'Terneira'].contains(_categoria));

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _uid = context.read<AuthProvider>().currentUser?.uid;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _bovinoId = args;
      } else if (args is Map<String, dynamic>) {
        _idMaePrefilled = args['idMae'] as int?;
      }
      await _carregarInvernadas();
      if (_bovinoId != null) await _carregarBovino();
    });
  }

  Future<void> _carregarInvernadas() async {
    if (_uid == null || !mounted) return;
    final db = await AppDatabase.instance.instanceFor(_uid);
    final lista = await InvernadaLocalRepository(db).listar();
    if (!mounted) return;
    setState(() => _invernadas = lista);
  }

  Future<void> _carregarBovino() async {
    if (_uid == null || _bovinoId == null) return;
    final db = await AppDatabase.instance.instanceFor(_uid);
    final b = await BovinoLocalRepository(db).buscarPorId(_bovinoId!);
    if (b == null || !mounted) return;

    setState(() {
      _brincoCtrl.text = b.numeroBrinco;
      _nomeCtrl.text = b.nomeAnimal ?? '';
      _racaCtrl.text = b.raca ?? '';
      _epcCtrl.text = b.codigoEpc ?? '';
      _pesoCtrl.text = b.pesoAtualKg != null ? '${b.pesoAtualKg}' : '';
      _origemCtrl.text = b.origem ?? '';
      _pelagemCtrl.text = b.pelagem ?? '';
      _obsCtrl.text = b.observacoes ?? '';
      _categoria = b.categoria;
      _sexo = b.sexo;
      _status = b.status;
      _estaDeCria = b.estaDeCria == 1;
      _idMaeExistente = b.idMae;
      _fotoExistente = b.foto;
      _invernadaId = b.invernadaId;
      _invernadaIdOriginal = b.invernadaId;
      if (b.dataNascimentoMillis != null) {
        _dataNascimento =
            DateTime.fromMillisecondsSinceEpoch(b.dataNascimentoMillis!);
        _dataCtrl.text = _formatarData(_dataNascimento!);
      }
      // Força recriação dos dropdowns para que iniciem com os valores corretos
      _formBodyKey = const ValueKey(true);
    });
  }

  @override
  void dispose() {
    _brincoCtrl.dispose();
    _nomeCtrl.dispose();
    _racaCtrl.dispose();
    _epcCtrl.dispose();
    _pesoCtrl.dispose();
    _origemCtrl.dispose();
    _pelagemCtrl.dispose();
    _obsCtrl.dispose();
    _dataCtrl.dispose();
    super.dispose();
  }

  // ── Salvar ────────────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uid == null) return;

    setState(() => _carregando = true);
    try {
      final db = await AppDatabase.instance.instanceFor(_uid);
      final repo = BovinoLocalRepository(db);

      final brinco = _brincoCtrl.text.trim();
      if (await repo.brincoEmUso(brinco, excluirId: _bovinoId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este brinco já está em uso.')),
        );
        return;
      }

      // Foto — tenta Cloudinary; em offline salva comprimida localmente
      String? fotoFinal;
      if (_fotoLocal != null) {
        try {
          fotoFinal = await CloudinaryService.upload(_fotoLocal!);
        } catch (_) {
          fotoFinal = await PhotoService.saveCompressed(_fotoLocal!, _uid!);
        }
        if (_fotoExistente != null) PhotoService.deleteIfLocal(_fotoExistente);
      } else if (!_fotoRemovida) {
        fotoFinal = _fotoExistente;
      } else {
        PhotoService.deleteIfLocal(_fotoExistente);
      }

      final peso = double.tryParse(_pesoCtrl.text.replaceAll(',', '.'));

      // Recuperar syncId existente em modo edição
      String syncId;
      if (_bovinoId != null) {
        syncId = (await repo.buscarPorId(_bovinoId!))?.syncId ?? Bovino.criar(numeroBrinco: brinco).syncId;
      } else {
        syncId = Bovino.criar(numeroBrinco: brinco).syncId;
      }

      final bovino = Bovino(
        id: _bovinoId,
        syncId: syncId,
        numeroBrinco: brinco,
        nomeAnimal:
            _nomeCtrl.text.trim().isEmpty ? null : _nomeCtrl.text.trim(),
        codigoEpc:
            _epcCtrl.text.trim().isEmpty ? null : _epcCtrl.text.trim(),
        raca: _racaCtrl.text.trim().isEmpty ? null : _racaCtrl.text.trim(),
        sexo: _sexo,
        categoria: _categoria,
        status: _status,
        pesoAtualKg: peso,
        pelagem: _pelagemCtrl.text.trim().isEmpty
            ? null
            : _pelagemCtrl.text.trim(),
        origem: _origemCtrl.text.trim().isEmpty
            ? null
            : _origemCtrl.text.trim(),
        observacoes:
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        foto: fotoFinal,
        dataNascimentoMillis: _dataNascimento?.millisecondsSinceEpoch,
        dataNascimento: _dataNascimento != null
            ? _formatarData(_dataNascimento!)
            : null,
        estaDeCria: _estaDeCria ? 1 : 0,
        invernadaId: _invernadaId,
        idMae: _bovinoId == null ? _idMaePrefilled : _idMaeExistente,
      );

      Bovino bovinoComId;
      if (_bovinoId == null) {
        final newId = await repo.inserir(bovino);
        bovinoComId = bovino.copyWith(id: newId);
      } else {
        await repo.atualizar(bovino);
        bovinoComId = bovino;
      }

      // Registra movimentação de invernada quando o campo muda em edição
      if (_bovinoId != null && _invernadaId != _invernadaIdOriginal) {
        final now = DateTime.now();
        final mov = MovimentacaoInvernada(
          bovinoId: bovinoComId.id!,
          data: _formatarData(now),
          dataMillis: now.millisecondsSinceEpoch,
          invernadaAnteriorId: _invernadaIdOriginal,
          novaInvernadaId: _invernadaId,
        );
        final movId = await InvernadaLocalRepository(db).inserirMovimentacao(mov);
        if (mounted) {
          InvernadaRemoteRepository(
            uid: _uid!,
            sync: context.read<SyncStatusService>(),
          ).salvarMovimentacao(mov, movId);
        }
      }

      // Fire-and-forget para o Firestore
      if (mounted) {
        BovinoRemoteRepository(
          uid: _uid!,
          sync: context.read<SyncStatusService>(),
        ).salvar(bovinoComId);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ── Foto ──────────────────────────────────────────────────────────────────────

  Future<void> _pickFoto(ImageSource source) async {
    final file = source == ImageSource.camera
        ? await PhotoService.pickFromCamera()
        : await PhotoService.pickFromGallery();
    if (file != null && mounted) {
      setState(() {
        _fotoLocal = file;
        _fotoRemovida = false;
      });
    }
  }

  void _removerFoto() => setState(() {
        _fotoLocal = null;
        _fotoRemovida = true;
      });

  // ── Data ──────────────────────────────────────────────────────────────────────

  Future<void> _pickData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dataNascimento = picked;
        _dataCtrl.text = _formatarData(picked);
      });
    }
  }

  String _formatarData(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = _bovinoId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar animal' : 'Novo animal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: KeyedSubtree(
            key: _formBodyKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Foto ──────────────────────────────────────────────────
                _FotoSection(
                  fotoLocal: _fotoLocal,
                  fotoExistente: _fotoRemovida ? null : _fotoExistente,
                  onCamera: () => _pickFoto(ImageSource.camera),
                  onGallery: () => _pickFoto(ImageSource.gallery),
                  onRemover: _removerFoto,
                ),
                const SizedBox(height: 20),

                // ── Dados principais ──────────────────────────────────────
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoria *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categorias
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoria = v),
                  validator: (v) =>
                      v == null ? 'Selecione a categoria.' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _brincoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Número do Brinco *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o brinco.'
                      : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome do animal',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pets_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _racaCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Raça',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _sexo,
                  decoration: const InputDecoration(
                    labelText: 'Sexo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.transgender_outlined),
                  ),
                  items: _sexos
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _sexo = v),
                ),
                const SizedBox(height: 12),

                // ── Invernada ─────────────────────────────────────────────
                DropdownButtonFormField<int?>(
                  initialValue: _invernadaId,
                  decoration: const InputDecoration(
                    labelText: 'Invernada',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fence_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sem invernada'),
                    ),
                    ..._invernadas.map(
                      (i) => DropdownMenuItem<int?>(
                        value: i.id,
                        child: Text(i.descricao),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _invernadaId = v),
                ),
                const SizedBox(height: 4),

                // ── Mais detalhes toggle ──────────────────────────────────
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _maisDetalhes = !_maisDetalhes),
                  icon: Icon(_maisDetalhes
                      ? Icons.expand_less
                      : Icons.expand_more),
                  label: Text(
                    _maisDetalhes ? 'Menos detalhes' : 'Mais detalhes',
                  ),
                ),

                if (_maisDetalhes) ...[
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _dataCtrl,
                    readOnly: true,
                    onTap: _pickData,
                    decoration: InputDecoration(
                      labelText: 'Data de nascimento',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      suffixIcon: _dataNascimento != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _dataNascimento = null;
                                _dataCtrl.clear();
                              }),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _pesoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Peso atual (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _epcCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Código EPC',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.nfc_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: _statusOpcoes
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'Ativo'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _origemCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Origem',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _pelagemCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Pelagem',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.palette_outlined),
                    ),
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
                ],

                // ── Está de cria (apenas fêmeas) ──────────────────────────
                if (_ehFemea) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _estaDeCria,
                    onChanged: (v) =>
                        setState(() => _estaDeCria = v ?? false),
                    title: const Text('Está de cria'),
                    subtitle:
                        const Text('Possui terneiro(a) vinculado(a)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

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
      ),
    );
  }
}

// ─── Seção de foto ────────────────────────────────────────────────────────────

class _FotoSection extends StatelessWidget {
  final File? fotoLocal;
  final String? fotoExistente;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemover;

  const _FotoSection({
    required this.fotoLocal,
    required this.fotoExistente,
    required this.onCamera,
    required this.onGallery,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final temFoto = fotoLocal != null || fotoExistente != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (temFoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildPreview(),
              )
            else
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Câmera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeria'),
                  ),
                ),
                if (temFoto) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: onRemover,
                    tooltip: 'Remover foto',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (fotoLocal != null) {
      return Image.file(
        fotoLocal!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    if (fotoExistente != null) {
      if (fotoExistente!.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: fotoExistente!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, _) => const ColoredBox(color: Color(0xFFE8F5E9)),
          errorWidget: (_, _, _) => const SizedBox(height: 200),
        );
      }
      return Image.file(
        File(fotoExistente!),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, e, stack) => const SizedBox(height: 200),
      );
    }
    return const SizedBox(height: 200);
  }
}
