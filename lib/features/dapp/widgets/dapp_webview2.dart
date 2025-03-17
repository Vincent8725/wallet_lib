import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

class DAppWebView2 extends StatefulWidget {
  final String url;
  final String walletAddress;
  final bool isWalletConnected;
  final Future<bool> Function(String url) onConnectRequest;
  final Future<bool> Function(String chainId) onChainSwitch;
  final void Function(String method, dynamic params) onCustomRequest;
  final Function(String)? onUrlChanged; // 添加URL变更回调

  const DAppWebView2({
    Key? key,
    required this.url,
    required this.walletAddress,
    required this.isWalletConnected,
    required this.onConnectRequest,
    required this.onChainSwitch,
    required this.onCustomRequest,
    this.onUrlChanged,
  }) : super(key: key);

  @override
  DAppWebView2State createState() => DAppWebView2State();
}

class DAppWebView2State extends State<DAppWebView2> {
  // 移除late关键字，使用可空类型
  WebViewController? _controller;
  String _jsScript = '';
  bool _isLoading = true;
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // 异步初始化方法
  Future<void> _initialize() async {
    try {
      // 加载JS脚本
      await _loadJS();
      // 初始化WebView控制器
      _initWebViewController();

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e) {
      print('初始化DAppWebView2失败: $e');
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    }
  }

  Future<void> _loadJS() async {
    try {
      _jsScript =
          await rootBundle.loadString('assets/scripts/dapp/dapp_inject.js');
      print('JS脚本加载成功，长度: ${_jsScript.length}');
    } catch (e) {
      print('加载JS脚本失败: $e');
      throw Exception('无法加载DApp注入脚本: $e');
    }
  }

  void reload() {
    _controller?.reload();
  }

  void _initWebViewController() {
    final controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
            print('页面开始加载: $url');
          },
          onPageFinished: (url) async {
            print('页面加载完成: $url');

            if (widget.onUrlChanged != null) {
              widget.onUrlChanged!(url);
            }

            // 注入JS脚本
            await _injectJS(controller);

            // 更新链和账户信息
            await _updateChainAndAccount(controller);

            setState(() {
              _isLoading = false;
            });
          },
          onUrlChange: (change) {
            if (widget.onUrlChanged != null && change.url != null) {
              widget.onUrlChanged!(change.url!);
            }
          },
          onWebResourceError: (error) {
            print('WebView错误: ${error.description}');
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel('Logger', onMessageReceived: (message) async {
        print('收到JS日志消息: ${message.message}');
      })
      ..addJavaScriptChannel(
        'FlutterWeb3',
        onMessageReceived: (message) async {
          print('收到JS消息: ${message.message}');

          try {
            final request = jsonDecode(message.message);
            final method = request['method'];
            final params = request['params'];
            final requestId = request['id'];
            final chainId = request['chainId'];

            switch (method) {
              case 'eth_requestAccounts':
                await _handleAccountRequest(controller, requestId);
                break;
              case 'wallet_switchEthereumChain':
                await _handleChainSwitch(
                    controller, requestId, params?[0]['chainId']);
                break;
              default:
                widget.onCustomRequest(method, params);
            }
          } catch (e) {
            print('处理JS消息失败: $e');
            // 向JS返回错误
            controller.runJavaScript('''
              console.error('处理请求失败: $e');
              if (window.dappController && window.dappController.triggerEvent) {
                window.dappController.triggerEvent('requestError', {
                  error: '$e'
                });
              }
            ''');
          }
        },
      );

    // 加载URL
    controller.loadRequest(Uri.parse(widget.url));

    // 设置控制器
    setState(() {
      _controller = controller;
      _isInitialized = true;
    });
  }

  // 注入JS脚本
  Future<void> _injectJS(WebViewController controller) async {
    try {
      // 检查脚本是否已加载
      if (_jsScript.isEmpty) {
        print('JS脚本为空，尝试重新加载');
        await _loadJS();
      }

      // 直接注入脚本
      await controller.runJavaScript(_jsScript);
      print('JS脚本注入成功');

      // 验证注入结果
      final result = await controller
          .runJavaScriptReturningResult(
              "typeof window.dappController === 'object' ? 'success' : 'failed'")
          .catchError((e) {
        print('验证脚本注入失败: $e');
        return 'failed';
      });

      if (result.toString() == 'success') {
        print('JS脚本验证通过');

        // 验证FlutterWeb3通道
        final channelResult = await controller
            .runJavaScriptReturningResult(
                "typeof window.FlutterWeb3 === 'object' ? 'channel_ok' : 'channel_missing'")
            .catchError((e) => 'channel_error');

        print('FlutterWeb3通道状态: $channelResult');

        // 测试通道通信
        if (channelResult.toString() == 'channel_ok') {
          await controller.runJavaScript('''
            console.log('测试FlutterWeb3通道');
            try {
              window.FlutterWeb3.postMessage(JSON.stringify({
                id: "test_channel",
                method: "test_connection",
                params: ["测试通道连接"]
              }));
              console.log('测试消息已发送');
            } catch(e) {
              console.error('测试通道失败:', e);
            }
          ''');
        }
      } else {
        print('JS脚本验证失败: $result');
        // 输出控制台错误信息以便调试
        await controller
            .runJavaScript("console.log('验证失败，dappController未正确初始化');");
      }
    } catch (e) {
      print('注入JS脚本失败: $e');
    }
  }

  // 更新链和账户信息
  Future<void> _updateChainAndAccount(WebViewController controller) async {
    try {
      const chainData = {
        'chainId': '0x1',
        'chainName': 'Ethereum Mainnet',
        'rpcUrl': 'https://mainnet.infura.io/v3/your-project-id',
        'blockExplorerUrl': 'https://etherscan.io'
      };

      // 设置链信息
      await controller.runJavaScript(
          'if (window.dappController) { window.dappController.setChain(${jsonEncode(chainData)}); }');

      // 如果有钱包地址，设置账户
      if (widget.walletAddress.isNotEmpty) {
        await controller.runJavaScript(
            'if (window.dappController) { window.dappController.setAccount("${widget.walletAddress}"); }');

        // 如果已连接，触发连接事件
        if (widget.isWalletConnected) {
          print('钱包已连接，触发连接事件');
          // await controller.runJavaScript('''
          //   if (window.ethereum && window.ethereum.triggerEvent) {
          //     window.ethereum.triggerEvent('accountsChanged', ["${widget.walletAddress}"]);
          //     window.ethereum.triggerEvent('connect', { chainId: "${chainData['chainId']}" });
          //     console.log('触发钱包连接事件');
          //   }
          // ''');
          // await controller.runJavaScript('''
          //     if (window.ethereum.triggerEvent) {
          //       window.ethereum.triggerEvent('accountsChanged', ["${widget.walletAddress}"]);
          //       window.ethereum.triggerEvent('connect', { chainId: "${chainData['chainId']}" });
          //     }
          // ''');
          // 主动调用一次eth_requestAccounts并处理结果
          await controller.runJavaScript('''
            console.log('主动调用eth_requestAccounts');
            if (window.ethereum && window.ethereum.request) {
              window.ethereum.request({ method: 'eth_requestAccounts' })
                .then(function(accounts) {
                  console.log('eth_requestAccounts成功:', accounts);
                })
                .catch(function(error) {
                  console.error('eth_requestAccounts失败:', error);
                });
            }
          ''');
        }

        print('更新链和账户信息完成: ${widget.walletAddress}');
      }
    } catch (e) {
      print('更新链和账户信息失败: $e');
    }
  }

  // 处理账户请求
  Future<void> _handleAccountRequest(
      WebViewController controller, String requestId) async {
    try {
      final connected = await widget.onConnectRequest(widget.url);
      if (connected) {
        // 返回账户地址
        await controller.runJavaScript('''
          if (window.resolveWeb3Request) {
            window.resolveWeb3Request('$requestId', '["${widget.walletAddress}"]');
          }
          if (window.ethereum && window.ethereum.triggerEvent) {
            window.ethereum.triggerEvent('accountsChanged', ["${widget.walletAddress}"]);
            window.ethereum.triggerEvent('connect', { chainId: window.ethereum.chainId });
            console.log('钱包连接成功: ${widget.walletAddress}');
          }
        ''');
      } else {
        await controller.runJavaScript(
            'if (window.rejectWeb3Request) { window.rejectWeb3Request("$requestId", "用户拒绝连接"); }');
      }
    } catch (e) {
      print('处理账户请求失败: $e');
      await controller.runJavaScript(
          'if (window.rejectWeb3Request) { window.rejectWeb3Request("$requestId", "处理请求失败: $e"); }');
    }
  }

  // 处理链切换
  Future<void> _handleChainSwitch(WebViewController controller,
      String requestId, String? targetChainId) async {
    if (targetChainId == null) return;

    try {
      final success = await widget.onChainSwitch(targetChainId);
      if (success) {
        // 更新当前链信息
        await controller.runJavaScript('''
          if (window.resolveWeb3Request) {
            window.resolveWeb3Request('$requestId', 'null');
          }
          if (window.dappController) {
            window.dappController.setChain({
              chainId: '$targetChainId',
              chainName: 'New Chain',
              rpcUrl: 'https://new-chain.rpc',
              blockExplorerUrl: 'https://new-chain.explorer'
            });
          }
        ''');
      } else {
        await controller.runJavaScript(
            'if (window.rejectWeb3Request) { window.rejectWeb3Request("$requestId", "切换链失败"); }');
      }
    } catch (e) {
      print('处理链切换请求失败: $e');
      await controller.runJavaScript(
          'if (window.rejectWeb3Request) { window.rejectWeb3Request("$requestId", "处理请求失败: $e"); }');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果控制器未初始化，显示加载指示器
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 构建WebView
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  // 更新当前钱包地址（如切换账户）
  Future<void> updateAccount(String newAddress) async {
    if (_controller == null) return;

    try {
      await _controller!.runJavaScript('''
        if (window.dappController) {
          window.dappController.setAccount('$newAddress');
          console.log('更新钱包地址: $newAddress');
        }
      ''');
    } catch (e) {
      print('更新账户失败: $e');
    }
  }

  // 切换链（外部调用）
  Future<void> switchChain(String chainId) async {
    if (_controller == null) return;

    try {
      await _controller!.runJavaScript('''
        if (window.ethereum && window.ethereum.switchChain) {
          window.ethereum.switchChain('$chainId');
          console.log('切换链: $chainId');
        }
      ''');
    } catch (e) {
      print('切换链失败: $e');
    }
  }
}
