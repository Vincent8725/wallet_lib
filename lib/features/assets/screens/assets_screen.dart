import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../../../core/services/wallet_service.dart';
import '../../../shared/widgets/balance_card.dart';
import '../../../core/config/chain_config.dart'; // 修正导入
import '../../wallet/screens/wallet_management_screen.dart';
import '../screens/send_transaction_screen.dart';
import '../screens/receive_screen.dart';
import '../screens/add_token_screen.dart';
import '../../../models/token.dart';
import '../../../models/wallet.dart'; // 添加钱包模型导入
import '../widgets/token_list.dart'; // 添加TokenList组件导入

class AssetsScreen extends StatefulWidget {
  @override
  _AssetsScreenState createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> with WidgetsBindingObserver {
  final WalletStorageService _storageService = WalletStorageService();
  final WalletService _walletService = WalletService();
  String _currentAddress = '';
  String _currentChainType = 'ETH';
  bool _isLoading = true;
  List<Token> _tokens = [];
  List<ChainConfig> _availableChains = []; // 修正为 ChainConfig 类型
  
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
      _availableChains = ChainConfigs.supportedChains; // 修正方法调用
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
      final tokens = await _walletService.getTokens(_currentAddress, _currentChainType);
      setState(() {
        _tokens = tokens;
      });
    } catch (e) {
      _showErrorSnackBar('加载代币失败: $e');
    }
  }
  
  Future<void> _switchChain(String chainType) async {
    if (_currentAddress.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 获取当前钱包
      final wallet = await _storageService.getWalletByAddress(_currentAddress);
      
      if (wallet != null) {
        // 切换链类型
        final updatedWallet = wallet.copyWithChainType(chainType);
        
        // 获取新链上的余额
        final balance = await _walletService.getBalance(
          updatedWallet.address,
          updatedWallet.chainType,
        );
        
        // 更新余额
        final walletWithBalance = updatedWallet.copyWithBalance(chainType, balance);
        
        // 保存更新后的钱包
        await _storageService.saveWallet(walletWithBalance);
        
        // 设置为当前钱包
        await _storageService.setCurrentWallet(walletWithBalance.address);
        
        setState(() {
          _currentChainType = chainType;
          _isLoading = false;
        });
        
        // 重新加载代币
        _loadTokens();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('切换链失败: $e');
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Widget _buildChainSelector() {
    if (_currentAddress.isEmpty) return SizedBox();
    
    final currentChain = ChainConfigs.getChainConfig(_currentChainType); // 修正方法调用
    
    return PopupMenuButton<String>(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentChain.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
      onSelected: _switchChain,
      itemBuilder: (context) {
        return _availableChains.map((chain) {
          return PopupMenuItem<String>(
            value: chain.symbol, // 使用 symbol 作为 chainType
            child: Row(
              children: [
                Text(chain.name),
                SizedBox(width: 8),
                if (chain.symbol == _currentChainType)
                  Icon(Icons.check, color: Theme.of(context).primaryColor),
              ],
            ),
          );
        }).toList();
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final currentChain = ChainConfigs.getChainConfig(_currentChainType); // 修正方法调用
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),

        actions: [
          // IconButton(
          //   icon: Icon(Icons.refresh),
          //   onPressed: _refreshWallet,
          //   tooltip: '刷新',
          // ),
          IconButton(
            icon: Icon(Icons.account_balance_wallet),
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
          ? Center(child: CircularProgressIndicator())
          : _currentAddress.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('暂无钱包'),
                      SizedBox(height: 16),
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
                        child: Text('创建钱包'),
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
                    
                    // 地址信息
                    // Padding(
                    //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    //   child: GestureDetector(
                    //     onTap: () {
                    //       Clipboard.setData(ClipboardData(text: _currentAddress));
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         SnackBar(content: Text('地址已复制到剪贴板')),
                    //       );
                    //     },
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.center,
                    //       children: [
                    //         Text(
                    //           _currentAddress.length > 20
                    //               ? '${_currentAddress.substring(0, 10)}...${_currentAddress.substring(_currentAddress.length - 10)}'
                    //               : _currentAddress,
                    //           style: TextStyle(
                    //             fontSize: 14,
                    //             color: Colors.grey[600],
                    //           ),
                    //         ),
                    //         SizedBox(width: 4),
                    //         Icon(
                    //           Icons.copy,
                    //           size: 14,
                    //           color: Colors.grey[600],
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    
                    // 转账和收款按钮
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.send),
                              label: Text('转账'),
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
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.qr_code),
                              label: Text('收款'),
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
                                padding: EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Token列表标题和添加按钮
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '代币列表',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline),
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
                          ? Center(
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