import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';

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

  // 修改为可空类型，以便我们可以重置它
  // Completer<void>? _pageStarted = Completer<void>();
  bool _isInjected = false;
  bool _isLoading = true; // 添加加载状态

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
      // URL改变时不需要手动注入，onPageFinished会处理
    } else if (widget.chainId != oldWidget.chainId ||
        widget.isWalletConnected != oldWidget.isWalletConnected ||
        widget.walletAddress != oldWidget.walletAddress) {
      // 只有在URL没变但其他参数变化时才更新以太坊对象
      //_updateEthereumObject();
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            dev.log('页面开始加载: $url',name: 'WalletBridge');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            dev.log('完成页面加载: $url',name: 'WalletBridge');
            widget.onUrlChanged(url);
            setState(() {
              _isLoading = false;
            });

            // 延迟注入，确保页面完全加载
            if (widget.isWalletConnected && widget.walletAddress.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (!_isInjected) {
                  _injectEthereumObject();
                }
              });
            }
          },
          onUrlChange: (UrlChange change) {
            dev.log('更改页面: ${change.url}',name: 'WalletBridge');
            if (change.url != null) {
              widget.onUrlChanged(change.url!);
            }
          },
          onWebResourceError: (WebResourceError error) {
            dev.log('Web资源错误: ${error.description}',name: 'WalletBridge');
          },
        ),
      )
      ..addJavaScriptChannel("Logger", onMessageReceived: (message) async {
        dev.log('<js控制台消息> ${message.message}',name: 'WalletBridge');
      })
      ..addJavaScriptChannel(
        'WalletBridge',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _injectEthereumObject() async {
    dev.log('开始注入web3对象');
    // 避免重复注入
    if (_isInjected) {
      dev.log('以太坊对象已注入，跳过');
      return;
    }

    try {
      // 确保 _pageStarted 不为空
      // if (_pageStarted == null || !_pageStarted!.isCompleted) {
      //   dev.log('页面尚未开始加载，跳过注入');
      //   return;
      // }

      // await _pageStarted!.future;

      // 先检查页面上是否已存在ethereum对象
      final hasEthereum = await _controller
          .runJavaScriptReturningResult(
              'typeof window.ethereum !== "undefined"')
          .catchError((e) {
        dev.log('检查ethereum对象失败: $e');
        return false;
      });

      if (hasEthereum.toString() == 'true') {
        dev.log('页面已有ethereum对象，更新现有对象');
        //await _updateEthereumObject();
      } else {
        dev.log('注入新的ethereum对象');
        // 注入以太坊对象
        await _controller.runJavaScript(_getEthereumInjectionScript());

        setState(() {
          _isInjected = true;
        });

        dev.log('以太坊对象注入成功');
      }
    } catch (e) {
      dev.log('注入以太坊对象失败: $e');
    }
  }

  // 添加更新以太坊对象的方法，不重新注入整个对象
  // Future<void> _updateEthereumObject() async {
  //   try {
  //     await _controller.runJavaScript('''
  //       if (window.ethereum) {
  //         window.ethereum.chainId = '${widget.chainId}';
  //         window.ethereum.selectedAddress = ${widget.isWalletConnected ? "'${widget.walletAddress}'" : 'null'};
  //         window.ethereum.isConnected = ${widget.isWalletConnected};
  //         console.log('以太坊对象已更新');
  //       }
  //     ''');
  //
  //     setState(() {
  //       _isInjected = true;
  //     });
  //   } catch (e) {
  //     dev.log('更新以太坊对象失败: $e');
  //   }
  // }

  String _getEthereumInjectionScript() {
    return '''
    (function() {
      // 重写 console 方法
      console.log = function (...args) {
        const formatted = args.map(arg =>
          typeof arg === 'object' ? JSON.stringify(arg) : arg
        ).join(' ');  
        window.Logger.postMessage(formatted);
      };

      const _listeners = {};
      let _accounts = [];

      window.ethereum = {
        isMetaMask: true,
        chainId: '${widget.chainId}',
        selectedAddress: ${widget.isWalletConnected ? "'${widget.walletAddress}'" : 'null'},
        isConnected: ${widget.isWalletConnected},
    
        // 核心请求方法
        request: ({ method, params }) => new Promise((resolve, reject) => {
          console.log('请求方法:', method, '参数:', params);
          // 通过 Flutter 桥接发送请求
          const requestId = Date.now();
          window.WalletBridge.postMessage(JSON.stringify({
            id: requestId,
            method,
            params
          }));
    
          // 存储回调
          window.ethereum._callbacks = window.ethereum._callbacks || {};
          window.ethereum._callbacks[requestId] = { resolve, reject };
        }),
    
        // 事件监听（简版）
        on: (event, callback) => {
          _listeners[event] = callback;
        },
      
        // 属性标记
        isMetaMask: true,
        isConnected: () => true,
      
        // Flutter 响应入口（由 Flutter 调用）
        _handleResponse: (id, result) => {
          const callback = window.ethereum._callbacks[id];
          if (callback) {
            callback.resolve(result);
            delete window.ethereum._callbacks[id];
          }
        },
      
        // Flutter 错误处理（由 Flutter 调用）
        _handleError: (id, error) => {
          const callback = window.ethereum._callbacks[id];
          if (callback) {
            callback.reject(new Error(error.message));
            delete window.ethereum._callbacks[id];
          }
        },
        
        // 发送请求
        send: function(method, params) {
          return this.request({method, params});
        },
        
        // 启用以太坊
        enable: function() {
          return this.request({method: 'eth_requestAccounts'});
        },
        
      };
      
      // 触发以太坊就绪事件
      window.dispatchEvent(new Event('ethereum#initialized'));
    })();
    ''';
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) async {
    dev.log('收到JS请求: ${message.message}');

    try {
      final Map<String, dynamic> request = json.decode(message.message);
      final String method = request['method'];
      final List<dynamic> params = request['params'] ?? [];
      final int id = request['id'];

      dynamic result;
      String? error;

      try {
        result = await _handleEthereumRequest(
            method, params.isNotEmpty ? params[0] : {});
      } catch (e) {
        error = e.toString();
        dev.log('处理请求失败: $e');
      }

      // 发送响应回JS
      final response =
          json.encode({'id': id, 'result': result, 'error': error});

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
          dev.log('返回请求地址${widget.walletAddress}');
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
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
