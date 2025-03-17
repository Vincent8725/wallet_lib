import 'package:flutter/material.dart';
import 'package:wallet_lib/features/home/screens/main_screen.dart';
import 'package:web3dart/credentials.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final privateKey = EthPrivateKey.createRandom();
                  final address = privateKey.address;
                  print(address);
                },
                child: const Text('Create Wallet'),
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(builder: (context) => MainScreen()),
                  );
                },
                child: const Text('Open Wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
