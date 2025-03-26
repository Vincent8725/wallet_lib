import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/services/dapp_service.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../../../core/services/chain_service.dart'; // 添加链服务
import '../widgets/dapp_webview.dart';
import '../widgets/transaction_confirmation_dialog.dart';

class DAppBrowserScreen extends StatefulWidget {
  final String initialUrl;
  final String name;
  final String? chainId; // 添加chainId参数

  const DAppBrowserScreen({
    Key? key,
    this.initialUrl = 'https://app.uniswap.org',
    this.name = 'Uniswap',
    this.chainId, // 接收chainId参数
  }) : super(key: key);

  @override
  _DAppBrowserScreenState createState() => _DAppBrowserScreenState();
}

class _DAppBrowserScreenState extends State<DAppBrowserScreen> {
  final TextEditingController _urlController = TextEditingController();
  final DAppService _dappService = DAppService();
  final WalletStorageService _walletService = WalletStorageService();

  // 确保使用正确的类型
  final GlobalKey<DAppWebViewState> _webViewKey = GlobalKey<DAppWebViewState>();

  String _currentUrl = '';
  String _currentName = '';
  bool _isAuthorized = false;
  String _currentWalletAddress = '';
  bool _isWalletConnected = false;
  String _currentChainId = ''; // 默认以太坊链ID

  // 添加收藏状态
  bool _isFavorite = false;
  
  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;
    _currentUrl = widget.initialUrl;
    _currentName = widget.name;
    // 如果传入了chainId，设置当前链ID
    if (widget.chainId != null && widget.chainId!.isNotEmpty) {
      dev.log('Received chainId: ${widget.chainId}', name: 'DAppBrowserScreen');
      _currentChainId = widget.chainId!;
    } else {

      // 否则尝试从ChainService获取当前链ID
      _loadCurrentChainId();

      dev.log('Load current chainId: $_currentChainId', name: 'DAppBrowserScreen');
    }
    
    _loadCurrentWallet(); // 加载当前钱包
    _checkFavoriteStatus(); // 检查收藏状态
  }
  
  // 检查当前DApp是否已收藏
  Future<void> _checkFavoriteStatus() async {
    try {
      final isFavorite = await _dappService.isFavoriteDApp(_currentUrl);
      setState(() {
        _isFavorite = isFavorite;
      });
    } catch (e) {
      print('检查收藏状态失败: $e');
    }
  }
  
  // 切换收藏状态
  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        // 取消收藏
        await _dappService.removeFavoriteDApp(_currentUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从收藏中移除')),
        );
      } else {
        // 添加收藏
        final host = Uri.parse(_currentUrl).host;
        final dappName = host.replaceAll('www.', '');
        
        await _dappService.addFavoriteDApp(
          _currentUrl, 
          dappName,
          _currentChainId,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到收藏')),
        );
      }
      
      // 更新收藏状态
      await _checkFavoriteStatus();
    } catch (e) {
      print('切换收藏状态失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }
  
  void _onUrlChanged(String url) {
    setState(() {
      _currentUrl = url;
      _urlController.text = url;
    });
    _checkAuthorization();
    _checkFavoriteStatus(); // 当URL变化时检查收藏状态
  }
  
  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // 加载当前链ID
  Future<void> _loadCurrentChainId() async {
    try {
      final chainName = await ChainService.getCurrentChain();
      final chainId = ChainService.getChainIdByName(chainName);
      setState(() {
        _currentChainId = chainId;
      });
    } catch (e) {
      print('加载当前链ID失败: $e');
    }
  }

  // 加载当前钱包
  Future<void> _loadCurrentWallet() async {
    try {
      final wallet = await _walletService.getCurrentWallet();
      if (wallet != null) {
        setState(() {
          _currentWalletAddress = wallet.address;
        });
        _checkAuthorization();
        // 自动尝试连接钱包
        _connectWallet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先创建或导入钱包')),
        );
      }
    } catch (e) {
      print('加载钱包失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载钱包失败: $e')),
      );
    }
  }


  // 添加showConnectDialog方法
Future<bool> showConnectDialog() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('连接请求'),
      content: const Text("是否允许DApp连接钱包？"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("允许")),
      ],
    ),
  );
  return confirmed ?? false;
}

// 添加switchChainTo方法
// 修改switchChainTo方法，更新当前链
  Future<bool> switchChainTo(String chainId) async {
    // 检查chainId是否在支持的链列表中
    if (chainId == '0x1' || chainId == '0x38') { // 以太坊和BSC
      setState(() {
        _currentChainId = chainId;
      });
      
      // 更新ChainService中的当前链
      final chainName = ChainService.getChainNameByChainId(chainId);
      await ChainService.setCurrentChain(chainName);
      
      // 通知用户链已切换
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到 ${chainName.toUpperCase()} 链')),
      );
      
      // 刷新WebView以应用新的链设置
      _webViewKey.currentState?.reload();
      
      return true;
    }
    
    // 不支持的链
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('不支持的链ID: $chainId')),
    );
    return false;
  }



  // 添加连接钱包方法
  Future<bool> _connectWallet() async {
    if (_currentWalletAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建或导入钱包')),
      );
      return false;
    }

    // 如果已连接，直接返回true
    if (_isWalletConnected) {
      return true;
    }

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('连接请求'),
            content: Text(
                'DApp "${Uri.parse(_currentUrl).host}" 请求连接您的钱包。\n\n地址: $_currentWalletAddress'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('拒绝'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('连接'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      setState(() {
        _isWalletConnected = true;
      });

      // 刷新WebView以应用新的连接状态
      _webViewKey.currentState?.reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('钱包已连接')),
      );
    }

    return confirmed;
  }

  Future<void> _checkAuthorization() async {
    if (_currentWalletAddress.isEmpty) return;

    setState(() {
    });

    try {
      final isAuthorized = await _dappService.isDAppAuthorized(_currentUrl);
      setState(() {
        _isAuthorized = isAuthorized;
      });
    } catch (e) {
      print('检查授权状态失败: $e');
    } finally {
      setState(() {
      });
    }
  }

  Future<void> _toggleAuthorization() async {
    if (_currentWalletAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建或导入钱包')),
      );
      return;
    }

    setState(() {
    });

    try {
      if (_isAuthorized) {
        // 撤销授权
        await _dappService.revokeAuthorization(_currentUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已撤销DApp授权')),
        );
      } else {
        // 授权DApp，使用当前钱包地址
        final success =
            await _dappService.authorize(_currentUrl, _currentWalletAddress);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DApp授权成功')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DApp授权失败')),
          );
        }
      }

      await _checkAuthorization();
    } catch (e) {
      print('切换授权状态失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    } finally {
      setState(() {
      });
    }
  }

  // 处理DApp交互请求
  Future<dynamic> _handleDAppInteraction(
      String method, Map<String, dynamic> params) async {
    if (!_isAuthorized) {
      throw Exception('DApp未授权');
    }

    // 获取当前钱包的私钥
    final wallet =
        await _walletService.getWalletByAddress(_currentWalletAddress);
    if (wallet == null) {
      throw Exception('找不到当前钱包');
    }

    // 对于发送交易请求，显示确认对话框
    if (method == 'eth_sendTransaction') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => TransactionConfirmationDialog(
          from: params['from'],
          to: params['to'],
          value: params['value'],
          data: params['data'],
        ),
      );

      if (confirmed != true) {
        throw Exception('用户取消交易');
      }
    }

    // 执行交互
    return await _dappService.interact(
        _currentUrl, method, params, wallet.privateKey);
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _currentName.isNotEmpty ? _currentName : 'DApp 浏览器',style: TextStyle(fontSize: 18)),
        actions: [
          // 添加当前链显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _currentChainId == '0x1' ? Colors.blue : Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentChainId == '0x1' ? 'ETH' : 'BSC',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          
          // 添加收藏按钮
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? '取消收藏' : '收藏DApp',
          ),
          
          // 修改刷新按钮实现
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 使用 try-catch 包装可能出错的代码
              try {
                _webViewKey.currentState?.reload();
              } catch (e) {
                print('刷新页面失败: $e');
                // 可以尝试替代方案
                setState(() {
                  // 重新加载当前URL
                  _currentUrl = _currentUrl;
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前钱包信息
          if (_currentWalletAddress.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '当前钱包: ${_currentWalletAddress.substring(0, 6)}...${_currentWalletAddress.substring(_currentWalletAddress.length - 4)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // 添加钱包连接状态指示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isWalletConnected ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isWalletConnected ? '已连接' : '未连接',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: DAppWebView(
              key: _webViewKey, // 确保使用key
              url: _currentUrl,
              walletAddress: _currentWalletAddress,
              isWalletConnected: _isWalletConnected,
              chainId: _currentChainId, // 传递当前链ID
              onConnectRequest: (url) async {
                return await _connectWallet();
              },
              onChainSwitch: (chainId) async {
                return await switchChainTo(chainId);
              },
              onCustomRequest: (method, params) {
                print('Custom request: $method, params: $params');
              },
              onUrlChanged: _onUrlChanged,
            ),
          ),
        ],
      ),
    );
  }
}
