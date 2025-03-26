import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

class DAppWebView extends StatefulWidget {
  final String url;
  final String walletAddress;
  final String chainId;
  final bool isWalletConnected;
  final Future<bool> Function(String url) onConnectRequest;
  final Future<bool> Function(String chainId) onChainSwitch;
  final void Function(String method, dynamic params) onCustomRequest;
  final Function(String)? onUrlChanged; // 添加URL变更回调

  const DAppWebView({
    Key? key,
    required this.url,
    required this.walletAddress,
    required this.chainId,
    required this.isWalletConnected,
    required this.onConnectRequest,
    required this.onChainSwitch,
    required this.onCustomRequest,
    this.onUrlChanged,
  }) : super(key: key);

  @override
  DAppWebViewState createState() => DAppWebViewState();
}

class DAppWebViewState extends State<DAppWebView> {
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
      dev.log("chainId:${widget.chainId}",name:"DappWebView" );
      // 加载JS脚本
      await _loadJS();
      // 初始化WebView控制器
      _initWebViewController();

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e) {
      dev.log('初始化DAppWebView2失败: $e');
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    }
  }

  Future<void> _loadJS() async {
    try {
      _jsScript =
          await rootBundle.loadString('assets/scripts/dapp/dapp_inject.js');
      dev.log('JS脚本加载成功，长度: ${_jsScript.length}');
    } catch (e) {
      dev.log('加载JS脚本失败: $e');
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
            dev.log('页面开始加载: $url');
          },
          onPageFinished: (url) async {
            dev.log('页面加载完成: $url');

            if (widget.onUrlChanged != null) {
              widget.onUrlChanged!(url);
            }

            // 注入JS脚本
            await _injectJS(controller);

            // 设置链和账户信息
            if (widget.isWalletConnected && widget.walletAddress.isNotEmpty) {
              await controller.runJavaScript('''
                setTimeout(function() {
                  if (window.dappController && typeof window.dappController.autoConnect === 'function') {
                    window.dappController.autoConnect('${widget.chainId}','${widget.walletAddress}');
                  }
                }, 1000);
              ''');
            }

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
            dev.log('WebView错误: ${error.description}');
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel('Logger', onMessageReceived: (message) async {
        dev.log('#js控制台消息# ${message.message}');
      })
      ..addJavaScriptChannel(
        'FlutterWeb3',
        onMessageReceived: (message) async {
          dev.log('#接收到的请求消息# ${message.message}');

          try {
            final request = jsonDecode(message.message);
            final method = request['method'];
            final params = request['params'];
            final requestId = request['id'];
            final chainId = request['chainId'];

            switch (method) {
              case 'eth_requestAccounts':
                await updateAccount(widget.walletAddress);
                // 解析请求
                await controller.runJavaScript('''
                  if (window.resolveWeb3Request) {
                    window.resolveWeb3Request('$requestId', '["${widget.walletAddress}"]');
                  }
                ''');
                break;
              case 'wallet_requestPermissions':
                // 处理权限请求
                dev.log('处理wallet_requestPermissions请求');
                final connected = await widget.onConnectRequest(widget.url);
                if (connected) {
                  // 返回权限许可
                  await controller.runJavaScript('''
                    if (window.resolveWeb3Request) {
                      window.resolveWeb3Request('$requestId', '[{"parentCapability":"eth_accounts","caveats":[{"type":"restrictReturnedAccounts","value":["${widget.walletAddress}"]}]}]');
                    }
                    // 触发连接事件
                    if (window.ethereum && window.ethereum.triggerEvent) {
                      window.ethereum.triggerEvent('accountsChanged', ["${widget.walletAddress}"]);
                      window.ethereum.triggerEvent('connect', { chainId: window.ethereum.chainId });
                      console.log('钱包连接成功: ${widget.walletAddress}');
                    }
                  ''');
                  // 更新账户
                  await updateAccount(widget.walletAddress);
                } else {
                  // 拒绝请求
                  await controller.runJavaScript(
                      'if (window.rejectWeb3Request) { window.rejectWeb3Request("$requestId", "用户拒绝连接"); }');
                }
                break;
              case 'wallet_switchEthereumChain':
                await switchChain(chainId);
                // 解析请求
                await controller.runJavaScript('''
                  if (window.resolveWeb3Request) {
                    window.resolveWeb3Request('$requestId', 'null');
                  }
                ''');
                break;
              default:
                widget.onCustomRequest(method, params);
                // 对于未知请求，尝试返回一个空结果
                await controller.runJavaScript('''
                  if (window.resolveWeb3Request) {
                    window.resolveWeb3Request('$requestId', 'null');
                    console.log('处理未知请求: $method');
                  }
                ''');
            }
          } catch (e) {
            dev.log('处理JS消息失败: $e');
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
        dev.log('JS脚本为空，尝试重新加载');
        await _loadJS();
      }

      // 直接注入脚本
      await controller.runJavaScript(_jsScript);
      dev.log('JS脚本注入成功');

      // 验证注入结果
      final result = await controller.runJavaScriptReturningResult('''
        (function() {
          return typeof window.dappController === 'object' 
            && typeof window.FlutterWeb3 === 'object';
        })()
      ''').then((r) => r == true).catchError((e) {
          dev.log('JS验证请求失败', error: e);
          return false;
      });

      if(result){
        dev.log('js注入验证成功');
      }else{
        dev.log('js注入验证失败');
      }

    } catch (e) {
      dev.log('注入JS脚本失败: $e');
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
        }
      ''');
    } catch (e) {
      dev.log('更新账户失败: $e');
    }
  }

  // 切换链（外部调用）
  Future<void> switchChain(String chainId) async {
    if (_controller == null) return;

    try {
      await _controller!.runJavaScript('''
        if (window.dappController) {
          window.dappController.switchChain('$chainId');
        }
      ''');
    } catch (e) {
      dev.log('切换链失败: $e');
    }
  }
}
