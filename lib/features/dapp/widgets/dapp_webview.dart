import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

class DAppWebView extends StatefulWidget {
  final String url;
  final Function(String) onUrlChanged;
  final bool isAuthorized;
  final Future<dynamic> Function(String, Map<String, dynamic>)? onInteractionRequest;
  final String walletAddress;
  final bool isWalletConnected;
  final Future<bool> Function(String url)? onConnectRequest;

  const DAppWebView({
    Key? key,
    required this.url,
    required this.onUrlChanged,
    required this.isAuthorized,
    required this.walletAddress,
    required this.isWalletConnected,
    required this.onInteractionRequest,
    this.onConnectRequest,
  }) : super(key: key);

  @override
  DAppWebViewState createState() => DAppWebViewState();
}

class DAppWebViewState extends State<DAppWebView> {
  late WebViewController _controller;
  final Completer<void> _webviewLoadCompleter = Completer<void>();
  String _basicJsScript = '';
  bool _hasPromptedForConnection = false;
  bool _isCheckingDAppNeeds = false;
  bool _isScriptInjected = false;
  
  @override
  void initState() {
    super.initState();
    _loadJsScript();
    _initWebViewController();
  }
  
  @override
  void dispose() {
    if (!_webviewLoadCompleter.isCompleted) {
      _webviewLoadCompleter.complete();
    }
    super.dispose();
  }
  
  // 加载JS脚本
  Future<void> _loadJsScript() async {
    try {
      _basicJsScript = await rootBundle.loadString('assets/scripts/dapp/basic.js');
      print('JS脚本加载成功，长度: ${_basicJsScript.length}');
    } catch (e) {
      print('加载JS脚本失败: $e');
      throw Exception('无法加载Web3脚本: $e');
    }
  }
  
  // 添加公开的 reload 方法
  void reload() {
    _controller.reload();
    _isScriptInjected = false;
    _hasPromptedForConnection = false;
  }
  
  void _initWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('页面开始加载: $url');
            // 重置连接状态
            _hasPromptedForConnection = false;
            _isCheckingDAppNeeds = false;
            _isScriptInjected = false;
          },
          onPageFinished: (String url) async {
            widget.onUrlChanged(url);
            print('页面加载完成: $url');
            
            // 注入基础脚本
            await _injectBasicScript();
            
            // 如果已连接，直接注入提供者
            if (widget.isWalletConnected && widget.walletAddress.isNotEmpty) {
              await _injectEthereumProvider();
            } else {
              // 否则检查DApp是否需要钱包
              _checkDAppNeedsWallet();
            }
          },
          onUrlChange: (UrlChange change) {
            widget.onUrlChanged(change.url ?? '');
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView错误: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterWeb3',
        onMessageReceived: (JavaScriptMessage message) async {
          print('收到JS消息: ${message.message}');
          await _handleWeb3Message(message);
        },
      )
      ..loadRequest(Uri.parse(widget.url))
      .then((_) {
        if (!_webviewLoadCompleter.isCompleted) {
          _webviewLoadCompleter.complete();
        }
      });
  }
  
  // 注入基础脚本
  Future<void> _injectBasicScript() async {
    //print('开始注入脚本：${_webviewLoadCompleter.isCompleted},$_isScriptInjected');
    if (_webviewLoadCompleter.isCompleted && _isScriptInjected) return;
    
    try {
      // 先检查是否已经注入
      final checkResult = await _controller.runJavaScriptReturningResult(
        "typeof window.walletDebug === 'function' ? 'injected' : 'not-injected'"
      );
      
      if (checkResult.toString() == 'injected') {
        print('基础脚本已经注入，跳过');
        _isScriptInjected = true;
        return;
      }

      print('开始注入基础脚本');
      await _controller.runJavaScript(_basicJsScript);
      
      // 验证注入结果
      final verifyResult = await _controller.runJavaScriptReturningResult(
        "typeof window.walletDebug === 'function' ? 'success' : 'failed'"
      );
      
      if (verifyResult.toString() == 'success') {
        print('基础脚本注入成功');
        _isScriptInjected = true;
      } else {
        print('基础脚本注入失败，验证未通过');
        throw Exception('脚本注入后验证失败');
      }
    } catch (e) {
      print('基础脚本注入失败: $e');
      throw Exception('无法注入Web3脚本: $e');
    }
  }
  
  // 检查DApp是否需要钱包
  Future<void> _checkDAppNeedsWallet() async {
    if (_webviewLoadCompleter.isCompleted || _hasPromptedForConnection || _isCheckingDAppNeeds || !_isScriptInjected) return;
    
    _isCheckingDAppNeeds = true;
    
    try {
      // 延迟检查，确保DApp已完全加载
      await Future.delayed(Duration(seconds: 1));
      
      final needsWallet = await _controller.runJavaScriptReturningResult(
        'window.checkDAppNeedsWallet()'
      );
      
      final bool needsWalletBool = needsWallet.toString().toLowerCase() == 'true';
      print('DApp是否需要钱包: $needsWalletBool');
      
      if (needsWalletBool) {
        _hasPromptedForConnection = true;
        
        // 提示用户连接
        if (widget.onConnectRequest != null) {
          final connected = await widget.onConnectRequest!(widget.url);
          
          if (connected) {
            // 连接成功，注入提供者
            await _injectEthereumProvider();
          }
        }
      }
    } catch (e) {
      print('检查DApp需求失败: $e');
    } finally {
      _isCheckingDAppNeeds = false;
    }
  }
  
  // 注入以太坊提供者
  Future<void> _injectEthereumProvider() async {
    print('开始初始化EthProvider：${_webviewLoadCompleter.isCompleted},$_isScriptInjected');
    if (_webviewLoadCompleter.isCompleted || !_isScriptInjected) return;
    
    try {
      // 调用JS中的初始化函数
      final js = '''
      window.initEthereumProvider('${widget.walletAddress}', ${widget.isWalletConnected});
      window.notifyWalletConnection('${widget.walletAddress}');
      'success';
      ''';
      
      final result = await _controller.runJavaScriptReturningResult(js);
      print('以太坊提供者注入结果: $result');
      
      if (result.toString() != 'success') {
        throw Exception('以太坊提供者注入失败');
      }
    } catch (e) {
      print('以太坊提供者注入失败: $e');
      throw Exception('无法注入以太坊提供者: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
  
  // 添加更新钱包地址的方法
  Future<void> updateWalletAddress(String newAddress) async {
    if (_webviewLoadCompleter.isCompleted || !_isScriptInjected) return;
    
    try {
      final js = '''
      (function() {
        if (window.ethereum) {
          // 更新地址
          window.ethereum.selectedAddress = '$newAddress';
          
          // 触发事件
          if (window.ethereum._events && window.ethereum._events.accountsChanged) {
            window.ethereum._events.accountsChanged.forEach(function(callback) {
              if (typeof callback === 'function') {
                callback(['$newAddress']);
              }
            });
          }
          
          console.log('钱包地址已更新: $newAddress');
          return true;
        }
        return false;
      })();
      ''';
      
      final result = await _controller.runJavaScriptReturningResult(js);
      if (result.toString() != 'true') {
        throw Exception('更新钱包地址失败: ethereum对象不存在');
      }
    } catch (e) {
      print('更新钱包地址失败: $e');
      throw Exception('无法更新钱包地址: $e');
    }
  }
  
  // 添加执行自定义JS的方法
  Future<dynamic> evaluateJavaScript(String js) async {
    if (_webviewLoadCompleter.isCompleted) return null;
    
    try {
      return await _controller.runJavaScriptReturningResult(js);
    } catch (e) {
      print('执行JavaScript失败: $e');
      throw Exception('执行JavaScript失败: $e');
    }
  }
  
  // 添加获取当前URL的方法
  Future<String> getCurrentUrl() async {
    if (_webviewLoadCompleter.isCompleted) return '';
    
    try {
      final result = await _controller.currentUrl();
      return result ?? '';
    } catch (e) {
      print('获取当前URL失败: $e');
      throw Exception('获取当前URL失败: $e');
    }
  }
  
  // 处理Web3消息
  Future<void> _handleWeb3Message(JavaScriptMessage message) async {
    try {
      final Map<String, dynamic> request = jsonDecode(message.message);
      final String method = request['method'] ?? '';
      final dynamic params = request['params'];
      final String id = request['id']?.toString() ?? '0';

      print('收到DApp请求: $method, ID: $id');

      if (method == 'eth_requestAccounts' || method == 'eth_accounts') {
        // 处理账户请求
        if (widget.isWalletConnected) {
          // 已连接，直接返回地址
          print('钱包已连接，直接返回地址');
          final result = jsonEncode([widget.walletAddress]);
          await _controller.runJavaScript(
              "window.resolveWeb3Request('$id', '$result');"
          );
        } else {
          // 请求连接钱包
          print('请求连接钱包，调用onConnectRequest');
          _hasPromptedForConnection = true;
          final connected = await widget.onConnectRequest?.call(widget.url) ?? false;

          if (connected) {
            // 连接成功，返回地址
            final result = jsonEncode([widget.walletAddress]);
            await _controller.runJavaScript(
                "window.resolveWeb3Request('$id', '$result');"
            );

            // 注入提供者
            await _injectEthereumProvider();
          } else {
            // 连接失败，返回错误
            await _controller.runJavaScript(
                "window.rejectWeb3Request('$id', '用户拒绝连接钱包');"
            );
          }
        }
      } else {
        // 处理其他请求
        if (!widget.isAuthorized) {
          // 未授权，拒绝请求
          await _controller.runJavaScript(
              "window.rejectWeb3Request('$id', '未授权的请求');"
          );
          return;
        }

        // 转发请求到外部处理
        if (widget.onInteractionRequest != null) {
          try {
            final result = await widget.onInteractionRequest!(
                method,
                params is Map ? params.cast<String, dynamic>() : {});

            if (result != null) {
              // 请求成功，返回结果
              final resultJson = jsonEncode(result);
              await _controller.runJavaScript(
                  "window.resolveWeb3Request('$id', '$resultJson');"
              );
            } else {
              // 请求失败，返回错误
              await _controller.runJavaScript(
                  "window.rejectWeb3Request('$id', '请求处理失败');"
              );
            }
          } catch (e) {
            // 处理异常
            await _controller.runJavaScript(
                "window.rejectWeb3Request('$id', '${e.toString().replaceAll("'", "\\'")}');"
            );
          }
        } else {
          // 没有处理器，拒绝请求
          await _controller.runJavaScript(
              "window.rejectWeb3Request('$id', '没有可用的请求处理器');"
          );
        }
      }
    } catch (e) {
      print('处理Web3消息失败: $e');
      throw Exception('处理Web3消息失败: $e');
    }
  }
}

