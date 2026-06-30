import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/storage/cloudinary_service.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../../core/utils/photo_service.dart';
import '../../auth/auth_provider.dart';
import '../../invernadas/data/invernada.dart';
import '../../invernadas/data/invernada_local_repository.dart';
import '../data/bovino.dart';
import '../data/bovino_local_repository.dart';
import '../data/bovino_remote_repository.dart';

const _uuid = Uuid();
const _draftKey = 'draft_cadastro_lote';

const _categorias = [
  'Vaca', 'Novilha', 'Terneira', 'Terneiro(a)',
  'Terneiro', 'Novilho', 'Touro', 'Boi',
];
const _categoriasFemea = ['Vaca', 'Novilha', 'Terneira'];

String _sexoDaCategoria(String? cat) =>
    _categoriasFemea.contains(cat) ? 'Fêmea' : 'Macho';

class _ItemLote {
  final String brinco;
  final String? categoria;
  final double? peso;
  final String? dataNascimento;
  final int? dataNascimentoMillis;
  final String? fotoPath; // caminho local persistido

  _ItemLote({
    required this.brinco,
    this.categoria,
    this.peso,
    this.dataNascimento,
    this.dataNascimentoMillis,
    this.fotoPath,
  });

  Map<String, dynamic> toJson() => {
        'brinco': brinco,
        'categoria': categoria,
        'peso': peso,
        'dataNascimento': dataNascimento,
        'dataNascimentoMillis': dataNascimentoMillis,
        'fotoPath': fotoPath,
      };

  factory _ItemLote.fromJson(Map<String, dynamic> j) => _ItemLote(
        brinco: j['brinco'] as String,
        categoria: j['categoria'] as String?,
        peso: (j['peso'] as num?)?.toDouble(),
        dataNascimento: j['dataNascimento'] as String?,
        dataNascimentoMillis: j['dataNascimentoMillis'] as int?,
        fotoPath: j['fotoPath'] as String?,
      );

  File? get fotoFile =>
      fotoPath != null && File(fotoPath!).existsSync() ? File(fotoPath!) : null;
}

class CadastroLoteScreen extends StatefulWidget {
  const CadastroLoteScreen({super.key});

  @override
  State<CadastroLoteScreen> createState() => _CadastroLoteScreenState();
}

class _CadastroLoteScreenState extends State<CadastroLoteScreen> {
  String? _uid;
  List<Invernada> _invernadas = [];
  int? _invernadaId;

  final _formKey = GlobalKey<FormState>();
  final _brincoCtrl = TextEditingController();
  String? _categoria;
  final _pesoCtrl = TextEditingController();
  DateTime? _dataNasc;
  File? _fotoAtual; // apenas para preview antes de adicionar

  final List<_ItemLote> _lote = [];
  bool _salvando = false;
  bool _adicionando = false; // lock enquanto salva foto local

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _uid = context.read<AuthProvider>().currentUser?.uid;
      if (_uid == null || !mounted) return;
      final db = await AppDatabase.instance.instanceFor(_uid);
      final lista = await InvernadaLocalRepository(db).listar();
      if (!mounted) return;
      setState(() => _invernadas = lista);
      await _loadDraft();
    });
  }

  @override
  void dispose() {
    _brincoCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  // ── Rascunho ────────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'invernadaId': _invernadaId,
      'lote': _lote.map((i) => i.toJson()).toList(),
    });
    await prefs.setString('${_draftKey}_$_uid', data);
  }

  Future<void> _loadDraft() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_draftKey}_$_uid');
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['lote'] as List)
          .map((e) => _ItemLote.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _invernadaId = data['invernadaId'] as int?;
        _lote.addAll(items);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rascunho restaurado · ${items.length} '
            '${items.length == 1 ? 'animal' : 'animais'}',
          ),
          action: SnackBarAction(
            label: 'Descartar',
            onPressed: () {
              setState(() => _lote.clear());
              _clearDraft();
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_draftKey}_$_uid');
  }

  // ── Formulário ──────────────────────────────────────────────────────────────

  Future<void> _adicionarAnimal() async {
    if (_adicionando || !_formKey.currentState!.validate()) return;
    setState(() => _adicionando = true);
    try {
      final peso =
          double.tryParse(_pesoCtrl.text.trim().replaceAll(',', '.'));
      String? dataNascStr;
      int? dataNascMillis;
      if (_dataNasc != null) {
        dataNascStr =
            '${_dataNasc!.day.toString().padLeft(2, '0')}/'
            '${_dataNasc!.month.toString().padLeft(2, '0')}/${_dataNasc!.year}';
        dataNascMillis = _dataNasc!.millisecondsSinceEpoch;
      }

      // Salva foto localmente de imediato para poder persistir no rascunho
      String? fotoPath;
      if (_fotoAtual != null && _uid != null) {
        fotoPath =
            await PhotoService.saveCompressed(_fotoAtual!, _uid!);
      }

      if (!mounted) return;
      setState(() {
        _lote.add(_ItemLote(
          brinco: _brincoCtrl.text.trim(),
          categoria: _categoria,
          peso: peso,
          dataNascimento: dataNascStr,
          dataNascimentoMillis: dataNascMillis,
          fotoPath: fotoPath,
        ));
        _brincoCtrl.clear();
        _pesoCtrl.clear();
        _dataNasc = null;
        _fotoAtual = null;
        // mantém _categoria para o próximo animal
      });
      await _saveDraft();
    } finally {
      if (mounted) setState(() => _adicionando = false);
    }
  }

  Future<void> _pickFoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = source == ImageSource.camera
        ? await PhotoService.pickFromCamera()
        : await PhotoService.pickFromGallery();
    if (file != null && mounted) setState(() => _fotoAtual = file);
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dataNasc ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d != null) setState(() => _dataNasc = d);
  }

  Future<void> _salvarLote() async {
    if (_lote.isEmpty || _uid == null) return;
    setState(() => _salvando = true);
    try {
      final syncSvc = context.read<SyncStatusService>();
      final db = await AppDatabase.instance.instanceFor(_uid);
      final localRepo = BovinoLocalRepository(db);
      final remoteRepo = BovinoRemoteRepository(uid: _uid!, sync: syncSvc);

      for (final item in _lote) {
        // foto já está salva localmente desde _adicionarAnimal;
        // tenta subir para Cloudinary como upgrade
        String? fotoFinal = item.fotoPath;
        if (item.fotoFile != null) {
          try {
            fotoFinal = await CloudinaryService.upload(item.fotoFile!);
          } catch (_) {}
        }

        final ehFemea = _categoriasFemea.contains(item.categoria);
        final bovino = Bovino(
          syncId: _uuid.v4(),
          numeroBrinco: item.brinco,
          categoria: item.categoria,
          sexo: _sexoDaCategoria(item.categoria),
          pesoAtualKg: item.peso,
          dataNascimento: item.dataNascimento,
          dataNascimentoMillis: item.dataNascimentoMillis,
          invernadaId: _invernadaId,
          estaDeCria: ehFemea ? 1 : 0,
          status: 'Ativo',
          foto: fotoFinal,
        );
        final newId = await localRepo.inserir(bovino);
        remoteRepo.salvar(bovino.copyWith(id: newId));
      }

      await _clearDraft();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_lote.length} animal${_lote.length != 1 ? 'is' : ''} '
            'cadastrado${_lote.length != 1 ? 's' : ''} com sucesso!',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<bool> _confirmarSaida() async {
    if (_lote.isEmpty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do cadastro?'),
        content: Text(
          'Você tem ${_lote.length} '
          '${_lote.length == 1 ? 'animal adicionado' : 'animais adicionados'}.\n'
          'O rascunho será mantido automaticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Continuar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Descartar e sair'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Salvar rascunho e sair'),
          ),
        ],
      ),
    );
    if (choice == 'keep') {
      await _saveDraft();
      return true;
    }
    if (choice == 'discard') {
      await _clearDraft();
      return true;
    }
    return false; // 'cancel' ou fechou o diálogo
  }

  @override
  Widget build(BuildContext context) {
    final semPeso = _lote.where((a) => a.peso == null).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final sair = await _confirmarSaida();
        if (sair) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Cadastro em lote')),
        body: Column(
          children: [
            // ── Invernada (seletor compacto) ────────────────────────────
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: DropdownButtonFormField<int?>(
                initialValue: _invernadaId,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Invernada (todos os animais)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fence_outlined),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Sem invernada')),
                  ..._invernadas.map((inv) => DropdownMenuItem(
                      value: inv.id, child: Text(inv.descricao))),
                ],
                onChanged: (v) {
                  setState(() => _invernadaId = v);
                  _saveDraft();
                },
              ),
            ),

            // ── Formulário por animal ────────────────────────────────────
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Linha 1: Brinco + Categoria
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _brincoCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Brinco *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Obrigatório';
                              }
                              if (_lote.any((a) => a.brinco == v.trim())) {
                                return 'Já adicionado';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _categoria,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: 'Categoria *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _categorias
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _categoria = v),
                            validator: (v) =>
                                v == null ? 'Selecione' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Linha 2: Peso + Nascimento + Foto + Adicionar
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pesoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _adicionarAnimal(),
                            decoration: const InputDecoration(
                              labelText: 'Peso (kg)',
                              border: OutlineInputBorder(),
                              suffixText: 'kg',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _escolherData,
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 16),
                          label: Text(
                            _dataNasc == null
                                ? 'Nasc.'
                                : '${_dataNasc!.day.toString().padLeft(2, '0')}/'
                                    '${_dataNasc!.month.toString().padLeft(2, '0')}/'
                                    '${_dataNasc!.year}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _pickFoto,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _fotoAtual != null
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              image: _fotoAtual != null
                                  ? DecorationImage(
                                      image: FileImage(_fotoAtual!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _fotoAtual == null
                                ? Icon(Icons.camera_alt_outlined,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              _adicionando ? null : _adicionarAnimal,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                          child: _adicionando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Contador ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${_lote.length} '
                    'animal${_lote.length != 1 ? 'is' : ''} no lote',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (semPeso > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· $semPeso sem peso',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),

            // ── Lista do lote ────────────────────────────────────────────
            Expanded(
              child: _lote.isEmpty
                  ? Center(
                      child: Text(
                        'Adicione o primeiro animal acima.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      itemCount: _lote.length,
                      itemBuilder: (_, i) {
                        final item = _lote[_lote.length - 1 - i];
                        final fotoFile = item.fotoFile;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              backgroundImage: fotoFile != null
                                  ? FileImage(fotoFile)
                                  : null,
                              child: fotoFile == null
                                  ? Text(
                                      '${_lote.length - i}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              item.brinco,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              [
                                item.categoria ?? '',
                                if (item.peso != null)
                                  '${item.peso!.toStringAsFixed(item.peso! % 1 == 0 ? 0 : 1)} kg'
                                else
                                  'Sem peso',
                                if (item.dataNascimento != null)
                                  item.dataNascimento!,
                              ]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: item.peso == null
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18),
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () {
                                setState(() =>
                                    _lote.removeAt(_lote.length - 1 - i));
                                _saveDraft();
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── Botão salvar ─────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed:
                      (_lote.isEmpty || _salvando) ? null : _salvarLote,
                  icon: _salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _lote.isEmpty
                        ? 'Adicione animais para salvar'
                        : 'Salvar lote (${_lote.length} '
                            '${_lote.length == 1 ? 'animal' : 'animais'})',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
