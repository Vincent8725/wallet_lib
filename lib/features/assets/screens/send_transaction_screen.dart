import 'package:flutter/material.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../../../core/config/chain_config.dart';
import '../../../shared/widgets/transaction_list.dart';

class SendTransactionScreen extends StatefulWidget {
  final String address;
  final String chainType;
  
  const SendTransactionScreen({
    Key? key,
    required this.address,
    required this.chainType,
  }) : super(key: key);

  @override
  _SendTransactionScreenState createState() => _SendTransactionScreenState();
}

class _SendTransactionScreenState extends State<SendTransactionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _toAddressController = TextEditingController();
  final _amountController = TextEditingController();
  
  final WalletService _walletService = WalletService();
  final WalletStorageService _storageService = WalletStorageService();
  
  bool _isLoading = false;
  String? _errorMessage;
  double _balance = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadBalance();
  }
  
  @override
  void dispose() {
    _toAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _loadBalance() async {
    try {
      final balance = await _walletService.getBalance(widget.address, widget.chainType);
      setState(() {
        _balance = balance;
      });
    } catch (e) {
      print('加载余额失败: $e');
    }
  }
  
  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 获取当前钱包
      final wallet = await _storageService.getWalletByAddress(widget.address);
      if (wallet == null) {
        throw Exception('找不到钱包');
      }
      
      // 发送交易
      final txHash = await _walletService.sendTransaction(
        privateKey: wallet.privateKey,
        toAddress: _toAddressController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        chainType: widget.chainType,
      );
      
      // 显示成功消息并返回
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('交易已提交，哈希: $txHash'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 清空表单
      _toAddressController.clear();
      _amountController.clear();
      
      // 重新加载余额
      await _loadBalance();
      
      // 切换到交易记录标签
      _tabController.animateTo(1);
    } catch (e) {
      setState(() {
        _errorMessage = '发送交易失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  late TabController _tabController;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  Widget build(BuildContext context) {
    final chainConfig = ChainConfigs.getChainConfig(widget.chainType);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('转账'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '发送'),
            Tab(text: '交易记录'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 发送标签页
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 余额信息
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '可用余额',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$_balance ${chainConfig.symbol}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 收款地址
                  TextFormField(
                    controller: _toAddressController,
                    decoration: InputDecoration(
                      labelText: '收款地址',
                      hintText: '输入有效的${chainConfig.name}地址',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入收款地址';
                      }
                      if (!value.startsWith('0x') || value.length != 42) {
                        return '请输入有效的${chainConfig.name}地址';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 转账金额
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '转账金额',
                      hintText: '输入转账金额',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: chainConfig.symbol,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入转账金额';
                      }
                      try {
                        final amount = double.parse(value);
                        if (amount <= 0) {
                          return '金额必须大于0';
                        }
                        if (amount > _balance) {
                          return '余额不足';
                        }
                      } catch (e) {
                        return '请输入有效的金额';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  if (_errorMessage != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendTransaction,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : Text('确认转账'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
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