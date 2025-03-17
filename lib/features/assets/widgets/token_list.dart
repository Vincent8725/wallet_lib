import 'package:flutter/material.dart';
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
  
  @override
  void initState() {
    super.initState();
    _loadTokens();
  }
  
  @override
  void didUpdateWidget(TokenList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address || oldWidget.chainType != widget.chainType) {
      _loadTokens();
    }
  }
  
  Future<void> _loadTokens() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 获取原生代币余额
      final nativeBalance = await _walletService.getBalance(widget.address, widget.chainType);
      
      // 获取原生代币价格
      final nativePrice = await _walletService.getTokenPrice(widget.chainType);
      
      // 获取代币列表
      final tokens = await _walletService.getTokens(widget.address, widget.chainType);
      
      // 添加默认代币
      if (widget.chainType == 'BSC' && !tokens.any((token) => token.symbol == 'USDT')) {
        // 为BSC链添加默认USDT代币
        tokens.add(Token(
          name: 'Tether USD',
          symbol: 'USDT',
          decimals: 18,
          address: '0x55d398326f99059fF775485246999027B3197955', // BSC上USDT合约地址
          balance: 0.0, // 初始余额为0
          price: 1.0, // USDT价格默认为1美元
          chainType: 'BSC',
        ));
      } else if (widget.chainType == 'ETH' && !tokens.any((token) => token.symbol == 'ETH')) {
        // 为ETH链添加默认ETH代币
        tokens.add(Token(
          name: 'Ethereum',
          symbol: 'ETH',
          decimals: 18,
          address: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', // ETH代币的虚拟地址
          balance: nativeBalance, // 使用原生代币余额
          price: nativePrice, // 使用原生代币价格
          chainType: 'ETH',
        ));
      }
      
      setState(() {
        _nativeBalance = nativeBalance;
        _nativePrice = nativePrice;
        _tokens = tokens;
        _isLoading = false;
      });
    } catch (e) {
      print('加载代币失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final chainConfig = ChainConfigs.getChainConfig(widget.chainType);
    
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    // 移除原生代币条目，只计算代币列表的数量
    final itemCount = _tokens.length;
    
    return RefreshIndicator(
      onRefresh: _loadTokens,
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
                  SizedBox(height: 16),
                  Text(
                    '暂无代币',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                // 直接使用索引获取代币，不再需要 index-1
                final token = _tokens[index];
                final usdValue = token.balance * token.price;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Text(
                      token.symbol.substring(0, 1),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    token.symbol,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(token.name),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${token.balance.toStringAsFixed(4)} ${token.symbol}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${usdValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}