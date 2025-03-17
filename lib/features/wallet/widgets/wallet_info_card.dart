import 'package:flutter/material.dart';

class WalletInfoCard extends StatelessWidget {
  const WalletInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              child: Icon(Icons.account_balance_wallet, size: 30),
            ),
            SizedBox(height: 8),
            Text(
              '0x1234...5678',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('ETH Wallet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}