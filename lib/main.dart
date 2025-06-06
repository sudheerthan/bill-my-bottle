import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(WaterDeliveryApp());
}

class WaterDeliveryApp extends StatelessWidget {
  const WaterDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Delivery Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}

class Delivery {
  final int? id;
  final DateTime date;
  final int bottles;
  final bool isPaid;

  Delivery({
    this.id,
    required this.date,
    required this.bottles,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'bottles': bottles,
      'isPaid': isPaid ? 1 : 0,
    };
  }

  static Delivery fromMap(Map<String, dynamic> map) {
    return Delivery(
      id: map['id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      bottles: map['bottles'],
      isPaid: map['isPaid'] == 1,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'deliveries.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE deliveries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        bottles INTEGER NOT NULL,
        isPaid INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertDelivery(Delivery delivery) async {
    final db = await database;
    return await db.insert('deliveries', delivery.toMap());
  }

  Future<List<Delivery>> getDeliveries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'deliveries',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Delivery.fromMap(maps[i]));
  }

  Future<List<Delivery>> getDeliveriesForMonth(DateTime month) async {
    final db = await database;
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    final List<Map<String, dynamic>> maps = await db.query(
      'deliveries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        startOfMonth.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Delivery.fromMap(maps[i]));
  }

  Future<int> updateDelivery(Delivery delivery) async {
    final db = await database;
    return await db.update(
      'deliveries',
      delivery.toMap(),
      where: 'id = ?',
      whereArgs: [delivery.id],
    );
  }

  Future<int> deleteDelivery(int id) async {
    final db = await database;
    return await db.delete(
      'deliveries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// Preferences Helper to persist rate per bottle
class PreferencesHelper {
  static const String _ratePerBottleKey = 'rate_per_bottle';
  
  static Future<double> getRatePerBottle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_ratePerBottleKey) ?? 20.0;
  }
  
  static Future<void> setRatePerBottle(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ratePerBottleKey, rate);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      TrackDeliveryScreen(),
      MonthlySummaryScreen(),
      DeliveryHistoryScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Track',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class TrackDeliveryScreen extends StatefulWidget {
  const TrackDeliveryScreen({super.key});

  @override
  _TrackDeliveryScreenState createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  DateTime _selectedDate = DateTime.now();
  int _bottleCount = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bill My Bottle'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,  
      ),
      
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
        //  mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            Text(
            'Track Every Drop. Simplify Every Delivery.',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          // SizedBox(height: 2),
          Image.asset(
            'assets/icons/20l_can.png',
            height: 130,
          ),
          
          
            // SizedBox(height: 5),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '🤖 Tap & Go',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () => _addDelivery(context, DateTime.now(), 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                      child: Text('🛒 Log One Delivery'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 2),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '📖 Custom Log',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.calendar_today, color: Colors.blue[600]),
                      title: Text('Date'),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      onTap:()=> _selectDate(context),
                    ),
                    ListTile(
                      leading: Icon(Icons.local_drink, color: Colors.blue[600]),
                      title: Text('Bottles'),
                      subtitle: Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() {
                              if (_bottleCount > 1) _bottleCount--;
                            }),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$_bottleCount',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _bottleCount++),
                            icon: Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4),
                    ElevatedButton(
                      onPressed: () => _addDelivery(context, _selectedDate, _bottleCount),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: Text('Add Delivery'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _addDelivery(BuildContext context,DateTime date, int bottles) async {
    final delivery = Delivery(date: date, bottles: bottles);
    await _dbHelper.insertDelivery(delivery);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$bottles bottle(s) added for ${DateFormat('MMM dd').format(date)}'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Reset custom entry
    setState(() {
      _selectedDate = DateTime.now();
      _bottleCount = 1;
    });
  }
}

class MonthlySummaryScreen extends StatefulWidget {
  const MonthlySummaryScreen({super.key});

  @override
  _MonthlySummaryScreenState createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  DateTime _selectedMonth = DateTime.now();
  List<Delivery> _monthlyDeliveries = [];
  double _ratePerBottle = 60.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRatePerBottle();
    _loadMonthlyData();
  }

  Future<void> _loadRatePerBottle() async {
    final rate = await PreferencesHelper.getRatePerBottle();
    setState(() {
      _ratePerBottle = rate;
    });
  }

  Future<void> _loadMonthlyData() async {
    setState(() => _isLoading = true);
    final deliveries = await _dbHelper.getDeliveriesForMonth(_selectedMonth);
    setState(() {
      _monthlyDeliveries = deliveries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalBottles = _monthlyDeliveries.fold<int>(0, (sum, d) => sum + d.bottles);
    final totalCost = totalBottles * _ratePerBottle;
    final paidDeliveries = _monthlyDeliveries.where((d) => d.isPaid).length;
    final unpaidDeliveries = _monthlyDeliveries.length - paidDeliveries;

    return Scaffold(
      appBar: AppBar(
        title: Text('Monthly Summary'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () => _changeMonth(-1),
                                  icon: Icon(Icons.chevron_left),
                                ),
                                Flexible(
                                  child: Text(
                                    DateFormat('MMMM yyyy').format(_selectedMonth),
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _changeMonth(1),
                                  icon: Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            ListTile(
                              leading: Icon(Icons.local_drink, color: Colors.blue),
                              title: Text('Rate per Bottle'),
                              subtitle: Text('₹${_ratePerBottle.toStringAsFixed(0)}'),
                              trailing: IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () => _editRate(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Using flexible layout instead of expanded
                    Container(
                      height: MediaQuery.of(context).size.height * 0.5, // Fixed height
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildSummaryCard(
                            'Total Bottles',
                            '$totalBottles',
                            Icons.local_drink,
                            Colors.blue,
                          ),
                          _buildSummaryCard(
                            'Estimated Cost',
                            '₹${totalCost.toStringAsFixed(0)}',
                            Icons.currency_rupee,
                            Colors.green,
                          ),
                          _buildSummaryCard(
                            'Deliveries',
                            '${_monthlyDeliveries.length}',
                            Icons.delivery_dining,
                            Colors.orange,
                          ),
                          _buildSummaryCard(
                            'Pending Payment',
                            '$unpaidDeliveries',
                            Icons.payment,
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(12), // Reduced padding to fit content better
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color), // Reduced icon size
            SizedBox(height: 6),
            Flexible(
              child: Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color), // Reduced font size
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]), // Reduced font size
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd);
    });
    _loadMonthlyData();
  }

  Future<void> _editRate(BuildContext context) async {
    final controller = TextEditingController(text: _ratePerBottle.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Rate per Bottle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Rate (₹)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final rate = double.tryParse(controller.text);
              if (rate != null && rate > 0) {
                Navigator.pop(context, rate);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      setState(() => _ratePerBottle = result);
      // Save to persistent storage
      await PreferencesHelper.setRatePerBottle(result);
    }
  }
}

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  _DeliveryHistoryScreenState createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Delivery> _deliveries = [];
  bool _isListView = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    final deliveries = await _dbHelper.getDeliveries();
    setState(() {
      _deliveries = deliveries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery History'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.calendar_view_month : Icons.list),
            onPressed: () => setState(() => _isListView = !_isListView),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _isListView
              ? _buildListView()
              : _buildCalendarView(context),
    );
  }

  Widget _buildListView() {
    if (_deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_drink, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No deliveries recorded yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _deliveries.length,
      itemBuilder: (context, index) {
        final delivery = _deliveries[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading:  Image.asset(
                    'assets/icons/20l_bottle.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
            title: Text(DateFormat('MMM dd, yyyy').format(delivery.date)),
            //subtitle: Text('${delivery.bottles} bottle(s)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  delivery.isPaid ? Icons.currency_rupee_outlined : Icons.hourglass_empty,
                  color: delivery.isPaid ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(context, value, delivery),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_payment',
                      child: Text(delivery.isPaid ? 'Mark as Unpaid' : 'Mark as Paid'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView(BuildContext context,) {
    final deliveryDates = _deliveries.map((d) => DateTime(d.date.year, d.date.month, d.date.day)).toSet();
    
    return TableCalendar<Delivery>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: DateTime.now(),
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {
    CalendarFormat.month: 'Month',
  },
      eventLoader: (day) {
        return _deliveries.where((delivery) {
          return isSameDay(delivery.date, day);
        }).toList();
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, deliveries) {
          if (deliveries.isNotEmpty) {
            final totalBottles = deliveries.fold<int>(0, (sum, d) => sum + (d).bottles);
            return Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(6),
                ),
                width: 16,
                height: 16,
                child: Center(
                  child: Text(
                    '$totalBottles',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            );
          }
          return null;
        },
      ),
      onDaySelected: (selectedDay, focusedDay) {
        final dayDeliveries = _deliveries.where((d) => isSameDay(d.date, selectedDay)).toList();
        if (dayDeliveries.isNotEmpty) {
          _showDayDetails(context, selectedDay, dayDeliveries);
        }
      },
    );
  }

  void _showDayDetails(BuildContext context,DateTime day, List<Delivery> deliveries) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DateFormat('MMM dd, yyyy').format(day)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: deliveries.map((delivery) => ListTile(
            leading: Icon(
              delivery.isPaid ? Icons.attach_money : Icons.error_outline,
              color: delivery.isPaid ? Colors.green : Colors.orange,
            ),
            title: Text('${delivery.bottles} bottle(s)'),
            subtitle: Text(delivery.isPaid ? 'Paid' : 'Pending'),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(BuildContext context,String action, Delivery delivery) async {
    if (action == 'toggle_payment') {
      final updatedDelivery = Delivery(
        id: delivery.id,
        date: delivery.date,
        bottles: delivery.bottles,
        isPaid: !delivery.isPaid,
      );
      await _dbHelper.updateDelivery(updatedDelivery);
      _loadDeliveries();
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Delivery'),
          content: Text('Are you sure you want to delete this delivery?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        await _dbHelper.deleteDelivery(delivery.id!);
        _loadDeliveries();
      }
    }
  }
}