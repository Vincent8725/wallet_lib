import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../../../core/services/wallet_service.dart';
import '../../../models/wallet.dart';
import '../../../core/config/chain_config.dart'; // 添加导入
import 'create_wallet_screen.dart';

class WalletManagementScreen extends StatefulWidget {
  @override
  _WalletManagementScreenState createState() => _WalletManagementScreenState();
}

// 添加SingleTickerProviderStateMixin以支持TabController
class _WalletManagementScreenState extends State<WalletManagementScreen> with SingleTickerProviderStateMixin {
  final WalletStorageService _storageService = WalletStorageService();
  final WalletService _walletService = WalletService(); // 添加WalletService
  List<Wallet> _wallets = [];
  String? _currentWalletAddress;
  bool _isLoading = true;
  late TabController _tabController; // 添加TabController
  List<ChainConfig> _supportedChains = []; // 添加支持的链列表

  @override
  void initState() {
    super.initState();
    _supportedChains = ChainConfigs.supportedChains; // 获取支持的链
    _tabController = TabController(length: _supportedChains.length, vsync: this); // 初始化TabController
    _loadWallets().then((_) {
      // 加载钱包后，自动切换到当前钱包的链
      _switchToCurrentWalletChain();
    });
  }
  
  // 添加切换到当前钱包链的方法
  void _switchToCurrentWalletChain() {
    if (_currentWalletAddress != null) {
      // 查找当前钱包
      final currentWallet = _wallets.firstWhere(
        (wallet) => wallet.address == _currentWalletAddress,
        orElse: () => _wallets.first,
      );
      
      // 查找当前钱包的链在支持链列表中的索引
      final chainIndex = _supportedChains.indexWhere(
        (chain) => chain.id == currentWallet.chainType
      );
      
      // 如果找到了对应的链，切换到该链
      if (chainIndex >= 0) {
        setState(() {
          _tabController.animateTo(chainIndex);
        });
      }
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose(); // 释放TabController
    super.dispose();
  }

  Future<void> _loadWallets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final wallets = await _storageService.getWallets();
      final currentWallet = await _storageService.getCurrentWallet();

      setState(() {
        _wallets = wallets;
        _currentWalletAddress = currentWallet?.address;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('加载钱包失败: $e');
    }
  }

  // 在_setCurrentWallet方法中添加返回成功标志
  Future<void> _setCurrentWallet(String address) async {
    try {
      await _storageService.setCurrentWallet(address);
      setState(() {
        _currentWalletAddress = address;
      });
      _showSuccessSnackBar('已切换到选中钱包');
      
      // 不应该在这里调用Navigator.pop，因为这会导致页面关闭
      // 只有在从其他页面调用时才需要返回
    } catch (e) {
      _showErrorSnackBar('切换钱包失败: $e');
    }
  }

  Future<void> _deleteWallet(Wallet wallet) async {
    final confirmed = await _showConfirmDialog(
      '删除钱包',
      '确定要删除钱包 ${wallet.shortAddress} 吗？此操作不可撤销，请确保您已备份助记词或私钥。',
    );

    if (confirmed != true) return;

    try {
      final success = await _storageService.deleteWallet(wallet.address);
      if (success) {
        await _loadWallets();
        _showSuccessSnackBar('钱包已删除');
      } else {
        _showErrorSnackBar('删除钱包失败');
      }
    } catch (e) {
      _showErrorSnackBar('删除钱包失败: $e');
    }
  }

  Future<void> _exportMnemonic(Wallet wallet) async {
    if (wallet.mnemonic.isEmpty) {
      _showErrorSnackBar('该钱包没有助记词');
      return;
    }

    final confirmed = await _showConfirmDialog(
      '导出助记词',
      '警告：助记词是恢复钱包的唯一凭证，请勿泄露给他人！',
    );

    if (confirmed != true) return;

    _showExportDialog('钱包助记词', wallet.mnemonic);
  }

  Future<void> _exportPrivateKey(Wallet wallet) async {
    final confirmed = await _showConfirmDialog(
      '导出私钥',
      '警告：私钥是控制钱包资产的唯一凭证，请勿泄露给他人！',
    );

    if (confirmed != true) return;

    _showExportDialog('钱包私钥', wallet.privateKey);
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确认'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                content,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '请妥善保管，不要泄露给他人！',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
              Navigator.pop(context);
            },
            child: Text('复制'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // 添加更新钱包余额的方法
  Future<void> _updateWalletBalances() async {
    if (_wallets.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      List<Wallet> updatedWallets = [];
      
      for (var wallet in _wallets) {
        // 获取ETH余额
        final ethBalance = await _walletService.getBalance(wallet.address, 'ETH');
        // 获取BSC余额
        final bscBalance = await _walletService.getBalance(wallet.address, 'BSC');
        
        // 更新钱包余额
        final updatedWallet = wallet.copyWithBalance('ETH', ethBalance)
                                   .copyWithBalance('BSC', bscBalance);
        
        // 保存更新后的钱包
        await _storageService.saveWallet(updatedWallet);
        
        updatedWallets.add(updatedWallet);
      }
      
      setState(() {
        _wallets = updatedWallets;
        _isLoading = false;
      });
      
      _showSuccessSnackBar('余额已更新');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('更新余额失败: $e');
    }
  }

  // 修改切换链类型的方法
  Future<void> _switchChainType(Wallet wallet, String newChainType) async {
    try {
      // 使用copyWithName方法保留钱包名称
      final updatedWallet = wallet.copyWithChainType(newChainType);
      
      // 保存更新后的钱包
      await _storageService.saveWallet(updatedWallet);
      
      // 设置为当前钱包
      await _storageService.setCurrentWallet(updatedWallet.address);
      
      // 重新加载钱包列表
      await _loadWallets();
      
      _showSuccessSnackBar('已切换到 $newChainType 链');
      
      // 不应该在这里调用Navigator.pop，因为这会导致页面关闭
    } catch (e) {
      _showErrorSnackBar('切换链类型失败: $e');
    }
  }

  // 添加更新当前钱包链类型的方法
  Future<void> _updateCurrentWalletChain(String chainSymbol) async {
    // 如果没有当前钱包，则不执行任何操作
    if (_currentWalletAddress == null || _wallets.isEmpty) return;

    try {
      // 查找当前钱包
      final currentWallet = _wallets.firstWhere(
        (wallet) => wallet.address == _currentWalletAddress,
        orElse: () => _wallets.first,
      );

      // 如果当前钱包的链类型已经是目标链类型，则不需要更新
      if (currentWallet.chainType == chainSymbol) return;

      // 更新当前钱包的链类型
      final updatedWallet = currentWallet.copyWithChainType(chainSymbol);

      // 保存更新后的钱包
      await _storageService.saveWallet(updatedWallet);
      
      // 设置为当前钱包
      await _storageService.setCurrentWallet(updatedWallet.address);

      // 重新加载钱包列表以更新UI
      await _loadWallets();

      _showSuccessSnackBar('已切换到 $chainSymbol 链');
    } catch (e) {
      _showErrorSnackBar('切换链类型失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 获取当前钱包并返回
        if (_currentWalletAddress != null) {
          // 重新从存储中获取最新的钱包信息
          final currentWallet = await _storageService.getWalletByAddress(_currentWalletAddress!);
          if (currentWallet != null) {
            // 返回更新后的钱包
            Navigator.pop(context, currentWallet);
            return false; // 不执行默认返回操作
          }
        }
        // 如果没有当前钱包，则返回true
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('钱包管理'),
          actions: [
            // 添加刷新余额按钮
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _updateWalletBalances,
              tooltip: '更新余额',
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateWalletScreen()),
                );
                if (result != null) {
                  await _loadWallets();
                }
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _wallets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('暂无钱包'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateWalletScreen(),
                              ),
                            );
                            if (result != null) {
                              await _loadWallets();
                            }
                          },
                          child: const Text('创建钱包'),
                        ),
                      ],
                    ),
                  )
                // 使用 Row 替换 TabBarView，左侧放置标签列表，右侧显示钱包列表
                : Row(
                    children: [
                    // 左侧标签列表
                    Container(
                      width: 80, // 设置左侧标签栏宽度
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: _supportedChains.length,
                        itemBuilder: (context, index) {
                          final chain = _supportedChains[index];
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _tabController.index = index;
                              });
                              
                              // 添加这行代码，当选中左侧链标签时，更新当前钱包的链类型
                              _updateCurrentWalletChain(chain.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _tabController.index == index
                                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: _tabController.index == index
                                        ? Theme.of(context).primaryColor
                                        : Colors.transparent,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  chain.id,
                                  style: TextStyle(
                                    color: _tabController.index == index
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[700],
                                    fontWeight: _tabController.index == index
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 右侧钱包列表，使用 Expanded 填充剩余空间
                    Expanded(
                      child: IndexedStack(
                        index: _tabController.index,
                        children: _supportedChains.map((chain) => 
                          _buildWalletList(chain.id)
                        ).toList(),
                      ),
                    ),
                  ],
                ),
      )
    );
  }

  // 修复钱包列表构建方法
  Widget _buildWalletList(String chainType) {
    return ListView.builder(
      itemCount: _wallets.length,
      itemBuilder: (context, index) {
        final wallet = _wallets[index];
        final isCurrentWallet = wallet.address == _currentWalletAddress;
        // 使用getBalance方法获取余额，如果不存在则返回0
        final chainBalance = wallet.balances[chainType] ?? 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: isCurrentWallet ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isCurrentWallet
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            title: Text(
              // 使用钱包名称，如果没有则显示地址
              wallet.name.isNotEmpty ? wallet.name : '${wallet.address.substring(0, 10)}...',
              style: TextStyle(
                fontWeight: isCurrentWallet ? FontWeight.bold : null,
                color: isCurrentWallet ? Theme.of(context).primaryColor : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${chainType == 'ETH' ? 'ETH' : 'BNB'}: ${chainBalance.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: isCurrentWallet ? Theme.of(context).primaryColor.withOpacity(0.7) : null,
                  ),
                ),
                Text(
                  '地址: ${wallet.address.substring(0, 8)}...${wallet.address.substring(wallet.address.length - 6)}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'set_current':
                    _setCurrentWallet(wallet.address);
                    break;
                  case 'switch_to_eth':
                    _switchChainType(wallet, 'ETH');
                    break;
                  case 'switch_to_bsc':
                    _switchChainType(wallet, 'BSC');
                    break;
                  case 'export_mnemonic':
                    _exportMnemonic(wallet);
                    break;
                  case 'export_private_key':
                    _exportPrivateKey(wallet);
                    break;
                  case 'delete':
                    _deleteWallet(wallet);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!isCurrentWallet)
                  const PopupMenuItem(
                    value: 'set_current',
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 18),
                        SizedBox(width: 8),
                        Text('设为当前钱包'),
                      ],
                    ),
                  ),
                // 添加切换到ETH链选项
                if (wallet.chainType != 'ETH')
                  const PopupMenuItem(
                    value: 'switch_to_eth',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 18),
                        SizedBox(width: 8),
                        Text('切换到ETH链'),
                      ],
                    ),
                  ),
                // 添加切换到BSC链选项
                if (wallet.chainType != 'BSC')
                  const PopupMenuItem(
                    value: 'switch_to_bsc',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 18),
                        SizedBox(width: 8),
                        Text('切换到BSC链'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'export_mnemonic',
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key, size: 18),
                      SizedBox(width: 8),
                      Text('导出助记词'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_private_key',
                  child: Row(
                    children: [
                      Icon(Icons.key, size: 18),
                      SizedBox(width: 8),
                      Text('导出私钥'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除钱包', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              if (!isCurrentWallet) {
                _setCurrentWallet(wallet.address);
              }
            },
          ),
        );
      },
    );
  }
  
  // 构建钱包列表项
  // 删除这两个方法
  // Widget _buildWalletItem(Wallet wallet) { ... }
  // Future<void> _selectWallet(String address) async { ... }
  
  // 选择钱包
  Future<void> _selectWallet(String address) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _storageService.setCurrentWallet(address);
      
      setState(() {
        _currentWalletAddress = address;
        _isLoading = false;
      });
      
      // 返回上一页，并传递结果
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择钱包失败: $e')),
      );
    }
  }
}