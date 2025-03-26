import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/wallet.dart';

class WalletStorageService {
  static const String _walletsKey = 'wallets';
  static const String _currentWalletKey = 'current_wallet';
  
  // 保存钱包
  Future<bool> saveWallet(Wallet wallet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有钱包列表
      final wallets = await getWallets();
      
      // 检查钱包是否已存在
      final existingWalletIndex = wallets.indexWhere((w) => w.address == wallet.address);
      
      if (existingWalletIndex >= 0) {
        // 更新现有钱包
        wallets[existingWalletIndex] = wallet;
      } else {
        // 添加新钱包
        wallets.add(wallet);
      }
      
      // 保存钱包列表
      final walletsJson = wallets.map((w) => jsonEncode(w.toJson())).toList();
      return await prefs.setStringList(_walletsKey, walletsJson);
    } catch (e) {
      dev.log('保存钱包失败: $e',name: 'WalletStorageService');
      return false;
    }
  }
  
  // 获取所有钱包
  Future<List<Wallet>> getWallets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletsJson = prefs.getStringList(_walletsKey) ?? [];
      
      return walletsJson.map((json) {
        final walletMap = jsonDecode(json);
        return Wallet.fromJson(walletMap);
      }).toList();
    } catch (e) {
      dev.log('获取钱包列表失败: $e',);
      return [];
    }
  }
  
  // 获取当前钱包
  Future<Wallet?> getCurrentWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentWalletAddress = prefs.getString(_currentWalletKey);
      
      if (currentWalletAddress == null) {
        return null;
      }
      
      return getWalletByAddress(currentWalletAddress);
    } catch (e) {
      dev.log('获取当前钱包失败: $e',name: 'WalletStorageService');
      return null;
    }
  }
  
  // 获取当前钱包的链类型
  Future<String> getCurrentChainType() async {
    try {
      final currentWallet = await getCurrentWallet();
      if (currentWallet != null && currentWallet.chainType.isNotEmpty) {
        return currentWallet.chainType;
      }
      return 'ethereum'; // 默认返回以太坊
    } catch (e) {
      dev.log('获取当前钱包链类型失败: $e',name: 'WalletStorageService');
      return 'ethereum'; // 出错时默认返回以太坊
    }
  }
  
  // 设置当前钱包
  Future<bool> setCurrentWallet(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_currentWalletKey, address);
    } catch (e) {
      dev.log('设置当前钱包失败: $e',name: 'WalletStorageService' );
      return false;
    }
  }
  
  // 根据地址获取钱包
  Future<Wallet?> getWalletByAddress(String address) async {
    try {
      final wallets = await getWallets();
      final wallet = wallets.where((w) => w.address == address).toList();
      
      return wallet.isNotEmpty ? wallet.first : null;
    } catch (e) {
      dev.log('获取钱包失败: $e',name: 'WalletStorageService');
      return null;
    }
  }
  
  // 删除钱包
  Future<bool> deleteWallet(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有钱包列表
      final wallets = await getWallets();
      
      // 移除指定地址的钱包
      wallets.removeWhere((w) => w.address == address);
      
      // 保存更新后的钱包列表
      final walletsJson = wallets.map((w) => jsonEncode(w.toJson())).toList();
      final result = await prefs.setStringList(_walletsKey, walletsJson);
      
      // 如果删除的是当前钱包，则清除当前钱包设置
      final currentWallet = await getCurrentWallet();
      if (currentWallet != null && currentWallet.address == address) {
        await prefs.remove(_currentWalletKey);
      }
      
      return result;
    } catch (e) {
      dev.log('删除钱包失败: $e',name: 'WalletStorageService');
      return false;
    }
  }
  
  // 更新钱包名称
  Future<bool> updateWalletName(String address, String newName) async {
    try {
      // 获取钱包
      final wallet = await getWalletByAddress(address);
      if (wallet == null) {
        return false;
      }
      
      // 更新名称
      final updatedWallet = wallet.copyWithName(newName);
      
      // 保存更新后的钱包
      return await saveWallet(updatedWallet);
    } catch (e) {
      dev.log('更新钱包名称失败: $e', name: 'WalletStorageService');
      return false;
    }
  }
}