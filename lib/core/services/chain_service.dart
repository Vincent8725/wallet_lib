import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_storage_service.dart';

class ChainService {
  static const String _currentChainKey = 'current_chain';
  static final WalletStorageService _walletService = WalletStorageService();
  
  // 获取当前选择的链
  static Future<String> getCurrentChain() async {
    try {
      // 首先尝试从当前钱包获取链类型
      final chainType = await _walletService.getCurrentChainType();
      if (chainType.isNotEmpty) {
        return chainType;
      }
      
      // 如果钱包没有链类型，则从偏好设置获取
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentChainKey) ?? 'ethereum'; // 默认为以太坊
    } catch (e) {
      print('获取当前链失败: $e');
      return 'ethereum'; // 出错时默认返回以太坊
    }
  }
  
  // 设置当前选择的链
  static Future<bool> setCurrentChain(String chain) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_currentChainKey, chain);
  }
  
  // 根据chainId获取链名称
  static String getChainNameByChainId(String chainId) {
    switch (chainId) {
      case '0x1':
        return 'ethereum';
      case '0x38':
        return 'bsc';
      default:
        return 'ethereum';
    }
  }
  
  // 根据链名称获取chainId
  static String getChainIdByName(String name) {
    switch (name) {
      case 'ethereum':
        return '0x1';
      case 'bsc':
        return '0x38';
      default:
        return '0x1';
    }
  }
  
  // 获取链的显示名称
  static String getChainDisplayName(String chainId) {
    switch (chainId) {
      case '0x1':
        return 'ETH';
      case '0x38':
        return 'BSC';
      default:
        return 'ETH';
    }
  }
}