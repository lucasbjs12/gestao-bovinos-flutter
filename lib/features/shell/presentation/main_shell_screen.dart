import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../bovinos/presentation/bovinos_screen.dart';
import '../../eventos_sanitarios/presentation/eventos_sanitarios_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../invernadas/presentation/invernadas_screen.dart';
import '../../rfid/presentation/rfid_screen.dart';
import '../../shell/shell_provider.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key});

  static const _abas = [
    _AbaInfo(label: 'Início',     icon: Icons.home_outlined,             iconSel: Icons.home),
    _AbaInfo(label: 'Bovinos',    icon: Icons.pets_outlined,             iconSel: Icons.pets),
    _AbaInfo(label: 'Invernadas', icon: Icons.grass_outlined,            iconSel: Icons.grass),
    _AbaInfo(label: 'Manejos',    icon: Icons.medical_services_outlined, iconSel: Icons.medical_services),
    _AbaInfo(label: 'RFID',       icon: Icons.nfc_outlined,              iconSel: Icons.nfc),
  ];

  static const _telas = [
    HomeScreen(),
    BovinosScreen(),
    InvernadasScreen(),
    EventosSanitariosScreen(),
    RfidScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellProvider>();

    return Scaffold(
      body: IndexedStack(
        index: shell.abaAtual,
        children: _telas,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: shell.abaAtual,
          onDestinationSelected: context.read<ShellProvider>().setAba,
          destinations: _abas
              .map((a) => NavigationDestination(
                    icon: Icon(a.icon),
                    selectedIcon: Icon(a.iconSel),
                    label: a.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _AbaInfo {
  final String label;
  final IconData icon;
  final IconData iconSel;
  const _AbaInfo({required this.label, required this.icon, required this.iconSel});
}

