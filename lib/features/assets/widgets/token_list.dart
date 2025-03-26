import 'dart:developer' as dev;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/config/chain_config.dart';
import '../../../models/token.dart';

class TokenList extends StatefulWidget {
  final String address;
  final String chainType;

  const TokenList({
    Key? key,
    required this.address,
    required this.chainType,
  }) : super(key: key);

  @override
  _TokenListState createState() => _TokenListState();
}

class _TokenListState extends State<TokenList> {
  final WalletService _walletService = WalletService();

  List<Token> _tokens = [];
  double _nativeBalance = 0.0; // 原生代币余额
  double _nativePrice = 0.0; // 原生代币价格
  bool _isLoading = true;
  bool _isRefreshing = false; // 添加刷新状态标记

  @override
  void initState() {
    super.initState();
    _loadCachedTokens(); // 修改为先加载缓存
  }

  @override
  void didUpdateWidget(TokenList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address ||
        oldWidget.chainType != widget.chainType) {
      _loadCachedTokens(); // 修改为先加载缓存
    }
  }

  // 新增方法：从缓存加载代币信息
  Future<void> _loadCachedTokens() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${widget.address}_${widget.chainType}_tokens';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        final List<dynamic> tokensData = data['tokens'] ?? [];
        final List<Token> tokens =
            tokensData.map((item) => Token.fromJson(item)).toList();

        setState(() {
          _tokens = tokens;
          _nativeBalance = data['nativeBalance'] ?? 0.0;
          _nativePrice = data['nativePrice'] ?? 0.0;
          _isLoading = false;
        });

        dev.log('从缓存加载了${tokens.length}个代币', name: 'TokenList');
      } else {
        // 如果没有缓存，调用原有的加载方法
        _loadTokens();
      }

      // 异步更新最新数据
      _refreshTokenData();
    } catch (e) {
      dev.log('加载缓存代币失败: $e', name: 'TokenList', level: 900);
      // 如果加载缓存失败，调用原有的加载方法
      _loadTokens();
    }
  }

  // 需要实现_loadTokens方法来加载代币数据
  Future<void> _loadTokens() async {
    try {
      // 获取原生代币余额
      final nativeBalance =
          await _walletService.getBalance(widget.address, widget.chainType);

      // 获取代币列表
      final tokens =
          await _walletService.getTokens(widget.address, widget.chainType);

      if (mounted) {
        setState(() {
          _nativeBalance = nativeBalance;
          _tokens = tokens;
          _isLoading = false;
        });
      }

      // 更新代币价格
      await _updateTokenPrices();
    } catch (e) {
      dev.log('加载代币失败: $e', name: 'TokenList', level: 900);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 新增方法：刷新代币数据（余额和价格）
  Future<void> _refreshTokenData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // 获取原生代币余额
      final nativeBalance =
          await _walletService.getBalance(widget.address, widget.chainType);

      // 更新原生代币余额
      final updatedTokens = List<Token>.from(_tokens);
      for (int i = 0; i < updatedTokens.length; i++) {
        if (updatedTokens[i].address ==
                '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' ||
            (widget.chainType == 'ETH' && updatedTokens[i].symbol == 'ETH') ||
            (widget.chainType == 'BSC' && updatedTokens[i].symbol == 'BNB')) {
          updatedTokens[i] = updatedTokens[i].copyWith(balance: nativeBalance);
        } else {
          // 获取代币余额
          try {
            final balance = await _walletService.getTokenBalance(
                widget.address, updatedTokens[i].address, widget.chainType);
            updatedTokens[i] = updatedTokens[i].copyWith(balance: balance);
          } catch (e) {
            dev.log('获取代币${updatedTokens[i].symbol}余额失败: $e',
                name: 'TokenList', level: 900);
          }
        }
      }

      // 更新UI
      if (mounted) {
        setState(() {
          _nativeBalance = nativeBalance;
          _tokens = updatedTokens;
        });
      }

      // 直接调用价格更新方法，确保价格更新
      await _updateTokenPrices();
    } catch (e) {
      dev.log('刷新代币余额失败: $e', name: 'TokenList', level: 900);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // 新增方法：缓存代币数据
  Future<void> _cacheTokenData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${widget.address}_${widget.chainType}_tokens';

      final Map<String, dynamic> data = {
        'tokens': _tokens.map((token) => token.toJson()).toList(),
        'nativeBalance': _nativeBalance,
        'nativePrice': _nativePrice,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(cacheKey, json.encode(data));
      dev.log('缓存了${_tokens.length}个代币数据', name: 'TokenList');
    } catch (e) {
      dev.log('缓存代币数据失败: $e', name: 'TokenList', level: 900);
    }
  }

  // 修改现有方法：在更新价格后缓存数据
  Future<void> _updateTokenPrices() async {
    try {
      // 获取原生代币价格
      final nativePrice = await _walletService.getTokenPrice(widget.chainType);
      dev.log('获取到${widget.chainType}原生代币价格: $nativePrice', name: 'TokenList');

      // 更新代币价格
      final updatedTokens = List<Token>.from(_tokens);
      for (int i = 0; i < updatedTokens.length; i++) {
        // 修正原生代币判断逻辑
        if (updatedTokens[i].address ==
                '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' ||
            (widget.chainType == 'ETH' && updatedTokens[i].symbol == 'ETH') ||
            (widget.chainType == 'BSC' && updatedTokens[i].symbol == 'BNB')) {
          // 更新原生代币价格
          final oldPrice = updatedTokens[i].price;
          updatedTokens[i] = updatedTokens[i].copyWith(price: nativePrice);
          dev.log(
              '更新${updatedTokens[i].symbol}价格: $oldPrice -> ${updatedTokens[i].price}',
              name: 'TokenList');
        } else if (updatedTokens[i].symbol == 'USDT') {
          // USDT价格固定为1美元
          updatedTokens[i] = updatedTokens[i].copyWith(price: 1.0);
          dev.log('设置USDT价格为1.0', name: 'TokenList');
        } else {
          // 获取其他代币价格
          try {
            final price =
                await _walletService.getTokenPrice(updatedTokens[i].address);
            final oldPrice = updatedTokens[i].price;
            updatedTokens[i] = updatedTokens[i].copyWith(price: price);
            dev.log(
                '更新${updatedTokens[i].symbol}价格: $oldPrice -> ${updatedTokens[i].price}',
                name: 'TokenList');
          } catch (e) {
            // 单个代币价格获取失败，保留原价格，不影响其他代币
            dev.log('获取代币${updatedTokens[i].symbol}价格失败: $e',
                name: 'TokenList', level: 900);
          }
        }
      }

      // 更新UI
      if (mounted) {
        setState(() {
          _nativePrice = nativePrice;
          _tokens = updatedTokens;
        });
      }

      // 添加：缓存更新后的数据
      _cacheTokenData();
    } catch (e) {
      // 价格更新失败，但不影响代币列表显示
      dev.log('更新代币价格失败: $e', name: 'TokenList', level: 900);
    }
  }

  @override
  Widget build(BuildContext context) {
    ChainConfigs.getChainConfig(widget.chainType);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 移除原生代币条目，只计算代币列表的数量
    final itemCount = _tokens.length;

    return RefreshIndicator(
      onRefresh: _refreshTokenData,
      child: itemCount == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.token,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无代币',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                ListView.builder(
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    // 直接使用索引获取代币
                    final token = _tokens[index];
                    final usdValue = token.balance * token.price;

                    // 使用Dismissible包装ListTile，实现左滑删除功能
                    return Dismissible(
                      key: Key(token.address), // 使用代币地址作为唯一标识
                      direction: DismissDirection.endToStart, // 只允许从右向左滑动
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        color: Colors.red,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        // 弹出确认对话框
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('确认删除'),
                              content: Text('确定要从列表中移除 ${token.symbol} 代币吗？'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('确定'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        // 从列表中移除代币
                        setState(() {
                          _tokens.removeAt(index);
                        });

                        // 更新缓存
                        _cacheTokenData();

                        // 显示提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${token.symbol} 已从列表中移除'),
                            action: SnackBarAction(
                              label: '撤销',
                              onPressed: () {
                                // 撤销删除操作
                                setState(() {
                                  _tokens.insert(index, token);
                                });
                                // 更新缓存
                                _cacheTokenData();
                              },
                            ),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: _getTokenIcon(token.symbol),
                        ),
                        title: Text(
                          token.symbol,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(token.name),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${token.balance.toStringAsFixed(4)} ${token.symbol}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              token.price > 0
                                  ? '\$${usdValue.toStringAsFixed(2)}'
                                  : '加载价格中...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_isRefreshing)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: Theme.of(context).primaryColor.withAlpha(125),
                    ),
                  ),
              ],
            ),
    );
  }
}

// 添加这个方法在类中的任何位置
  Widget _getTokenIcon(String symbol) {
    return Image.asset(
      'assets/icons/token/$symbol.png',
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        // 当图片加载失败时，显示首字母
        return Text(
          symbol.substring(0, 1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        );
      },
    );
  }
