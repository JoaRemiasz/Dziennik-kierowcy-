import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'trip_storage.dart';

void main() {
  runApp(const DriverDiaryApp());
}

// ==========================================
// MODEL PUNKTU TRASY
// ==========================================

class RoutePoint {
  final String name;
  final String type;
  final String? time;

  RoutePoint({
    required this.name,
    required this.type,
    this.time,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'time': time,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      name: json['name'] ?? '',
      type: json['type'] ?? 'Załadunek',
      time: json['time'] as String?,
    );
  }
}

// ==========================================
// MODEL TRASY
// ==========================================

class Trip {
  final String id;
  final DateTime date;
  final String start;
  final String end;
  final String? startTime;
  final String? endTime;
  final double odometerStart;
  final double odometerEnd;
  final List<RoutePoint> points;

  Trip({
    required this.id,
    required this.date,
    required this.start,
    required this.end,
    this.startTime,
    this.endTime,
    required this.odometerStart,
    required this.odometerEnd,
    required this.points,
  });

  double get kilometers => odometerEnd - odometerStart;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'start': start,
        'end': end,
        'startTime': startTime,
        'endTime': endTime,
        'odometerStart': odometerStart,
        'odometerEnd': odometerEnd,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      date: DateTime.parse(json['date']),
      start: json['start'],
      end: json['end'],
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      odometerStart: (json['odometerStart'] as num).toDouble(),
      odometerEnd: (json['odometerEnd'] as num).toDouble(),
      points:
          (json['points'] as List).map((p) => RoutePoint.fromJson(p)).toList(),
    );
  }
}

// ==========================================
// APLIKACJA
// ==========================================

class DriverDiaryApp extends StatelessWidget {
  const DriverDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dziennik Kierowcy',
      locale: const Locale('pl', 'PL'),
      supportedLocales: const [
        Locale('pl', 'PL'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2479D8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      ),
      home: const MainScreen(),
    );
  }
}

// ==========================================
// WSPÓLNA WARSTWA ZAPISU DANYCH
// ==========================================

class TripDatabase {
  TripDatabase._();

  static final TripDatabase instance = TripDatabase._();

  Future<List<Trip>> loadTrips() async {
    final saved = await loadTripsJson();
    if (saved == null || saved.isEmpty) return [];

    final decoded = jsonDecode(saved);
    if (decoded is! List) return [];

    return decoded
        .map((item) => Trip.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<void> saveTrips(List<Trip> trips) async {
    final encoded = jsonEncode(
      trips.map((trip) => trip.toJson()).toList(),
    );
    await saveTripsJson(encoded);
  }
}

// ==========================================
// GŁÓWNY EKRAN I BAZA LOKALNA
// ==========================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  List<Trip> trips = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Future<void> loadTrips() async {
    try {
      trips = await TripDatabase.instance.loadTrips();
      trips.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('Błąd odczytu tras: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nie udało się odczytać zapisanych tras.')),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveTrips() async {
    try {
      await TripDatabase.instance.saveTrips(trips);
    } catch (e) {
      debugPrint('Błąd zapisu tras: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się zapisać zmian.')),
        );
      }
    }
  }

  Future<void> addTrip() async {
    final result = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (_) => const AddTripPage()),
    );
    if (result != null) {
      setState(() {
        trips.add(result);
        trips.sort((a, b) => b.date.compareTo(a.date));
      });
      await saveTrips();
    }
  }

  Future<void> editTrip(Trip trip) async {
    final result = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (_) => AddTripPage(initialTrip: trip)),
    );
    if (result != null) {
      final index = trips.indexWhere((item) => item.id == trip.id);
      if (index != -1) {
        setState(() {
          trips[index] = result;
          trips.sort((a, b) => b.date.compareTo(a.date));
        });
        await saveTrips();
      }
    }
  }

  Future<void> deleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usunąć trasę?'),
        content: Text(
            'Czy na pewno chcesz usunąć trasę ${trip.start} – ${trip.end}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => trips.removeWhere((item) => item.id == trip.id));
      await saveTrips();
    }
  }

  double get totalKilometers {
    return trips.fold(0, (sum, trip) => sum + trip.kilometers);
  }

  double get monthKilometers {
    final now = DateTime.now();

    return trips
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .fold(0, (sum, trip) => sum + trip.kilometers);
  }

  List<Widget> get pages => [
        HomePage(
          trips: trips,
          totalKm: totalKilometers,
          monthKm: monthKilometers,
          onAdd: addTrip,
          onEdit: editTrip,
          onDelete: deleteTrip,
        ),
        CalendarPage(trips: trips, onEdit: editTrip, onDelete: deleteTrip),
        RoutesPage(trips: trips, onEdit: editTrip, onDelete: deleteTrip),
        StatisticsPage(
          trips: trips,
          totalKm: totalKilometers,
          monthKm: monthKilometers,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : pages[selectedIndex],
      ),
      floatingActionButton: selectedIndex == 0 || selectedIndex == 2
          ? FloatingActionButton.extended(
              onPressed: addTrip,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj trasę'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Start',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Kalendarz',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            label: 'Trasy',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Statystyki',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// EKRAN GŁÓWNY
// ==========================================

class HomePage extends StatelessWidget {
  final List<Trip> trips;
  final double totalKm;
  final double monthKm;
  final VoidCallback onAdd;
  final ValueChanged<Trip> onEdit;
  final ValueChanged<Trip> onDelete;

  const HomePage({
    super.key,
    required this.trips,
    required this.totalKm,
    required this.monthKm,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  String formatKm(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ' ',
        );
  }

  @override
  Widget build(BuildContext context) {
    final days = trips
        .map((t) => '${t.date.year}-${t.date.month}-${t.date.day}')
        .toSet()
        .length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Dziennik Kierowcy',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'Twoja historia tras w jednym miejscu',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1769BD), Color(0xFF3295EC)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CAŁKOWITY PRZEBIEG Z ZAPISANYCH TRAS',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Text(
                '${formatKm(totalKm)} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: statCard(
                Icons.route,
                '${formatKm(monthKm)} km',
                'W tym miesiącu',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: statCard(
                Icons.calendar_today,
                '$days',
                'Dni z trasą',
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Dodaj nową trasę'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 55),
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'Ostatnie trasy',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (trips.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'Nie masz jeszcze zapisanych tras.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...trips.take(3).map((trip) => TripCard(
            trip: trip,
            onEdit: () => onEdit(trip),
            onDelete: () => onDelete(trip))),
      ],
    );
  }

  Widget statCard(IconData icon, String value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2479D8)),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FORMULARZ DODAWANIA TRASY
// ==========================================

class PointInput {
  final TextEditingController controller = TextEditingController();
  String type = 'Załadunek';
  String? time;
}

class AddTripPage extends StatefulWidget {
  final Trip? initialTrip;

  const AddTripPage({super.key, this.initialTrip});

  @override
  State<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends State<AddTripPage> {
  final formKey = GlobalKey<FormState>();

  final startController = TextEditingController();
  final endController = TextEditingController();
  final startKmController = TextEditingController();
  final endKmController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String? startTime;
  String? endTime;

  final List<PointInput> points = [];

  @override
  void initState() {
    super.initState();
    final trip = widget.initialTrip;
    if (trip != null) {
      selectedDate = trip.date;
      startController.text = trip.start;
      endController.text = trip.end;
      startTime = trip.startTime;
      endTime = trip.endTime;
      startKmController.text = trip.odometerStart.toString();
      endKmController.text = trip.odometerEnd.toString();
      for (final savedPoint in trip.points) {
        final point = PointInput()
          ..controller.text = savedPoint.name
          ..type = savedPoint.type
          ..time = savedPoint.time;
        points.add(point);
      }
    }
  }

  double get calculatedKm {
    final start = double.tryParse(startKmController.text.replaceAll(',', '.'));
    final end = double.tryParse(endKmController.text.replaceAll(',', '.'));

    if (start == null || end == null || end < start) {
      return 0;
    }

    return end - start;
  }

  @override
  void dispose() {
    startController.dispose();
    endController.dispose();
    startKmController.dispose();
    endKmController.dispose();

    for (final point in points) {
      point.controller.dispose();
    }

    super.dispose();
  }

  String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'To pole jest wymagane';
    }
    return null;
  }

  String? validateKm(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Wpisz stan licznika';
    }

    final number = double.tryParse(value.replaceAll(',', '.'));

    if (number == null || number < 0) {
      return 'Wpisz prawidłową wartość';
    }

    return null;
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pl', 'PL'),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  Future<String?> chooseTime(String? currentTime) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (currentTime != null && currentTime.contains(':')) {
      final parts = currentTime.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        initialTime = TimeOfDay(hour: hour, minute: minute);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null) return currentTime;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  Widget timePickerButton({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await chooseTime(value);
        if (picked != null) onChanged(picked);
      },
      icon: const Icon(Icons.access_time),
      label: Text(value == null ? label : '$label: $value'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  void addPoint() {
    setState(() => points.add(PointInput()));
  }

  void removePoint(int index) {
    setState(() {
      points[index].controller.dispose();
      points.removeAt(index);
    });
  }

  void saveTrip() {
    if (!formKey.currentState!.validate()) return;

    final startKm = double.parse(
      startKmController.text.replaceAll(',', '.'),
    );

    final endKm = double.parse(
      endKmController.text.replaceAll(',', '.'),
    );

    if (endKm < startKm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Końcowy stan licznika nie może być mniejszy od początkowego.'),
        ),
      );
      return;
    }

    final trip = Trip(
      id: widget.initialTrip?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: selectedDate,
      start: startController.text.trim(),
      end: endController.text.trim(),
      startTime: startTime,
      endTime: endTime,
      odometerStart: startKm,
      odometerEnd: endKm,
      points: points
          .where((p) => p.controller.text.trim().isNotEmpty)
          .map((p) => RoutePoint(
                name: p.controller.text.trim(),
                type: p.type,
                time: p.time,
              ))
          .toList(),
    );

    Navigator.pop(context, trip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTrip == null ? 'Nowa trasa' : 'Edytuj trasę'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Informacje o trasie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: chooseDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                'Data: ${selectedDate.day.toString().padLeft(2, '0')}.'
                '${selectedDate.month.toString().padLeft(2, '0')}.'
                '${selectedDate.year}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 18),
            buildField(
              controller: startController,
              label: 'Miejsce rozpoczęcia',
              hint: 'Np. Poznań',
              icon: Icons.trip_origin,
              validator: requiredText,
            ),
            const SizedBox(height: 8),
            timePickerButton(
              label: 'Godzina rozpoczęcia',
              value: startTime,
              onChanged: (value) => setState(() => startTime = value),
            ),
            const SizedBox(height: 14),
            buildField(
              controller: endController,
              label: 'Miejsce zakończenia',
              hint: 'Np. Amsterdam',
              icon: Icons.flag,
              validator: requiredText,
            ),
            const SizedBox(height: 8),
            timePickerButton(
              label: 'Godzina zakończenia',
              value: endTime,
              onChanged: (value) => setState(() => endTime = value),
            ),
            const SizedBox(height: 25),
            const Text(
              'Punkty pośrednie',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'Możesz dodać dowolną liczbę załadunków, rozładunków i postojów.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...List.generate(points.length, (index) {
              final point = points[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Punkt ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => removePoint(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: point.type,
                        decoration: const InputDecoration(
                          labelText: 'Rodzaj punktu',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          'Załadunek',
                          'Rozładunek',
                          'Postój',
                          'Tankowanie',
                          'Inne',
                        ].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => point.type = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: point.controller,
                        decoration: const InputDecoration(
                          labelText: 'Miejscowość / firma / adres',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      timePickerButton(
                        label: 'Godzina postoju / operacji',
                        value: point.time,
                        onChanged: (value) =>
                            setState(() => point.time = value),
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: addPoint,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj punkt trasy'),
            ),
            const SizedBox(height: 25),
            const Text(
              'Stan licznika',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            buildField(
              controller: startKmController,
              label: 'Stan początkowy (km)',
              hint: 'Np. 452100',
              icon: Icons.speed,
              validator: validateKm,
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 14),
            buildField(
              controller: endKmController,
              label: 'Stan końcowy (km)',
              hint: 'Np. 453020',
              icon: Icons.speed,
              validator: validateKm,
              keyboard: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F2E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'PRZEJECHANE KILOMETRY',
                    style: TextStyle(
                      color: Color(0xFF277B49),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${calculatedKm.toStringAsFixed(0)} km',
                    style: const TextStyle(
                      color: Color(0xFF277B49),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            FilledButton.icon(
              onPressed: saveTrip,
              icon: const Icon(Icons.save),
              label: Text(widget.initialTrip == null
                  ? 'Zapisz trasę'
                  : 'Zapisz zmiany'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 58),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboard = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ==========================================
// KARTA TRASY
// ==========================================

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TripCard({super.key, required this.trip, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 7),
                Text(
                  '${trip.date.day.toString().padLeft(2, '0')}.'
                  '${trip.date.month.toString().padLeft(2, '0')}.'
                  '${trip.date.year}',
                ),
                const Spacer(),
                Text(
                  '${trip.kilometers.toStringAsFixed(0)} km',
                  style: const TextStyle(
                    color: Color(0xFF277B49),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'Opcje trasy',
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edytuj'),
                            )),
                      if (onDelete != null)
                        const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('Usuń',
                                  style: TextStyle(color: Colors.red)),
                            )),
                    ],
                  ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.trip_origin, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(trip.start)),
                if (trip.startTime != null)
                  Text(trip.startTime!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            ...trip.points.map((point) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${point.type}: ${point.name}'),
                      ),
                      if (point.time != null)
                        Text(point.time!,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.flag, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(trip.end)),
                  if (trip.endTime != null)
                    Text(trip.endTime!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Licznik: ${trip.odometerStart.toStringAsFixed(0)} → '
              '${trip.odometerEnd.toStringAsFixed(0)} km',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// LISTA TRAS
// ==========================================

class RoutesPage extends StatelessWidget {
  final List<Trip> trips;
  final ValueChanged<Trip> onEdit;
  final ValueChanged<Trip> onDelete;

  const RoutesPage(
      {super.key,
      required this.trips,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Historia tras',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        if (trips.isEmpty)
          const Center(child: Text('Nie zapisano jeszcze żadnej trasy.')),
        ...trips.map((trip) => TripCard(
            trip: trip,
            onEdit: () => onEdit(trip),
            onDelete: () => onDelete(trip))),
      ],
    );
  }
}

// ==========================================
// KALENDARZ
// ==========================================

class CalendarPage extends StatefulWidget {
  final List<Trip> trips;
  final ValueChanged<Trip> onEdit;
  final ValueChanged<Trip> onDelete;

  const CalendarPage(
      {super.key,
      required this.trips,
      required this.onEdit,
      required this.onDelete});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

  final List<String> monthNames = [
    'Styczeń',
    'Luty',
    'Marzec',
    'Kwiecień',
    'Maj',
    'Czerwiec',
    'Lipiec',
    'Sierpień',
    'Wrzesień',
    'Październik',
    'Listopad',
    'Grudzień',
  ];

  final List<String> weekdays = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'];

  bool sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Trip> tripsForDay(DateTime date) {
    return widget.trips.where((trip) => sameDay(trip.date, date)).toList();
  }

  void changeMonth(int difference) {
    setState(() {
      visibleMonth = DateTime(
        visibleMonth.year,
        visibleMonth.month + difference,
      );
      selectedDate = DateTime(visibleMonth.year, visibleMonth.month, 1);
    });
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingDays = (firstDay.weekday + 6) % 7;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final selectedTrips = tripsForDay(selectedDate);
    final selectedKm = selectedTrips.fold<double>(
      0,
      (sum, trip) => sum + trip.kilometers,
    );

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Kalendarz',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Poprzedni miesiąc',
                ),
                Text(
                  '${monthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Następny miesiąc',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: weekdays
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingDays + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              visibleMonth.year,
              visibleMonth.month,
              dayNumber,
            );
            final isSelected = sameDay(date, selectedDate);
            final hasTrips = tripsForDay(date).isNotEmpty;
            final isToday = sameDay(date, DateTime.now());

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => selectedDate = date),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2479D8)
                      : isToday
                          ? const Color(0xFFE1EDFF)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !isSelected
                      ? Border.all(color: const Color(0xFF2479D8))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasTrips)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF2479D8),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const Divider(),
        Text(
          'Trasy z dnia ${formatDate(selectedDate)}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (selectedTrips.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Brak zapisanych tras w tym dniu.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed, color: Color(0xFF2479D8)),
              title: const Text('Łącznie przejechane'),
              trailing: Text(
                '${selectedKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...selectedTrips.map((trip) => TripCard(
              trip: trip,
              onEdit: () => widget.onEdit(trip),
              onDelete: () => widget.onDelete(trip))),
        ],
      ],
    );
  }
}

// ==========================================
// STATYSTYKI
// ==========================================

class StatisticsPage extends StatelessWidget {
  final List<Trip> trips;
  final double totalKm;
  final double monthKm;

  const StatisticsPage({
    super.key,
    required this.trips,
    required this.totalKm,
    required this.monthKm,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Statystyki',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Łącznie przejechane'),
            trailing: Text('${totalKm.toStringAsFixed(0)} km'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('W tym miesiącu'),
            trailing: Text('${monthKm.toStringAsFixed(0)} km'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Liczba tras'),
            trailing: Text('${trips.length}'),
          ),
        ),
      ],
    );
  }
}
