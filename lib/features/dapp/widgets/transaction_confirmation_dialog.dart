import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'dart:math' as math;

class TransactionConfirmationDialog extends StatelessWidget {
  final String from;
  final String to;
  final String? value;
  final String? data;
  
  const TransactionConfirmationDialog({
    Key? key,
    required this.from,
    required this.to,
    this.value,
    this.data,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 计算交易金额（如果有）
    String valueText = '0 ETH';
    if (value != null && value!.isNotEmpty) {
      try {
        final valueInWei = BigInt.parse(value!);
        final valueInEth = EtherAmount.fromBigInt(EtherUnit.wei, valueInWei)
            .getValueInUnit(EtherUnit.ether);
        valueText = '$valueInEth ETH';
      } catch (e) {
        valueText = '无法解析金额';
      }
    }
    
    return AlertDialog(
      title: Text('确认交易'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('您确定要执行以下交易吗？'),
          SizedBox(height: 16),
          _buildInfoRow('发送方', from),
          _buildInfoRow('接收方', to),
          _buildInfoRow('金额', valueText),
          if (data != null && data!.isNotEmpty && data != '0x')
            _buildInfoRow('数据', '${data!.substring(0, math.min(10, data!.length))}...'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('确认'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}