import 'package:flutter/material.dart';
import 'package:fast_food_app/services/mongo_service.dart';
import 'package:fast_food_app/models.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ManageHoursPage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const ManageHoursPage({super.key, this.onRefresh});

  @override
  State<ManageHoursPage> createState() => _ManageHoursPageState();
}

class _ManageHoursPageState extends State<ManageHoursPage> {
  final MongoService _mongoService = MongoService();
  Future<RestaurantSettings>? _settingsFuture;
  RestaurantSettings? _currentSettings;

  final Map<String, String> _dayOrder = {
    '1': 'Lundi', '2': 'Mardi', '3': 'Mercredi', '4': 'Jeudi',
    '5': 'Vendredi', '6': 'Samedi', '7': 'Dimanche',
  };

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  Future<RestaurantSettings> _loadSettings() async {
    final settings = await _mongoService.getSettings();
    for (var dayKey in _dayOrder.keys) {
      if (!settings.hours.containsKey(dayKey)) {
        settings.hours[dayKey] = DailyHours(isOpen: false, openTime: '11:00', closeTime: '22:00');
      }
    }
    if(mounted) setState(() => _currentSettings = settings);
    return settings;
  }

  Future<void> _selectTime(BuildContext context, String dayKey, bool isOpeningTime) async {
    final now = TimeOfDay.now();
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );

    if (selectedTime != null && _currentSettings != null) {
      setState(() {
        final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
        if (isOpeningTime) {
          _currentSettings!.hours[dayKey]!.openTime = timeString;
        } else {
          _currentSettings!.hours[dayKey]!.closeTime = timeString;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_currentSettings == null) return;
    try {
      await _mongoService.updateSettings(_currentSettings!);
      widget.onRefresh?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horaires enregistrés !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF53c6fd);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<RestaurantSettings>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _currentSettings == null) {
            return const Center(child: CircularProgressIndicator(color: accentColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: _dayOrder.keys.map((dayKey) {
                    final dayHours = _currentSettings!.hours[dayKey]!;
                    final dayName = _dayOrder[dayKey]!;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: Colors.white.withOpacity(0.8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                                Switch(
                                  value: dayHours.isOpen,
                                  onChanged: (bool value) => setState(() => dayHours.isOpen = value),
                                  activeColor: accentColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AnimatedOpacity(
                              opacity: dayHours.isOpen ? 1.0 : 0.4,
                              duration: const Duration(milliseconds: 300),
                              child: IgnorePointer(
                                ignoring: !dayHours.isOpen,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildTimeSelector('Ouverture', dayHours.openTime, () => _selectTime(context, dayKey, true)),
                                    _buildTimeSelector('Fermeture', dayHours.closeTime, () => _selectTime(context, dayKey, false)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: _saveSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF9c4dea), Color(0xFFff80b1)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF9c4dea).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: const Center(child: Text('Enregistrer les modifications', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector(String label, String time, VoidCallback onTap) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF53c6fd))),
          ),
        ),
      ],
    );
  }
}
