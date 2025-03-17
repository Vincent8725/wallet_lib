import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/services/dapp_service.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../widgets/dapp_webview2.dart';
import '../widgets/transaction_confirmation_dialog.dart';

class DAppBrowserScreen extends StatefulWidget {
  final String initialUrl;

  const DAppBrowserScreen({
    Key? key,
    this.initialUrl = 'https://app.uniswap.org',
  }) : super(key: key);

  @override
  _DAppBrowserScreenState createState() => _DAppBrowserScreenState();
}

class _DAppBrowserScreenState extends State<DAppBrowserScreen> {
  final TextEditingController _urlController = TextEditingController();
  final DAppService _dappService = DAppService();
  final WalletStorageService _walletService = WalletStorageService();

  // 确保使用正确的类型
  final GlobalKey<DAppWebView2State> _webViewKey = GlobalKey<DAppWebView2State>();

  String _currentUrl = '';
  bool _isLoading = false;
  bool _isAuthorized = false;
  String _currentWalletAddress = '';
  bool _isWalletConnected = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;
    _currentUrl = widget.initialUrl;
    _loadCurrentWallet(); // 加载当前钱包
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
Future<bool> switchChainTo(String chainId) async {
  // 这里添加实际链切换逻辑，例如：
  // 1. 检查chainId是否在支持的链列表中
  // 2. 通知区块链节点切换链
  // 3. 更新UI状态
  // 示例返回：
  if (chainId == '0x1') {
    setState(() {
      // 更新当前链状态
    });
    return true;
  }
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
      _isLoading = true;
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
        _isLoading = false;
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
      _isLoading = true;
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
        _isLoading = false;
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

  void _onUrlChanged(String url) {
    setState(() {
      _currentUrl = url;
      _urlController.text = url;
    });
    _checkAuthorization();
  }

  void _navigateToUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _currentUrl = url;
      });
      _checkAuthorization();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _currentUrl.isNotEmpty ? Uri.parse(_currentUrl).host : 'DApp 浏览器'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(_isAuthorized ? Icons.lock_open : Icons.lock),
              onPressed: _toggleAuthorization,
              tooltip: _isAuthorized ? '撤销授权' : '授权DApp',
            ),
          // 添加连接钱包按钮
          IconButton(
            icon: Icon(_isWalletConnected ? Icons.link : Icons.link_off),
            onPressed: _connectWallet,
            tooltip: _isWalletConnected ? '已连接钱包' : '连接钱包',
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

          // 移除地址栏和前往按钮

          Expanded(
            child: DAppWebView2(
              key: _webViewKey, // 确保使用key
              url: _currentUrl,
              walletAddress: _currentWalletAddress,
              isWalletConnected: _isWalletConnected,
              onConnectRequest: (url) async {
                // 使用已有的连接钱包方法，而不是showConnectDialog
                return await _connectWallet();
              },
              onChainSwitch: (chainId) async {
                // 处理链切换逻辑
                return await switchChainTo(chainId);
              },
              onCustomRequest: (method, params) {
                // 处理其他请求
                print('Custom request: $method, params: $params');
              },
              onUrlChanged: _onUrlChanged, // 添加URL变更回调
            ),
          ),
        ],
      ),
    );
  }
}
