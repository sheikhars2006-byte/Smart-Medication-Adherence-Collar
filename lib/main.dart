import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String kDatabaseBaseUrl =
    'https://medication-tracker-4b3fd-default-rtdb.asia-southeast1.firebasedatabase.app';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Medication Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F3F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      home: const DeviceConnectPage(),
    );
  }
}

class DeviceData {
  final String deviceId;
  final String status;
  final int lastSeenEpoch;
  final int currentPills;
  final int totalDoses;
  final int lastDoseEpoch;
  final String lastDoseText;
  final bool lidOpen;
  final bool movementDetected;
  final bool doseTaken;
  final bool missedDoseAlert;
  final bool sosAlert;
  final bool reminderActive;
  final int offlineQueue;
  final String nextDose1;
  final String nextDose2;
  final String nextDose3;
  final int ax;
  final int ay;
  final int az;
  final int hall;
  final int button;
  final int alert;

  DeviceData({
    required this.deviceId,
    required this.status,
    required this.lastSeenEpoch,
    required this.currentPills,
    required this.totalDoses,
    required this.lastDoseEpoch,
    required this.lastDoseText,
    required this.lidOpen,
    required this.movementDetected,
    required this.doseTaken,
    required this.missedDoseAlert,
    required this.sosAlert,
    required this.reminderActive,
    required this.offlineQueue,
    required this.nextDose1,
    required this.nextDose2,
    required this.nextDose3,
    required this.ax,
    required this.ay,
    required this.az,
    required this.hall,
    required this.button,
    required this.alert,
  });

  factory DeviceData.fromMap(Map<String, dynamic> map) {
    int readInt(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool readBool(String key) {
      final value = map[key];
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is double) return value.toInt() == 1;
      if (value is String) {
        return value == '1' || value.toLowerCase() == 'true';
      }
      return false;
    }

    return DeviceData(
      deviceId: (map['deviceId'] ?? '').toString(),
      status: (map['status'] ?? 'unknown').toString(),
      lastSeenEpoch: readInt('lastSeenEpoch'),
      currentPills: readInt('currentPills'),
      totalDoses: readInt('totalDoses'),
      lastDoseEpoch: readInt('lastDoseEpoch'),
      lastDoseText: (map['lastDoseText'] ?? 'N/A').toString(),
      lidOpen: readBool('lidOpen'),
      movementDetected: readBool('movementDetected'),
      doseTaken: readBool('doseTaken'),
      missedDoseAlert: readBool('missedDoseAlert'),
      sosAlert: readBool('sosAlert'),
      reminderActive: readBool('reminderActive'),
      offlineQueue: readInt('offlineQueue'),
      nextDose1: (map['nextDose1'] ?? '--:--').toString(),
      nextDose2: (map['nextDose2'] ?? '--:--').toString(),
      nextDose3: (map['nextDose3'] ?? '--:--').toString(),
      ax: readInt('ax'),
      ay: readInt('ay'),
      az: readInt('az'),
      hall: readInt('hall'),
      button: readInt('button'),
      alert: readInt('alert'),
    );
  }
}

class DeviceConfig {
  final String patientName;
  final String medicineName;
  final int totalPills;
  final int pillsPerDose;
  final List<String> doseTimes;

  DeviceConfig({
    required this.patientName,
    required this.medicineName,
    required this.totalPills,
    required this.pillsPerDose,
    required this.doseTimes,
  });

  factory DeviceConfig.fromMap(Map<String, dynamic> map) {
    final dynamic doseTimesRaw = map['doseTimes'];
    List<String> times = [];

    if (doseTimesRaw is List) {
      times = doseTimesRaw.map((e) => e.toString()).toList();
    }

    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return DeviceConfig(
      patientName: (map['patientName'] ?? '').toString(),
      medicineName: (map['medicineName'] ?? '').toString(),
      totalPills: readInt(map['totalPills']),
      pillsPerDose: readInt(map['pillsPerDose']),
      doseTimes: times,
    );
  }
}

class HistoryEvent {
  final String id;
  final String event;
  final String time;
  final int epoch;
  final String scheduledTime;
  final int remainingPills;
  final int totalDoses;

  HistoryEvent({
    required this.id,
    required this.event,
    required this.time,
    required this.epoch,
    required this.scheduledTime,
    required this.remainingPills,
    required this.totalDoses,
  });

  factory HistoryEvent.fromMap(String id, Map<String, dynamic> map) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return HistoryEvent(
      id: id,
      event: (map['event'] ?? 'unknown').toString(),
      time: (map['time'] ?? 'N/A').toString(),
      epoch: readInt(map['epoch']),
      scheduledTime: (map['scheduledTime'] ?? '--:--').toString(),
      remainingPills: readInt(map['remainingPills']),
      totalDoses: readInt(map['totalDoses']),
    );
  }
}

class DeviceConnectPage extends StatefulWidget {
  const DeviceConnectPage({super.key});

  @override
  State<DeviceConnectPage> createState() => _DeviceConnectPageState();
}

class _DeviceConnectPageState extends State<DeviceConnectPage> {
  final TextEditingController _deviceIdController =
      TextEditingController(text: 'COL001');

  bool isLoading = false;
  String errorMessage = '';

  Future<void> connectDevice() async {
    final deviceId = _deviceIdController.text.trim();

    if (deviceId.isEmpty) {
      setState(() {
        errorMessage = 'Please enter Device ID';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final configUrl = '$kDatabaseBaseUrl/deviceConfig/$deviceId.json';
      final configResponse = await http.get(Uri.parse(configUrl)).timeout(
        const Duration(seconds: 8),
      );

      if (!mounted) return;

      if (configResponse.statusCode == 200 &&
          configResponse.body != 'null' &&
          configResponse.body.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceHomePage(deviceId: deviceId),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SetupPage(deviceId: deviceId),
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Connection Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF8F4FB),
              Color(0xFFECE4F7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 80,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withAlpha(30),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.medication_outlined,
                      size: 42,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Smart Medication Tracker',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter the unique COLID / device ID to connect to a medication pod.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextField(
                            controller: _deviceIdController,
                            decoration: const InputDecoration(
                              labelText: 'Enter COLID / Device ID',
                              hintText: 'Example: COL001',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code_2_outlined),
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isLoading ? null : connectDevice,
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.link),
                              label:
                                  Text(isLoading ? 'Connecting...' : 'Connect'),
                            ),
                          ),
                          if (errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupPage extends StatefulWidget {
  final String deviceId;

  const SetupPage({super.key, required this.deviceId});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _totalPillsController = TextEditingController();
  final TextEditingController _pillsPerDoseController = TextEditingController();

  final List<TextEditingController> _timeControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  bool isSaving = false;

  Future<void> saveConfig() async {
    setState(() {
      isSaving = true;
    });

    final doseTimes = _timeControllers
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final body = {
      "patientName": _patientNameController.text.trim(),
      "medicineName": _medicineNameController.text.trim(),
      "totalPills": int.tryParse(_totalPillsController.text.trim()) ?? 0,
      "pillsPerDose": int.tryParse(_pillsPerDoseController.text.trim()) ?? 1,
      "doseTimes": doseTimes,
    };

    final url = '$kDatabaseBaseUrl/deviceConfig/${widget.deviceId}.json';

    await http.put(
      Uri.parse(url),
      body: jsonEncode(body),
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceHomePage(deviceId: widget.deviceId),
      ),
    );
  }

  Widget inputField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup ${widget.deviceId}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              inputField('Patient Name', _patientNameController),
              inputField('Medicine Name', _medicineNameController),
              inputField(
                'Total Pills',
                _totalPillsController,
                keyboardType: TextInputType.number,
              ),
              inputField(
                'Pills Per Dose',
                _pillsPerDoseController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dose Times (HH:MM)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              inputField('Dose Time 1', _timeControllers[0]),
              inputField('Dose Time 2', _timeControllers[1]),
              inputField('Dose Time 3', _timeControllers[2]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSaving ? null : saveConfig,
                  child: Text(isSaving ? 'Saving...' : 'Save Configuration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceHomePage extends StatefulWidget {
  final String deviceId;

  const DeviceHomePage({super.key, required this.deviceId});

  @override
  State<DeviceHomePage> createState() => _DeviceHomePageState();
}

class _DeviceHomePageState extends State<DeviceHomePage> {
  int selectedIndex = 0;
  bool isLoading = true;
  String errorMessage = '';
  DeviceData? deviceData;
  DeviceConfig? deviceConfig;
  List<HistoryEvent> historyEvents = [];
  Timer? autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    refreshAll();

    autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshAll();
    });
  }

  @override
  void dispose() {
    autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      fetchDeviceData(),
      fetchConfig(),
      fetchHistory(),
    ]);
  }

  Future<void> fetchDeviceData() async {
    try {
      final url = '$kDatabaseBaseUrl/devices/${widget.deviceId}.json';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = 'HTTP Error: ${response.statusCode}';
        });
        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No device data found';
        });
        return;
      }

      if (decoded is! Map) {
        setState(() {
          isLoading = false;
          errorMessage = 'Unexpected device format';
        });
        return;
      }

      setState(() {
        deviceData = DeviceData.fromMap(Map<String, dynamic>.from(decoded));
        isLoading = false;
        errorMessage = '';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Device load error: $e';
      });
    }
  }

  Future<void> fetchConfig() async {
    try {
      final url = '$kDatabaseBaseUrl/deviceConfig/${widget.deviceId}.json';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode != 200 || response.body == 'null') {
        setState(() {
          deviceConfig = null;
        });
        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        setState(() {
          deviceConfig = DeviceConfig.fromMap(
            Map<String, dynamic>.from(decoded),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> fetchHistory() async {
    try {
      final url = '$kDatabaseBaseUrl/history/${widget.deviceId}.json';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);

      if (decoded == null) {
        setState(() {
          historyEvents = [];
        });
        return;
      }

      if (decoded is! Map) return;

      final mapped = Map<String, dynamic>.from(decoded);
      final List<HistoryEvent> events = [];

      mapped.forEach((key, value) {
        if (value is Map) {
          events.add(
            HistoryEvent.fromMap(
              key,
              Map<String, dynamic>.from(value),
            ),
          );
        }
      });

      events.sort((a, b) => b.epoch.compareTo(a.epoch));

      setState(() {
        historyEvents = events;
      });
    } catch (_) {}
  }

  bool get isActuallyOnline {
    if (deviceData == null) return false;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (nowEpoch - deviceData!.lastSeenEpoch) <= 20;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        deviceId: widget.deviceId,
        deviceData: deviceData,
        deviceConfig: deviceConfig,
        isLoading: isLoading,
        errorMessage: errorMessage,
        isActuallyOnline: isActuallyOnline,
        onRefresh: refreshAll,
        historyEvents: historyEvents,
      ),
      MonitoringPage(
        deviceId: widget.deviceId,
        deviceData: deviceData,
        deviceConfig: deviceConfig,
        isLoading: isLoading,
        errorMessage: errorMessage,
        isActuallyOnline: isActuallyOnline,
        onRefresh: refreshAll,
      ),
      HistoryPage(
        deviceId: widget.deviceId,
        historyEvents: historyEvents,
        isLoading: isLoading,
        errorMessage: errorMessage,
        onRefresh: refreshAll,
      ),
      ProfilePage(
        deviceId: widget.deviceId,
        deviceData: deviceData,
        deviceConfig: deviceConfig,
        isLoading: isLoading,
        errorMessage: errorMessage,
        isActuallyOnline: isActuallyOnline,
        onRefresh: refreshAll,
        onChangeDevice: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DeviceConnectPage()),
            (route) => false,
          );
        },
        onEditSetup: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SetupPage(deviceId: widget.deviceId),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Monitoring',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final String deviceId;
  final DeviceData? deviceData;
  final DeviceConfig? deviceConfig;
  final bool isLoading;
  final String errorMessage;
  final bool isActuallyOnline;
  final Future<void> Function() onRefresh;
  final List<HistoryEvent> historyEvents;

  const DashboardPage({
    super.key,
    required this.deviceId,
    required this.deviceData,
    required this.deviceConfig,
    required this.isLoading,
    required this.errorMessage,
    required this.isActuallyOnline,
    required this.onRefresh,
    required this.historyEvents,
  });

  bool get refillLow {
    if (deviceData == null) return false;
    return deviceData!.currentPills <= 5;
  }

  String get overallStatus {
    if (deviceData == null) return 'No Data';
    if (deviceData!.sosAlert) return 'Emergency Alert Active';
    if (deviceData!.missedDoseAlert) return 'Missed Dose Detected';
    if (deviceData!.reminderActive) return 'Reminder Active';
    if (!isActuallyOnline) return 'Device Offline';
    return 'Monitoring Normally';
  }

  Color get overallColor {
    if (deviceData == null) return Colors.grey;
    if (deviceData!.sosAlert) return Colors.red;
    if (deviceData!.missedDoseAlert) return Colors.red;
    if (deviceData!.reminderActive) return Colors.orange;
    if (!isActuallyOnline) return Colors.grey;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final patientName =
        (deviceConfig?.patientName.isNotEmpty ?? false) ? deviceConfig!.patientName : 'Patient';
    final medicineName = (deviceConfig?.medicineName.isNotEmpty ?? false)
        ? deviceConfig!.medicineName
        : 'Medicine';

    final configuredDoseTimes = (deviceConfig?.doseTimes.isNotEmpty ?? false)
        ? deviceConfig!.doseTimes.join(', ')
        : '${deviceData?.nextDose1 ?? '--:--'}, ${deviceData?.nextDose2 ?? '--:--'}, ${deviceData?.nextDose3 ?? '--:--'}';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard',
                        style:
                            TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'COLID: $deviceId',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage.isNotEmpty)
              _ErrorCard(message: errorMessage)
            else if (deviceData != null) ...[
              _HeroStatusCard(
                title: overallStatus,
                subtitle: 'Live caregiver summary',
                color: overallColor,
                statusText: isActuallyOnline ? 'ONLINE' : 'OFFLINE',
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(patientName),
                  subtitle: Text(medicineName),
                  trailing: Text(
                    'COLID\n$deviceId',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.medication_outlined,
                      title: 'Pills Left',
                      value: '${deviceData!.currentPills}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      title: 'Total Doses',
                      value: '${deviceData!.totalDoses}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoTileCard(
                icon: Icons.access_time,
                title: 'Last Dose Time',
                value: deviceData!.lastDoseText,
              ),
              _InfoTileCard(
                icon: Icons.schedule,
                title: 'Configured Dose Times',
                value: configuredDoseTimes,
              ),
              _InfoTileCard(
                icon: Icons.medication_liquid_outlined,
                title: 'Pills Per Dose',
                value: '${deviceConfig?.pillsPerDose ?? 1}',
              ),
              _InfoTileCard(
                icon: Icons.inventory_2_outlined,
                title: 'Configured Total Pills',
                value: '${deviceConfig?.totalPills ?? 0}',
              ),
              _InfoTileCard(
                icon: Icons.warning_amber_rounded,
                title: 'Missed Dose Alert',
                value: deviceData!.missedDoseAlert ? 'YES' : 'NO',
                valueColor:
                    deviceData!.missedDoseAlert ? Colors.red : Colors.green,
              ),
              _InfoTileCard(
                icon: Icons.emergency,
                title: 'SOS Alert',
                value: deviceData!.sosAlert ? 'ACTIVE' : 'NO',
                valueColor: deviceData!.sosAlert ? Colors.red : Colors.green,
              ),
              _InfoTileCard(
                icon: Icons.notifications_active_outlined,
                title: 'Reminder Status',
                value: deviceData!.reminderActive ? 'ACTIVE' : 'IDLE',
                valueColor:
                    deviceData!.reminderActive ? Colors.orange : Colors.green,
              ),
              _InfoTileCard(
                icon: Icons.local_hospital_outlined,
                title: 'Refill Alert',
                value: refillLow ? 'LOW STOCK' : 'NORMAL',
                valueColor: refillLow ? Colors.red : Colors.green,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalyticsPage(
                          historyEvents: historyEvents,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.show_chart),
                  label: const Text('View Analytics'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MonitoringPage extends StatelessWidget {
  final String deviceId;
  final DeviceData? deviceData;
  final DeviceConfig? deviceConfig;
  final bool isLoading;
  final String errorMessage;
  final bool isActuallyOnline;
  final Future<void> Function() onRefresh;

  const MonitoringPage({
    super.key,
    required this.deviceId,
    required this.deviceData,
    required this.deviceConfig,
    required this.isLoading,
    required this.errorMessage,
    required this.isActuallyOnline,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Monitoring',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage.isNotEmpty)
              _ErrorCard(message: errorMessage)
            else if (deviceData != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _SignalCard(
                      title: 'Online State',
                      value: isActuallyOnline ? 'ONLINE' : 'OFFLINE',
                      icon: Icons.wifi_tethering_outlined,
                      color: isActuallyOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SignalCard(
                      title: 'Offline Queue',
                      value: '${deviceData!.offlineQueue}',
                      icon: Icons.sync_problem_outlined,
                      color: deviceData!.offlineQueue > 0
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SignalCard(
                      title: 'Hall Sensor',
                      value: '${deviceData!.hall}',
                      icon: Icons.sensors_outlined,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SignalCard(
                      title: 'Button',
                      value: '${deviceData!.button}',
                      icon: Icons.radio_button_checked,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SignalCard(
                      title: 'Lid Open',
                      value: deviceData!.lidOpen ? 'Yes' : 'No',
                      icon: Icons.sensor_door_outlined,
                      color:
                          deviceData!.lidOpen ? Colors.orange : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SignalCard(
                      title: 'Movement',
                      value:
                          deviceData!.movementDetected ? 'Detected' : 'No',
                      icon: Icons.directions_run,
                      color: deviceData!.movementDetected
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Accelerometer Data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _AxisCard(label: 'AX', value: '${deviceData!.ax}'),
              _AxisCard(label: 'AY', value: '${deviceData!.ay}'),
              _AxisCard(label: 'AZ', value: '${deviceData!.az}'),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.show_chart),
                  title: const Text('Visual Analytics'),
                  subtitle: const Text('Open simple trend graph'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalyticsPage(
                          historyEvents: const [],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  final String deviceId;
  final List<HistoryEvent> historyEvents;
  final bool isLoading;
  final String errorMessage;
  final Future<void> Function() onRefresh;

  const HistoryPage({
    super.key,
    required this.deviceId,
    required this.historyEvents,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'History',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage.isNotEmpty)
              _ErrorCard(message: errorMessage)
            else if (historyEvents.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: const [
                      Icon(Icons.history, size: 54, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No history available yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...historyEvents.map((event) {
                final taken = event.event == 'dose_taken';
                final missed = event.event == 'dose_missed';
                final sos = event.event == 'SOS';

                Color color = Colors.grey;
                IconData icon = Icons.info;

                if (taken) {
                  color = Colors.green;
                  icon = Icons.check;
                } else if (missed) {
                  color = Colors.red;
                  icon = Icons.warning_amber_rounded;
                } else if (sos) {
                  color = Colors.deepOrange;
                  icon = Icons.emergency;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: color.withAlpha(30),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(
                      event.event,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Logged time: ${event.time}'),
                          Text('Scheduled time: ${event.scheduledTime}'),
                          Text('Pills remaining: ${event.remainingPills}'),
                          Text('Total doses: ${event.totalDoses}'),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final String deviceId;
  final DeviceData? deviceData;
  final DeviceConfig? deviceConfig;
  final bool isLoading;
  final String errorMessage;
  final bool isActuallyOnline;
  final Future<void> Function() onRefresh;
  final VoidCallback onChangeDevice;
  final VoidCallback onEditSetup;

  const ProfilePage({
    super.key,
    required this.deviceId,
    required this.deviceData,
    required this.deviceConfig,
    required this.isLoading,
    required this.errorMessage,
    required this.isActuallyOnline,
    required this.onRefresh,
    required this.onChangeDevice,
    required this.onEditSetup,
  });

  @override
  Widget build(BuildContext context) {
    final patientName =
        (deviceConfig?.patientName.isNotEmpty ?? false) ? deviceConfig!.patientName : 'Not set';
    final medicineName =
        (deviceConfig?.medicineName.isNotEmpty ?? false) ? deviceConfig!.medicineName : 'Not set';

    final doseTimes = (deviceConfig?.doseTimes.isNotEmpty ?? false)
        ? deviceConfig!.doseTimes.join(', ')
        : 'Not set';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Profile',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      child: Icon(Icons.person, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Caregiver',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connected COLID: $deviceId',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage.isNotEmpty)
              _ErrorCard(message: errorMessage)
            else ...[
              _InfoTileCard(
                icon: Icons.memory,
                title: 'Device ID',
                value: deviceData?.deviceId.isNotEmpty == true
                    ? deviceData!.deviceId
                    : deviceId,
              ),
              _InfoTileCard(
                icon: Icons.person_outline,
                title: 'Patient Name',
                value: patientName,
              ),
              _InfoTileCard(
                icon: Icons.medication_liquid_outlined,
                title: 'Medicine Name',
                value: medicineName,
              ),
              _InfoTileCard(
                icon: Icons.inventory_2_outlined,
                title: 'Configured Total Pills',
                value: '${deviceConfig?.totalPills ?? 0}',
              ),
              _InfoTileCard(
                icon: Icons.medication_outlined,
                title: 'Pills Per Dose',
                value: '${deviceConfig?.pillsPerDose ?? 0}',
              ),
              _InfoTileCard(
                icon: Icons.schedule,
                title: 'Dose Times',
                value: doseTimes,
              ),
              _InfoTileCard(
                icon: Icons.wifi,
                title: 'Live Status',
                value: isActuallyOnline ? 'ONLINE' : 'OFFLINE',
                valueColor: isActuallyOnline ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onEditSetup,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Patient / Medicine Setup'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onChangeDevice,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change COLID'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AnalyticsPage extends StatelessWidget {
  final List<HistoryEvent> historyEvents;

  const AnalyticsPage({super.key, required this.historyEvents});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> dayCounts = {};

    for (final event in historyEvents) {
      if (event.time.length >= 10) {
        final day = event.time.substring(0, 10);
        dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      }
    }

    final entries = dayCounts.entries.toList();
    final spots = <FlSpot>[];

    for (int i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value.toDouble()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: historyEvents.isEmpty
            ? const Center(
                child: Text(
                  'No analytics data yet',
                  style: TextStyle(fontSize: 18),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dose Activity Trend',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Simple visual graph of recorded events',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: const FlTitlesData(show: true),
                            borderData: FlBorderData(show: true),
                            minX: 0,
                            maxX: spots.isEmpty ? 1 : spots.length.toDouble() - 1,
                            minY: 0,
                            maxY: spots.isEmpty
                                ? 5
                                : (spots
                                        .map((e) => e.y)
                                        .reduce((a, b) => a > b ? a : b) +
                                    1),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                dotData: const FlDotData(show: true),
                                barWidth: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Total history events: ${historyEvents.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
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

class _HeroStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final String statusText;

  const _HeroStatusCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha(240),
            color.withAlpha(190),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(60),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _InfoTileCard({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: SizedBox(
          width: 150,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SignalCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisCard extends StatelessWidget {
  final String label;
  final String value;

  const _AxisCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(label),
        ),
        title: Text('$label Axis Value'),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}