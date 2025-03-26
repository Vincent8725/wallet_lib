import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../../../core/config/chain_config.dart';

class BalanceCard extends StatefulWidget {
  final String address;
  final String chainType;
  final bool useDarkStyle;

  const BalanceCard({
    Key? key,
    required this.address,
    required this.chainType,
    this.useDarkStyle = false,
  }) : super(key: key);

  @override
  _BalanceCardState createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  final WalletService _walletService = WalletService();
  final WalletStorageService _storageService = WalletStorageService();

  double _totalUsdValue = 0.0; // 所有代币的总美元价值
  bool _isLoading = true;
  String _walletName = ''; // 钱包名称

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address ||
        oldWidget.chainType != widget.chainType) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return; // 添加检查，如果组件已卸载则直接返回
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取钱包信息
      final wallet = await _storageService.getWalletByAddress(widget.address);

      // 获取原生代币余额
      final balance =
          await _walletService.getBalance(widget.address, widget.chainType);

      // 获取代币价格
      final price = await _walletService.getTokenPrice(widget.chainType);

      // 获取所有代币列表
      final tokens =
          await _walletService.getTokens(widget.address, widget.chainType);

      // 计算所有代币的总美元价值
      double totalValue = balance * price; // 原生代币价值

      // 添加其他代币价值
      for (var token in tokens) {
        totalValue += token.balance * token.price;
      }

      // 添加mounted检查
      if (mounted) {
        setState(() {
          _totalUsdValue = totalValue;
          _walletName = wallet?.name ?? '我的钱包';
          _isLoading = false;
        });
      }
    } catch (e) {
      dev.log('加载余额失败: $e', name: 'BalanceCard');
      // 添加mounted检查
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chainConfig = ChainConfigs.getChainConfig(widget.chainType);
    // 使用主题颜色而不是硬编码颜色
    final backgroundColor = widget.useDarkStyle 
        ? Theme.of(context).primaryColor 
        : Theme.of(context).cardColor;
    final textColor = widget.useDarkStyle 
        ? Colors.white 
        : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      color: backgroundColor,
      // 使用主题定义的卡片形状
      shape: Theme.of(context).cardTheme.shape,
      // shape: RoundedRectangleBorder(
      //   borderRadius: BorderRadius.circular(16),
      // ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 链名称和钱包名称
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  chainConfig.name,
                  style: TextStyle(
                    color: textColor, // 使用withValues替代withOpacity, 0.8 * 255 ≈ 204
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _walletName,
                  style: TextStyle(
                    color: textColor, // 0.8 * 255 ≈ 204
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 地址
            Text(
              widget.address.length > 20
                  ? '${widget.address.substring(0, 10)}...${widget.address.substring(widget.address.length - 10)}'
                  : widget.address,
              style: TextStyle(
                color: textColor, // 0.6 * 255 ≈ 153
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),

            // 总资产价值
            Center(
              child: Column(
                children: [
                  _isLoading
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        )
                      : Text(
                          '\$${_totalUsdValue.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
