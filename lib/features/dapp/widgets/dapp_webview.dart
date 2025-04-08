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
  final Function(String)? onUrlChanged;

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
  WebViewController? _controller;
  String _jsScript = '';
  bool _isLoading = true;
  final Completer<void> _initCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // 异步初始化方法
  Future<void> _initialize() async {
    try {
      await _loadJS();
      _initWebViewController();
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e) {
      dev.log('初始化DAppWebView失败: $e');
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    }
  }

  Future<void> _loadJS() async {
    try {
      _jsScript = await rootBundle.loadString('assets/scripts/dapp/dapp_inject.js');
    } catch (e) {
      dev.log('加载JS脚本失败: $e');
      throw Exception('无法加载DApp注入脚本');
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
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (widget.onUrlChanged != null) {
              widget.onUrlChanged!(url);
            }

            await _injectJS(controller);

            if (widget.isWalletConnected && widget.walletAddress.isNotEmpty) {
              await controller.runJavaScript('''
                setTimeout(function() {
                  if (window.ethereum && typeof window.initialize === 'function') {
                    window.initialize('${widget.chainId}','${widget.walletAddress}');
                    console.log('初始化成功');
                  } else {
                    console.log('初始化失败');
                  }            
                }, 500);
              ''');
            }

            setState(() => _isLoading = false);
          },
          onUrlChange: (change) {
            if (widget.onUrlChanged != null && change.url != null) {
              widget.onUrlChanged!(change.url!);
            }
          },
          onWebResourceError: (error) {
            dev.log('WebView错误: ${error.description}');
            setState(() => _isLoading = false);
          },
        ),
      )
      ..addJavaScriptChannel('Logger', onMessageReceived: (message) {
        dev.log('<js> ${message.message}');
      })
      ..addJavaScriptChannel(
        'FlutterWeb3',
        onMessageReceived: (message) async {
          try {
            final request = jsonDecode(message.message);
            final method = request['method'];
            final params = request['params'];
            final requestId = request['id'];

            switch (method) {
              case 'eth_requestAccounts':
                await controller.runJavaScript(
                  'window.resolveWeb3Request("$requestId", ["${widget.walletAddress}"])'
                );
                break;
                
              case 'wallet_requestPermissions':
                final connected = await widget.onConnectRequest(widget.url);
                if (connected) {
                  await controller.runJavaScript('''
                    window.resolveWeb3Request('$requestId', '[{"parentCapability":"eth_accounts","caveats":[{"type":"restrictReturnedAccounts","value":["${widget.walletAddress}"]}]}]');
                    if (window.ethereum && window.ethereum.triggerEvent) {
                      window.ethereum.triggerEvent('accountsChanged', ["${widget.walletAddress}"]);
                      window.ethereum.triggerEvent('connect', { chainId: window.ethereum.chainId });
                    }
                  ''');
                } else {
                  await controller.runJavaScript(
                    'window.rejectWeb3Request("$requestId", "用户拒绝连接")'
                  );
                }
                break;
                
              case 'wallet_switchEthereumChain':
                final chainId = params[0]['chainId'];
                final switched = await widget.onChainSwitch(chainId);
                if (switched) {
                  await controller.runJavaScript(
                    'window.resolveWeb3Request("$requestId", null)'
                  );
                } else {
                  await controller.runJavaScript(
                    'window.rejectWeb3Request("$requestId", "用户拒绝切换链")'
                  );
                }
                break;
                
              default:
                widget.onCustomRequest(method, params is List ? params[0] : params);
                await controller.runJavaScript(
                  'window.resolveWeb3Request("$requestId", null)'
                );
            }
          } catch (e) {
            dev.log('处理JS消息失败: $e');
            controller.runJavaScript(
              'window.ethereum.triggerEvent("requestError", { error: "$e" })'
            );
          }
        },
      );

    controller.loadRequest(Uri.parse(widget.url));

    setState(() => _controller = controller);
  }

  Future<void> _injectJS(WebViewController controller) async {
    try {
      if (_jsScript.isEmpty) {
        await _loadJS();
      }

      await controller.runJavaScript(_jsScript);
      
      final result = await controller.runJavaScriptReturningResult(
        'typeof window.ethereum === "object" && typeof window.FlutterWeb3 === "object"'
      ).then((r) => r.toString() == 'true').catchError((_) => false);

      if (result) {
        await controller.runJavaScript(
          'window.initialize("${widget.chainId}","${widget.walletAddress}")'
        );
      }
    } catch (e) {
      dev.log('注入JS脚本失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
