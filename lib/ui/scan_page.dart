import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// Note: qrcode_reader package is not in your pubspec
// You might need to add a QR scanning package like mobile_scanner or qr_code_scanner
// For this example, I'll assume you have a QR scanner package with similar API

import 'package:workout_planner/ui/components/routine_overview_card.dart';
import 'package:workout_planner/resource/db_provider.dart';
import 'components//custom_snack_bars.dart';
import 'package:workout_planner/models/routine.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final textEditingController = TextEditingController();
  String barcode = "";
  Routine? routine;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    textEditingController.addListener(() {});
    super.initState();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Scan'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                    onPressed: input, child: const Text('Enter routine ID')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                    onPressed: scan, child: const Text('Scan QR code')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
                child: isValidRoutineJsonStr(barcode)
                    ? FutureBuilder<RoutineOverview>(
                  future: getRoutineOverView(barcode),
                  builder: (_, snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    } else {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                  },
                )
                    : Container(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.0),
                child: isValidRoutineJsonStr(barcode)
                    ? Builder(
                  builder: (context) => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (routine != null) {
                        DBProvider.db.newRoutine(routine!);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Row(
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.done),
                                ),
                                Text('Added to my routines.'),
                              ],
                            )));
                      }
                    },
                    child: const Text('Add to my routines'),
                  ),
                )
                    : Container(),
              ),
            ],
          ),
        ));
  }

  Future<void> input() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(noNetworkSnackBar);
    } else {
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (_) {
            return Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Material(
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      onSubmitted: (str) {
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() {
                            barcode = '-r$str';
                          });
                        }
                      },
                      controller: textEditingController,
                      decoration: const InputDecoration(hintText: 'Routine ID'),
                    ),
                  ),
                ),
              ),
            );
          });
    }
  }

  Future<void> scan() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(noNetworkSnackBar);
    } else {
      try {
        // Since qrcode_reader isn't in your pubspec, you'll need to replace this
        // with whatever QR scanning package you're using
        // This is a placeholder for your QR scanning implementation
        final result = await scanQRCode();
        if (result != null && mounted) {
          setState(() {
            barcode = result;
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to scan QR code: ${e.toString()}')),
        );
      }
    }
  }

  // Placeholder for QR scanning implementation
  Future<String?> scanQRCode() async {
    // Replace this with your actual QR scanning implementation
    // For example, if using mobile_scanner:
    // final controller = MobileScannerController();
    // final result = await Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => MobileScanner(
    //       controller: controller,
    //       onDetect: (capture) {
    //         final List<Barcode> barcodes = capture.barcodes;
    //         for (final barcode in barcodes) {
    //           return barcode.rawValue;
    //         }
    //       },
    //     ),
    //   ),
    // );
    // return result;

    // For now, return mock data
    throw Exception('QR scanning not implemented - add a QR scanning package to your pubspec.yaml');
  }

  bool isValidRoutineJsonStr(String? str) {
    if (str == null || str.isEmpty) {
      return false;
    } else if (str.startsWith('-r')) {
      return true;
    } else {
      return false;
    }
  }

  Future<RoutineOverview> getRoutineOverView(String str) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("userShares")
          .doc(str.replaceFirst("-r", ""))
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Routine not found');
      }

      final routineStr = snapshot.data()!['routine'] as String?;
      if (routineStr == null) {
        throw Exception('Invalid routine data');
      }

      routine = Routine.fromMap(jsonDecode(routineStr.replaceFirst('-r', '')));
      return RoutineOverview(
        routine: routine!,
      );
    } catch (e) {
      throw Exception('Failed to load routine: ${e.toString()}');
    }
  }
}