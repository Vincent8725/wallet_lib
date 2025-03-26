import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/config/chain_config.dart';
import '../../wallet/widgets/transaction_list.dart';

class ReceiveScreen extends StatefulWidget {
  final String address;
  final String chainType;
  
  const ReceiveScreen({
    Key? key,
    required this.address,
    required this.chainType,
  }) : super(key: key);

  @override
  _ReceiveScreenState createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final chainConfig = ChainConfigs.getChainConfig(widget.chainType);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('收款'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '收款码'),
            Tab(text: '交易记录'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 收款码标签页
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            '${chainConfig.name}收款地址',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 24),
                          QrImageView(
                            data: widget.address,
                            version: QrVersions.auto,
                            size: 200.0,
                            backgroundColor: Colors.white,
                          ),
                          SizedBox(height: 24),
                          Text(
                            widget.address,
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: Icon(Icons.copy),
                            label: Text('复制地址'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.address));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('地址已复制到剪贴板')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '注意事项',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• 请确保发送的是${chainConfig.name}网络的资产\n'
                            '• 发送其他网络的资产可能会导致资产丢失\n'
                            '• 转账完成后需要区块确认，可能需要等待几分钟',
                            style: TextStyle(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 交易记录标签页
          TransactionList(
            expanded: true,
            address: widget.address,
            chainType: widget.chainType,
          ),
        ],
      ),
    );
  }
}