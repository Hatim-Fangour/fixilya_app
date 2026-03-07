import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================
// 🔬 BOOKING SYSTEM DIAGNOSTIC TOOL
// Add this as a button in your handyman home page
// ============================================

class BookingDiagnosticTool extends StatefulWidget {
  const BookingDiagnosticTool({super.key});

  @override
  State<BookingDiagnosticTool> createState() => _BookingDiagnosticToolState();
}

class _BookingDiagnosticToolState extends State<BookingDiagnosticTool> {
  List<String> diagnosticResults = [];
  bool isRunning = false;

  Future<void> runDiagnostics() async {
    setState(() {
      diagnosticResults.clear();
      isRunning = true;
    });

    await _addResult('🔍 Starting Booking System Diagnostics...\n');

    // Test 1: Check Authentication
    await _checkAuth();

    // Test 2: Check Firestore Connection
    await _checkFirestore();

    // Test 3: Check Bookings Collection
    await _checkBookings();

    // Test 4: Check Notifications Collection
    await _checkNotifications();

    // Test 5: Check Indexes
    await _checkIndexes();

    await _addResult('\n✅ Diagnostics Complete!');

    setState(() => isRunning = false);
  }

  Future<void> _checkAuth() async {
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addResult('TEST 1: Authentication');
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await _addResult('❌ CRITICAL: No user logged in!');
      await _addResult('   Solution: Login first\n');
      return;
    }

    await _addResult('✅ User authenticated');
    await _addResult('   User ID: ${user.uid}');
    await _addResult('   Email: ${user.email}\n');
  }

  Future<void> _checkFirestore() async {
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addResult('TEST 2: Firestore Connection');
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final test = await FirebaseFirestore.instance
          .collection('_test_')
          .limit(1)
          .get();

      await _addResult('✅ Firestore connected\n');
    } catch (e) {
      await _addResult('❌ Firestore connection failed');
      await _addResult('   Error: $e\n');
    }
  }

  Future<void> _checkBookings() async {
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addResult('TEST 3: Bookings Collection');
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      await _addResult('❌ Cannot check: Not logged in\n');
      return;
    }

    try {
      // Check all bookings
      final allBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .get();

      await _addResult(
        '📊 Total bookings in database: ${allBookings.docs.length}',
      );

      // Check bookings for this handyman
      final myBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('handymanId', isEqualTo: uid)
          .get();

      await _addResult('📊 Bookings for you: ${myBookings.docs.length}');

      if (myBookings.docs.isEmpty) {
        await _addResult('⚠️  You have 0 bookings');
        await _addResult('   Checking why...\n');

        // Check if ANY booking has your ID
        bool foundMatch = false;
        for (var doc in allBookings.docs) {
          final data = doc.data();
          if (data['handymanId'] == uid) {
            foundMatch = true;
            break;
          }
        }

        if (!foundMatch) {
          await _addResult('   ❌ No bookings have handymanId = $uid');
          await _addResult('   Problem: ID mismatch!');
          await _addResult('   Check handyman ID in client app\n');
        }
      } else {
        await _addResult('\n📋 Your Bookings:');
        for (var doc in myBookings.docs) {
          final data = doc.data();
          await _addResult('   • ${doc.id}');
          await _addResult('     Status: ${data['status']}');
          await _addResult('     Client: ${data['clientName']}');
          await _addResult('     Service: ${data['service']}');
        }
        await _addResult('');
      }

      // Check pending bookings specifically
      final pendingQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('handymanId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      await _addResult('📊 Pending requests: ${pendingQuery.docs.length}');

      if (pendingQuery.docs.isEmpty && myBookings.docs.isNotEmpty) {
        await _addResult('   ℹ️  You have bookings, but none are pending');
        await _addResult('   They might be accepted/declined/completed\n');
      }
    } catch (e) {
      await _addResult('❌ Error checking bookings');
      await _addResult('   Error: $e');

      if (e.toString().contains('index')) {
        await _addResult('   Problem: Missing Firestore index!');
        await _addResult('   Solution: Create required indexes\n');
      }
    }
  }

  Future<void> _checkNotifications() async {
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addResult('TEST 4: Notifications');
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      await _addResult('❌ Cannot check: Not logged in\n');
      return;
    }

    try {
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();

      await _addResult('📊 Total notifications: ${notifications.docs.length}');

      if (notifications.docs.isEmpty) {
        await _addResult('⚠️  You have 0 notifications');
        await _addResult('   This is unusual if bookings were created\n');
      } else {
        final unread = notifications.docs
            .where((doc) => doc.data()['read'] == false)
            .length;
        await _addResult('   Unread: $unread');
        await _addResult('   Read: ${notifications.docs.length - unread}\n');

        await _addResult('📋 Recent Notifications:');
        for (var doc in notifications.docs.take(3)) {
          final data = doc.data();
          await _addResult('   • ${data['title']}');
          await _addResult('     ${data['message']}');
          await _addResult('     Type: ${data['type']}');
        }
        await _addResult('');
      }
    } catch (e) {
      await _addResult('❌ Error checking notifications');
      await _addResult('   Error: $e\n');
    }
  }

  Future<void> _checkIndexes() async {
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _addResult('TEST 5: Required Indexes');
    _addResult('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      await _addResult('❌ Cannot check: Not logged in\n');
      return;
    }

    // Test each query that needs an index
    final tests = [
      {
        'name': 'Active Bookings Query',
        'test': () => FirebaseFirestore.instance
            .collection('bookings')
            .where('handymanId', isEqualTo: uid)
            .where('status', whereIn: ['confirmed', 'in_progress'])
            .orderBy('scheduledDate', descending: false)
            .limit(1)
            .get(),
      },
      {
        'name': 'Pending Requests Query',
        'test': () => FirebaseFirestore.instance
            .collection('bookings')
            .where('handymanId', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(),
      },
      {
        'name': 'Declined Bookings Query',
        'test': () => FirebaseFirestore.instance
            .collection('bookings')
            .where('handymanId', isEqualTo: uid)
            .where('status', isEqualTo: 'declined')
            .orderBy('declinedAt', descending: true)
            .limit(1)
            .get(),
      },
      {
        'name': 'Notifications Query',
        'test': () => FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .where('read', isEqualTo: false)
            .limit(1)
            .get(),
      },
    ];

    for (var test in tests) {
      try {
        final testFunc =
            test['test']
                as Future<QuerySnapshot<Map<String, dynamic>>> Function();
        await testFunc();
        await _addResult('✅ ${test['name']}');
      } catch (e) {
        await _addResult('❌ ${test['name']}');
        if (e.toString().contains('index')) {
          await _addResult('   Missing index! Click error link to create');
        }
      }
    }

    await _addResult('');
  }

  Future<void> _addResult(String message) async {
    setState(() {
      diagnosticResults.add(message);
    });
    await Future.delayed(Duration(milliseconds: 100));
    if (kDebugMode) debugPrint(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Diagnostics'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black87,
              padding: EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: diagnosticResults.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      diagnosticResults[index],
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isRunning ? null : runDiagnostics,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: isRunning
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Run Diagnostics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
