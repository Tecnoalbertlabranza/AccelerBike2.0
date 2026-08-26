import 'package:app_movile/core/theme/app_colors.dart';
import 'package:app_movile/core/stats/weekly_stats_service.dart';
import 'package:app_movile/features/home/presentation/widgets/home/home_content.dart';
import 'package:app_movile/features/profile/presentation/profile_view.dart';
import 'package:app_movile/features/route/presentation/route_view.dart';
import 'package:app_movile/features/statistics/presentation/statistics_view.dart';
import 'package:app_movile/core/network/supabase_service.dart';
import 'package:app_movile/core/widgets/top_bar.dart';
import 'package:app_movile/core/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  String _userName = 'Ciclista';
  // estadisticas semanales locales
  double _weeklyDistance  = 0.0;
  String _weeklyTime      = '00:00';
  double _weeklyCalories  = 0.0;
  @override
  void initState() {
    super.initState();
    _loadUserName();
    // cargando estadisticas semanales locales
    _loadWeeklyStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeUsage();
    });
  }
  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('profile_name') ?? '';
    if (localName.isNotEmpty) {
      if (mounted) setState(() => _userName = localName);
      return;
    }
    // fallback a supabase si no hay nombre local
    final name = await supabaseService.getUserName();
    if (mounted) setState(() => _userName = name);
  }

  // carga las 3 estadisticas de la semana desde shared_preferences
  Future<void> _loadWeeklyStats() async {
    final stats = await WeeklyStatsService.instance.load();
    if (mounted) {
      setState(() {
        _weeklyDistance = stats.distanceKm;
        _weeklyTime     = stats.formattedTime;
        _weeklyCalories = stats.calories;
      });
    }
  }
  
  Future<void> _checkFirstTimeUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (!hasSeenOnboarding && mounted) {
      _showWelcomePopup(context);
    }
  }

  void _showWelcomePopup(BuildContext context) {
    final nameController = TextEditingController();
    double selectedRadius = 29.0; 
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( 
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2128),
              title: const Text(
                '¡Bienvenido a AccelerBike!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para comenzar, necesitamos algunos datos básicos.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tu Nombre',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Radio de la rueda (Pulgadas)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: selectedRadius,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E2128),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 26.0, child: Text('26"')),
                          DropdownMenuItem(value: 27.5, child: Text('27.5"')),
                          DropdownMenuItem(value: 29.0, child: Text('29"')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedRadius = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                isSaving 
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        setState(() => isSaving = true);

                        await supabaseService.saveInitialUserName(
                          name: nameController.text.trim(),
                        );

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setDouble('wheel_radius', selectedRadius);
                        await prefs.setBool('has_seen_onboarding', true);

                        setState(() => isSaving = false);
                        if (mounted) Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Comenzar'),
                    ),
              ],
            );
          }
        );
      },
    );
  }
  
  // ya no necesitamos fetch de supabase para la distancia semanal
  // se lee directo de shared_preferences en _loadWeeklyStats

  List<Widget> _buildScreens() {
    return [
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido $_userName',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold
                ),
            ),
            const SizedBox(height: 24),
            welcomeMessage(context),
            const SizedBox(height: 16),
            Divider(
              color: const Color(0xFF004407),
              thickness: 2, 
              indent: 20,   
              endIndent: 20,
            ),
            const SizedBox(height: 16),
            startTravel(context),
            const SizedBox(height: 28),     
            metrics(
              context,
              _weeklyDistance.toStringAsFixed(2),
              _weeklyTime,
              _weeklyCalories.toStringAsFixed(0),
            ),
            const SizedBox(height: 16),
            Divider(
              color: const Color(0xFF004407),
              thickness: 2, 
              indent: 20,  
              endIndent: 20,
            ),
          ],
        ),
      ),
      const StatisticsView(),
      const ProfileView(),
    ];
  }

  void _onFabPressed() {
    // gps no requiere conexion ble para iniciar ruta
    // al volver recargamos las estadisticas actualizadas
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RouteView()),
    ).then((_) => _loadWeeklyStats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: topBar(context, false),
      body: _buildScreens()[_selectedIndex],
      floatingActionButton: FloatingActionButton.large(
        onPressed: _onFabPressed,
        backgroundColor: AppColors.green,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.directions_bike,
          color: Colors.black,
          size: 40,
        ),
      ),
      bottomNavigationBar: NavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}