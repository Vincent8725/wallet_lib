import 'package:intl/intl.dart';
import '../core/config/chain_config.dart';

class Transaction {
  final String hash;
  final String from;
  final String to;
  final double value;
  final String status;
  final DateTime timestamp;
  final int gasUsed;
  final BigInt gasPrice;
  final String chainType;

  Transaction({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.status,
    required this.timestamp,
    required this.gasUsed,
    required this.gasPrice,
    required this.chainType,
  });

  // 获取交易类型（发送/接收）
  String getType(String currentAddress) {
    if (from.toLowerCase() == currentAddress.toLowerCase()) {
      return '发送';
    } else if (to.toLowerCase() == currentAddress.toLowerCase()) {
      return '接收';
    } else {
      return '合约交互';
    }
  }

  // 获取交易方向图标
  bool isOutgoing(String currentAddress) {
    return from.toLowerCase() == currentAddress.toLowerCase();
  }

  // 获取格式化的时间
  String get formattedTime {
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
  }

  // 获取简短的哈希值
  String get shortHash {
    if (hash.length > 10) {
      return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
    }
    return hash;
  }

  // 获取交易费用（ETH/BNB）
  double get fee {
    final gasPriceInEth = gasPrice / BigInt.from(10).pow(18);
    return gasUsed * gasPriceInEth.toDouble();
  }
  
  // 获取链的符号
  String get symbol {
    return ChainConfigs.getChainConfig(chainType).symbol;
  }
  
  // 获取浏览器URL
  String get explorerUrl {
    final config = ChainConfigs.getChainConfig(chainType);
    return '${config.explorerUrl}/tx/$hash';
  }
}