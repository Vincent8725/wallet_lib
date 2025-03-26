import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

class DAppWebView2 extends StatefulWidget {
  final String url;
  final String walletAddress;
  final bool isWalletConnected;
  final String chainId;
  final Function(String) onUrlChanged;
  final Future<bool> Function(String) onConnectRequest;
  final Future<bool> Function(String) onChainSwitch;
  final Function(String, Map<String, dynamic>) onCustomRequest;

  const DAppWebView2({
    Key? key,
    required this.url,
    required this.walletAddress,
    required this.isWalletConnected,
    required this.onUrlChanged,
    required this.onConnectRequest,
    required this.onChainSwitch,
    required this.onCustomRequest,
    this.chainId = '0x1',
  }) : super(key: key);

  @override
  DAppWebView2State createState() => DAppWebView2State();
}

class DAppWebView2State extends State<DAppWebView2> {
  late WebViewController _controller;
  final Completer<void> _pageStarted = Completer<void>();
  bool _isInjected = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(DAppWebView2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 如果URL改变，加载新URL
    if (widget.url != oldWidget.url) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
    
    // 如果chainId改变，重新注入以太坊对象
    if (widget.chainId != oldWidget.chainId || 
        widget.isWalletConnected != oldWidget.isWalletConnected ||
        widget.walletAddress != oldWidget.walletAddress) {
      _injectEthereumObject();
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            dev.log('Page started loading: $url');
            _pageStarted.complete();
            setState(() {
              _isInjected = false;
            });
          },
          onPageFinished: (String url) {
            dev.log('Page finished loading: $url');
            widget.onUrlChanged(url);
            _injectEthereumObject();
          },
          onUrlChange: (UrlChange change) {
            dev.log('URL changed to: ${change.url}');
            if (change.url != null) {
              widget.onUrlChanged(change.url!);
            }
          },
          onWebResourceError: (WebResourceError error) {
            dev.log('Web resource error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'WalletBridge',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _injectEthereumObject() async {
    if (_isInjected) return;

    try {
      await _pageStarted.future;
      
      // 注入以太坊对象
      await _controller.runJavaScript(_getEthereumInjectionScript());
      
      setState(() {
        _isInjected = true;
      });
      
      dev.log('以太坊对象注入成功');
    } catch (e) {
      dev.log('注入以太坊对象失败: $e');
    }
  }

  String _getEthereumInjectionScript() {
    return '''
    (function() {
      window.ethereum = {
        isMetaMask: true,
        chainId: '${widget.chainId}',
        selectedAddress: ${widget.isWalletConnected ? "'${widget.walletAddress}'" : 'null'},
        isConnected: ${widget.isWalletConnected},
        
        // 请求账户
        request: function(args) {
          return new Promise((resolve, reject) => {
            const id = Date.now().toString();
            const request = {
              id: id,
              method: args.method,
              params: args.params || []
            };
            
            // 发送请求到Flutter
            window.WalletBridge.postMessage(JSON.stringify(request));
            
            // 监听响应
            window.addEventListener('message', function responseHandler(e) {
              if (e.data && e.data.id === id) {
                window.removeEventListener('message', responseHandler);
                if (e.data.error) {
                  reject(new Error(e.data.error));
                } else {
                  resolve(e.data.result);
                }
              }
            });
          });
        },
        
        // 发送请求
        send: function(method, params) {
          return this.request({method, params});
        },
        
        // 启用以太坊
        enable: function() {
          return this.request({method: 'eth_requestAccounts'});
        },
        
        // 监听事件
        on: function(eventName, callback) {
          window.addEventListener('ethereum_' + eventName, (e) => {
            callback(e.detail);
          });
        },
        
        // 移除事件监听
        removeListener: function(eventName, callback) {
          window.removeEventListener('ethereum_' + eventName, callback);
        }
      };
      
      // 触发以太坊就绪事件
      window.dispatchEvent(new Event('ethereum#initialized'));
    })();
    ''';
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) async {
    try {
      final Map<String, dynamic> request = json.decode(message.message);
      final String method = request['method'];
      final List<dynamic> params = request['params'] ?? [];
      final String id = request['id'];
      
      dev.log('收到JS请求: $method, 参数: $params, ID: $id');
      
      dynamic result;
      String? error;
      
      try {
        result = await _handleEthereumRequest(method, params.isNotEmpty ? params[0] : {});
      } catch (e) {
        error = e.toString();
        dev.log('处理请求失败: $e');
      }
      
      // 发送响应回JS
      final response = json.encode({
        'id': id,
        'result': result,
        'error': error
      });
      
      await _controller.runJavaScript('''
        window.dispatchEvent(new MessageEvent('message', {
          data: $response
        }));
      ''');
    } catch (e) {
      dev.log('处理JS消息失败: $e');
    }
  }

  Future<dynamic> _handleEthereumRequest(String method, dynamic params) async {
    switch (method) {
      case 'eth_chainId':
        return widget.chainId;
        
      case 'eth_requestAccounts':
        final connected = await widget.onConnectRequest(widget.url);
        if (connected) {
          return [widget.walletAddress];
        }
        throw Exception('用户拒绝连接');
        
      case 'eth_accounts':
        if (widget.isWalletConnected) {
          return [widget.walletAddress];
        }
        return [];
        
      case 'wallet_switchEthereumChain':
        if (params is List && params.isNotEmpty) {
          final chainId = params[0]['chainId'];
          final switched = await widget.onChainSwitch(chainId);
          if (!switched) {
            throw Exception('切换链失败');
          }
          return null;
        }
        throw Exception('无效的参数');
        
      default:
        // 处理其他自定义请求
        if (params is Map<String, dynamic>) {
          widget.onCustomRequest(method, params);
        } else {
          widget.onCustomRequest(method, {'params': params});
        }
        return null;
    }
  }

  // 提供给外部调用的刷新方法
  void reload() {
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}