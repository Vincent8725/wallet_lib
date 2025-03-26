import 'package:flutter/material.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../widgets/balance_card.dart';
import '../../../core/config/chain_config.dart'; // 修正导入
import '../../wallet/screens/wallet_management_screen.dart';
import '../screens/send_transaction_screen.dart';
import '../screens/receive_screen.dart';
import '../screens/add_token_screen.dart';
import '../../../models/wallet.dart'; // 添加钱包模型导入
import '../widgets/token_list.dart'; // 添加TokenList组件导入

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  _AssetsScreenState createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> with WidgetsBindingObserver {
  final WalletStorageService _storageService = WalletStorageService();
  String _currentAddress = '';
  String _currentChainType = 'ETH';
  bool _isLoading = true;
// 修正为 ChainConfig 类型
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAvailableChains();
    _loadCurrentWallet();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCurrentWallet();
    }
  }

  void _loadAvailableChains() {
    setState(() {
// 修正方法调用
    });
  }

  Future<void> _refreshWallet() async {
    await _loadCurrentWallet();
  }
  
  Future<void> _loadCurrentWallet() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentWallet = await _storageService.getCurrentWallet();
      
      setState(() {
        _currentAddress = currentWallet?.address ?? '';
        _currentChainType = currentWallet?.chainType ?? 'ETH';
        _isLoading = false;
      });
      
      if (_currentAddress.isNotEmpty) {
        _loadTokens();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('加载钱包失败: $e');
    }
  }
  
  Future<void> _loadTokens() async {
    try {
      setState(() {
      });
    } catch (e) {
      _showErrorSnackBar('加载代币失败: $e');
    }
  }
  
  
  void _showErrorSnackBar(String message) {
    // 添加mounted检查，确保组件仍然挂载
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    ChainConfigs.getChainConfig(_currentChainType); // 修正方法调用
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () async {
              // 修改这里，接收钱包管理页面返回的结果
              final selectedWallet = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WalletManagementScreen()),
              );
              
              // 如果用户选择了钱包，则切换到该钱包
              if (selectedWallet != null && selectedWallet is Wallet) {
                // 设置为当前钱包
                await _storageService.setCurrentWallet(selectedWallet.address);
                // 刷新钱包
                await _refreshWallet();
              }
            },
            tooltip: '钱包管理',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentAddress.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('暂无钱包'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final selectedWallet = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WalletManagementScreen(),
                            ),
                          );
                          
                          // 如果用户选择了钱包，则切换到该钱包
                          if (selectedWallet != null && selectedWallet is Wallet) {
                            // 设置为当前钱包
                            await _storageService.setCurrentWallet(selectedWallet.address);
                            // 刷新钱包
                            await _refreshWallet();
                          }
                        },
                        child: const Text('创建钱包'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 余额卡片
                    BalanceCard(
                      useDarkStyle: true,
                      address: _currentAddress,
                      chainType: _currentChainType,
                    ),
                    
                    
                    // 转账和收款按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send,color: Colors.white,),
                              label: const Text('转账'),
                              // 修复 SendTransactionScreen 的参数名称
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SendTransactionScreen(
                                      address: _currentAddress, // 修改为 walletAddress
                                      chainType: _currentChainType,
                                    ),
                                  ),
                                ).then((_) => _refreshWallet());
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.lightBlue
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.qr_code, color: Colors.white),
                              label: const Text('收款'),
                              // 修复 ReceiveScreen 的参数名称
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReceiveScreen(
                                      address: _currentAddress, // 修改为 walletAddress
                                      chainType: _currentChainType,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Token列表标题和添加按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '代币列表',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddTokenScreen(
                                    address: _currentAddress,
                                    chainType: _currentChainType,
                                  ),
                                ),
                              );
                              if (result == true) {
                                // 刷新TokenList组件
                                setState(() {});
                              }
                            },
                            tooltip: '添加代币',
                          ),
                        ],
                      ),
                    ),
                    
                    // 使用TokenList组件替代原来的代币列表实现
                    Expanded(
                      child: _currentAddress.isEmpty
                          ? const Center(
                              child: Text('请先创建或导入钱包'),
                            )
                          : TokenList(
                              address: _currentAddress,
                              chainType: _currentChainType,
                            ),
                    ),
                  ],
                ),
    );
  }
}