import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_status_service.dart';
import '../../auth/auth_provider.dart';
import '../../bovinos/data/bovino.dart';
import '../../home/home_provider.dart';
import '../../bovinos/data/bovino_local_repository.dart';
import '../../invernadas/data/invernada.dart';
import '../../invernadas/data/invernada_local_repository.dart';
import '../data/evento_sanitario.dart';
import '../data/evento_sanitario_completo.dart';
import '../data/evento_sanitario_local_repository.dart';
import '../data/evento_sanitario_remote_repository.dart';
import '../data/manejo_rascunho_service.dart';
import '../eventos_sanitarios_provider.dart';

class CadastroEventoScreen extends StatefulWidget {
  const CadastroEventoScreen({super.key});

  @override
  State<CadastroEventoScreen> createState() => _CadastroEventoScreenState();
}

class _CadastroEventoScreenState extends State<CadastroEventoScreen> {
  // ── Contexto ─────────────────────────────────────────────────────────────
  String? _uid;
  int? _eventoId;
  bool _carregando = false;
  EventoSanitarioCompleto? _eventoOriginal;
  Timer? _debounceRascunho;

  // ── Navegação em etapas ──────────────────────────────────────────────────
  final _pageCtrl = PageController();
  int _step = 0;

  // ── Etapa 1: campos do evento ────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _produtoCtrl = TextEditingController();
  final _dosagemCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _dataCtrl = TextEditingController();

  String _tipo = EventoSanitario.tipos.first;
  DateTime? _dataEvento;
  int? _invernadaId;

  // ── Etapa 2: seleção de animais ──────────────────────────────────────────
  final _buscaCtrl = TextEditingController();
  String _termoBusca = '';
  bool _apenasInvernada = true;

  // ── Dados carregados ─────────────────────────────────────────────────────
  List<Invernada> _invernadas = [];
  List<Bovino> _todosBovinos = [];
  List<int> _bovinosSelecionados = [];

  @override
  void initState() {
    super.initState();
    for (final ctrl in [_produtoCtrl, _dosagemCtrl, _responsavelCtrl, _obsCtrl]) {
      ctrl.addListener(_agendarRascunho);
    }
    _buscaCtrl.addListener(() =>
        setState(() => _termoBusca = _buscaCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _uid = context.read<AuthProvider>().currentUser?.uid;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        _eventoId = args;
      } else if (args is List<int> && args.isNotEmpty) {
        _bovinosSelecionados = List<int>.from(args);
      }
      await _carregarDados();
      if (_eventoId == null && _bovinosSelecionados.isEmpty && mounted) {
        await _ofereceRestaurarRascunho();
      }
    });
  }

  Future<void> _carregarDados() async {
    if (_uid == null) return;
    final db = await AppDatabase.instance.instanceFor(_uid);
    final invernadas = await InvernadaLocalRepository(db).listar();
    final bovinos = await BovinoLocalRepository(db).listarAtivos();

    if (!mounted) return;
    setState(() {
      _invernadas = invernadas;
      _todosBovinos = bovinos;
    });

    if (_eventoId != null) {
      final evento =
          await EventoSanitarioLocalRepository(db).buscarCompletoPorId(_eventoId!);
      if (evento == null || !mounted) return;
      _eventoOriginal = evento;
      setState(() {
        _tipo = evento.tipo;
        _invernadaId = evento.invernadaId;
        _produtoCtrl.text = evento.produtoUtilizado ?? '';
        _dosagemCtrl.text = evento.dosagem ?? '';
        _responsavelCtrl.text = evento.responsavel ?? '';
        _obsCtrl.text = evento.observacoes ?? '';
        _bovinosSelecionados = List<int>.from(evento.bovinoIdsList);
        if (evento.dataEventoMillis != null) {
          _dataEvento =
              DateTime.fromMillisecondsSinceEpoch(evento.dataEventoMillis!);
          _dataCtrl.text = _formatarData(_dataEvento!);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceRascunho?.cancel();
    _pageCtrl.dispose();
    _buscaCtrl.dispose();
    for (final ctrl in [_produtoCtrl, _dosagemCtrl, _responsavelCtrl, _obsCtrl]) {
      ctrl.removeListener(_agendarRascunho);
      ctrl.dispose();
    }
    _dataCtrl.dispose();
    super.dispose();
  }

  // ── Rascunho ──────────────────────────────────────────────────────────────

  void _agendarRascunho() {
    if (_eventoId != null) return;
    _debounceRascunho?.cancel();
    _debounceRascunho = Timer(const Duration(milliseconds: 500), _salvarRascunho);
  }

  void _salvarRascunho() {
    if (_eventoId != null) return;
    ManejoRascunhoService.salvar(
      tipo: _tipo,
      data: _dataEvento != null ? _formatarData(_dataEvento!) : null,
      invernadaId: _invernadaId,
      produto: _produtoCtrl.text,
      dosagem: _dosagemCtrl.text,
      responsavel: _responsavelCtrl.text,
      observacoes: _obsCtrl.text,
      bovinoIds: _bovinosSelecionados,
    );
  }

  Future<void> _ofereceRestaurarRascunho() async {
    final dados = await ManejoRascunhoService.carregar();
    if (dados == null || !mounted) return;

    final restaurar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rascunho encontrado'),
        content: const Text(
          'Você tem um manejo não finalizado. Deseja continuar de onde parou?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (restaurar == true && mounted) {
      setState(() {
        _tipo = dados['tipo'] as String? ?? _tipo;
        _invernadaId = dados['invernadaId'] as int?;
        _produtoCtrl.text = dados['produto'] as String? ?? '';
        _dosagemCtrl.text = dados['dosagem'] as String? ?? '';
        _responsavelCtrl.text = dados['responsavel'] as String? ?? '';
        _obsCtrl.text = dados['observacoes'] as String? ?? '';
        _bovinosSelecionados = (dados['bovinoIds'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            [];
        final dataStr = dados['data'] as String?;
        if (dataStr != null) {
          final partes = dataStr.split('/');
          if (partes.length == 3) {
            _dataEvento = DateTime(
              int.parse(partes[2]),
              int.parse(partes[1]),
              int.parse(partes[0]),
            );
            _dataCtrl.text = dataStr;
          }
        }
      });
    } else if (restaurar == false) {
      await ManejoRascunhoService.limpar();
    }
  }

  // ── Navegação entre etapas ────────────────────────────────────────────────

  void _irParaStep2() {
    if (!_formKey.currentState!.validate()) return;
    // Reseta busca e filtro ao entrar na seleção
    _buscaCtrl.clear();
    setState(() {
      _termoBusca = '';
      _apenasInvernada = _invernadaId != null;
      _step = 1;
    });
    _pageCtrl.animateToPage(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _voltarParaStep1() {
    setState(() => _step = 0);
    _pageCtrl.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  // ── Etapa 1: helpers ──────────────────────────────────────────────────────

  Future<void> _pickData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataEvento ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dataEvento = picked;
        _dataCtrl.text = _formatarData(picked);
      });
      _agendarRascunho();
    }
  }

  String _formatarData(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  // ── Etapa 2: helpers ──────────────────────────────────────────────────────

  List<Bovino> get _bovinosFiltrados {
    final termo = _termoBusca.toLowerCase().trim();
    return _todosBovinos.where((b) {
      if (termo.isNotEmpty) {
        return b.numeroBrinco.toLowerCase().contains(termo) ||
            (b.nomeAnimal?.toLowerCase().contains(termo) ?? false);
      }
      if (_apenasInvernada && _invernadaId != null) {
        return b.invernadaId == _invernadaId ||
            _bovinosSelecionados.contains(b.id);
      }
      return true;
    }).toList();
  }

  void _toggleBovino(int id) {
    setState(() {
      if (_bovinosSelecionados.contains(id)) {
        _bovinosSelecionados.remove(id);
      } else {
        _bovinosSelecionados.add(id);
      }
    });
    _agendarRascunho();
  }

  void _selecionarTodos() {
    final filtrados = _bovinosFiltrados;
    final todosJaSelecionados =
        filtrados.every((b) => _bovinosSelecionados.contains(b.id));
    setState(() {
      if (todosJaSelecionados) {
        for (final b in filtrados) {
          _bovinosSelecionados.remove(b.id);
        }
      } else {
        for (final b in filtrados) {
          if (!_bovinosSelecionados.contains(b.id)) {
            _bovinosSelecionados.add(b.id!);
          }
        }
      }
    });
    _agendarRascunho();
  }

  // ── Salvar ────────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (_bovinosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um animal.')),
      );
      return;
    }
    if (_uid == null) return;

    setState(() => _carregando = true);
    try {
      final db = await AppDatabase.instance.instanceFor(_uid);
      final repo = EventoSanitarioLocalRepository(db);

      final syncId =
          _eventoOriginal?.syncId ?? EventoSanitario.criar(tipo: _tipo).syncId;

      final evento = EventoSanitario(
        id: _eventoId,
        syncId: syncId,
        tipo: _tipo,
        dataEvento: _dataEvento != null ? _formatarData(_dataEvento!) : null,
        dataEventoMillis: _dataEvento?.millisecondsSinceEpoch,
        invernadaId: _invernadaId,
        produtoUtilizado: _produtoCtrl.text.trim().isEmpty
            ? null
            : _produtoCtrl.text.trim(),
        dosagem:
            _dosagemCtrl.text.trim().isEmpty ? null : _dosagemCtrl.text.trim(),
        responsavel: _responsavelCtrl.text.trim().isEmpty
            ? null
            : _responsavelCtrl.text.trim(),
        observacoes:
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );

      int eventoComId;
      if (_eventoId == null) {
        eventoComId = await repo.inserirComBovinos(evento, _bovinosSelecionados);
      } else {
        await repo.atualizarComBovinos(evento, _bovinosSelecionados);
        eventoComId = _eventoId!;
      }

      final eventoSalvo = evento.copyWith(id: eventoComId);

      await ManejoRascunhoService.limpar();

      if (mounted) {
        EventoSanitarioRemoteRepository(
          uid: _uid!,
          sync: context.read<SyncStatusService>(),
        ).salvar(eventoSalvo, _bovinosSelecionados);

        context.read<EventosSanitariosProvider>().recarregar();
        context.read<HomeProvider>().carregar(_uid!);
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = _eventoId != null;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltarParaStep1();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _step == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _voltarParaStep1,
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _step == 0
                    ? (isEdit ? 'Editar evento' : 'Novo evento')
                    : 'Selecionar animais',
                style: const TextStyle(fontSize: 17),
              ),
              Text(
                'Etapa ${_step + 1} de 2',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        body: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStep1(isEdit),
            _buildStep2(),
          ],
        ),
      ),
    );
  }

  // ── Etapa 1 ───────────────────────────────────────────────────────────────

  Widget _buildStep1(bool isEdit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Progresso visual ────────────────────────────────────────
            _StepIndicator(step: 0),
            const SizedBox(height: 20),

            // ── Tipo ────────────────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de evento *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services_outlined),
              ),
              items: EventoSanitario.tipos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                setState(() => _tipo = v ?? _tipo);
                _agendarRascunho();
              },
              validator: (v) => v == null ? 'Selecione o tipo.' : null,
            ),
            const SizedBox(height: 12),

            // ── Data ─────────────────────────────────────────────────────
            TextFormField(
              controller: _dataCtrl,
              readOnly: true,
              onTap: _pickData,
              decoration: InputDecoration(
                labelText: 'Data do evento *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                suffixIcon: _dataEvento != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _dataEvento = null;
                          _dataCtrl.clear();
                        }),
                      )
                    : null,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe a data.' : null,
            ),
            const SizedBox(height: 12),

            // ── Invernada (opcional) ─────────────────────────────────────
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
                  child: Text('Todas as invernadas'),
                ),
                ..._invernadas.map(
                  (i) => DropdownMenuItem<int?>(
                    value: i.id,
                    child: Text(i.descricao),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _invernadaId = v);
                _agendarRascunho();
              },
            ),
            const SizedBox(height: 12),

            // ── Produto ──────────────────────────────────────────────────
            TextFormField(
              controller: _produtoCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Produto utilizado',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.science_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // ── Dosagem ──────────────────────────────────────────────────
            TextFormField(
              controller: _dosagemCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Dosagem',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // ── Responsável ──────────────────────────────────────────────
            TextFormField(
              controller: _responsavelCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Responsável',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // ── Observações ──────────────────────────────────────────────
            TextFormField(
              controller: _obsCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Resumo animais já selecionados (modo edição / restauro) ──
            if (_bovinosSelecionados.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pets,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_bovinosSelecionados.length} animal(is) selecionado(s)',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Botão próximo ────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _irParaStep2,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Próximo: selecionar animais'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa 2 ───────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final filtrados = _bovinosFiltrados;
    final todosNaListaSelecionados =
        filtrados.isNotEmpty &&
        filtrados.every((b) => _bovinosSelecionados.contains(b.id));
    final nomeInvernada = _invernadaId != null
        ? _invernadas
            .where((i) => i.id == _invernadaId)
            .map((i) => i.descricao)
            .firstOrNull
        : null;

    return Column(
      children: [
        // ── Indicador de progresso ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _StepIndicator(step: 1),
        ),

        // ── Barra de busca ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _buscaCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por brinco ou nome…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _termoBusca.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _buscaCtrl.clear();
                        setState(() => _termoBusca = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
        ),

        // ── Filtro por invernada + selecionar todos ────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              if (nomeInvernada != null) ...[
                FilterChip(
                  label: Text(nomeInvernada),
                  selected: _apenasInvernada,
                  onSelected: (v) => setState(() => _apenasInvernada = v),
                  avatar: const Icon(Icons.fence_outlined, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: _selecionarTodos,
                icon: Icon(
                  todosNaListaSelecionados
                      ? Icons.deselect
                      : Icons.select_all,
                  size: 18,
                ),
                label: Text(
                  todosNaListaSelecionados ? 'Desmarcar todos' : 'Selecionar todos',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // ── Contador ──────────────────────────────────────────────────
        if (_bovinosSelecionados.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_bovinosSelecionados.length} selecionado(s) no total',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

        const Divider(height: 12),

        // ── Lista ──────────────────────────────────────────────────────
        Expanded(
          child: filtrados.isEmpty
              ? const Center(child: Text('Nenhum animal encontrado.'))
              : ListView.builder(
                  itemCount: filtrados.length,
                  itemBuilder: (_, i) {
                    final b = filtrados[i];
                    final marcado = _bovinosSelecionados.contains(b.id);
                    final outraInvernada = _invernadaId != null &&
                        b.invernadaId != _invernadaId &&
                        b.invernadaId != null;
                    return CheckboxListTile(
                      value: marcado,
                      onChanged: (_) => _toggleBovino(b.id!),
                      title: Text(b.nomeAnimal ?? b.numeroBrinco),
                      subtitle: Text(
                        [
                          if (b.nomeAnimal != null) b.numeroBrinco,
                          if (b.categoria != null) b.categoria!,
                          if (b.invernadaDescricao != null)
                            b.invernadaDescricao!,
                          if (outraInvernada) '⚠ outra invernada',
                        ].join(' · '),
                      ),
                      tileColor: outraInvernada
                          ? const Color(0xFFFFF8E1)
                          : marcado
                              ? const Color(0xFFE8F5E9)
                              : null,
                    );
                  },
                ),
        ),

        // ── Botão salvar ──────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: _carregando ? null : _salvar,
              icon: _carregando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_eventoId != null ? 'Atualizar' : 'Salvar evento'),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Indicador de etapa ───────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _Dot(active: step == 0, done: step > 0, label: '1', cs: cs),
        Expanded(
          child: Container(
            height: 2,
            color: step >= 1 ? cs.primary : cs.outlineVariant,
          ),
        ),
        _Dot(active: step == 1, done: false, label: '2', cs: cs),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  final bool done;
  final String label;
  final ColorScheme cs;

  const _Dot({
    required this.active,
    required this.done,
    required this.label,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final bg = (active || done) ? cs.primary : cs.outlineVariant;
    final fg = (active || done) ? cs.onPrimary : cs.onSurface;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: done
            ? Icon(Icons.check, size: 16, color: fg)
            : Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
