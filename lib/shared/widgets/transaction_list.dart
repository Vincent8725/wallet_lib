import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../core/services/wallet_service.dart';

class TransactionList extends StatefulWidget {
  final bool expanded;
  final String address;
  final String chainType; // 添加链类型属性
  
  const TransactionList({
    Key? key,
    this.expanded = false,
    required this.address,
    this.chainType = 'ETH', // 默认为ETH链
  }) : super(key: key);

  @override
  _TransactionListState createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  final WalletService _walletService = WalletService();
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }
  
  @override
  void didUpdateWidget(TransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) {
      _loadTransactions();
    }
  }
  
  Future<void> _loadTransactions() async {
    if (widget.address.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // 修改这里，添加链类型参数
      final transactions = await _walletService.getTransactions(widget.address, widget.chainType);
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载交易记录失败: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    Widget content;
    
    if (_isLoading) {
      content = Center(
        child: CircularProgressIndicator(),
      );
    } else if (_error != null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: Text('重试'),
            ),
          ],
        ),
      );
    } else if (_transactions.isEmpty) {
      content = Center(
        child: Text('暂无交易记录'),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView.builder(
          itemCount: _transactions.length,
          itemBuilder: (context, index) {
            final tx = _transactions[index];
            final isOutgoing = tx.isOutgoing(widget.address);
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isOutgoing ? Colors.red[100] : Colors.green[100],
                child: Icon(
                  isOutgoing ? Icons.call_made : Icons.call_received,
                  size: 16,
                  color: isOutgoing ? Colors.red : Colors.green,
                ),
              ),
              title: Text(
                isOutgoing ? '发送' : '接收',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isOutgoing ? '发送至: ${tx.to}' : '来自: ${tx.from}',
                style: TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isOutgoing ? "-" : "+"} ${tx.value.toStringAsFixed(4)} ETH',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOutgoing ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    tx.status,
                    style: TextStyle(
                      color: tx.status == '成功' ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              onTap: () {
                // 显示交易详情
                _showTransactionDetails(context, tx);
              },
            );
          },
        ),
      );
    }
    
    return widget.expanded ? Expanded(child: content) : content;
  }
  
  void _showTransactionDetails(BuildContext context, Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '交易详情',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailItem('交易哈希', tx.hash),
            _buildDetailItem('状态', tx.status),
            _buildDetailItem('时间', tx.formattedTime),
            _buildDetailItem('发送方', tx.from),
            _buildDetailItem('接收方', tx.to),
            _buildDetailItem('金额', '${tx.value} ETH'),
            _buildDetailItem('交易费用', '${tx.fee.toStringAsFixed(8)} ETH'),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // 在浏览器中查看交易
                  // TODO: 实现在浏览器中查看交易的功能
                },
                child: Text('在浏览器中查看'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}