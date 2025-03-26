import 'dart:developer' as dev;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DAppService {
  // 存储已授权的DApp
  static const String _authorizedDAppsKey = 'authorized_dapps';
  
  // 获取已授权的DApp列表
  Future<List<String>> getAuthorizedDApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_authorizedDAppsKey) ?? [];
  }
  
  // 检查DApp是否已授权
  Future<bool> isDAppAuthorized(String dappUrl) async {
    final authorizedDApps = await getAuthorizedDApps();
    return authorizedDApps.contains(dappUrl);
  }
  
  // DApp 授权
  Future<bool> authorize(String dappUrl, String walletAddress) async {
    try {
      // 检查DApp是否有效
      final isValid = await _validateDApp(dappUrl);
      if (!isValid) {
        throw Exception('无效的DApp URL');
      }
      
      // 保存授权信息
      final prefs = await SharedPreferences.getInstance();
      final authorizedDApps = prefs.getStringList(_authorizedDAppsKey) ?? [];
      
      if (!authorizedDApps.contains(dappUrl)) {
        authorizedDApps.add(dappUrl);
        await prefs.setStringList(_authorizedDAppsKey, authorizedDApps);
      }
      
      return true;
    } catch (e) {
      dev.log('DApp授权失败: $e');
      return false;
    }
  }
  
  // 撤销DApp授权
  Future<bool> revokeAuthorization(String dappUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authorizedDApps = prefs.getStringList(_authorizedDAppsKey) ?? [];
      
      if (authorizedDApps.contains(dappUrl)) {
        authorizedDApps.remove(dappUrl);
        await prefs.setStringList(_authorizedDAppsKey, authorizedDApps);
      }
      
      return true;
    } catch (e) {
      dev.log('撤销DApp授权失败: $e');
      return false;
    }
  }
  
  // 与DApp交互
  Future<dynamic> interact(String dappUrl, String method, Map<String, dynamic> params, String privateKey) async {
    try {
      // 检查DApp是否已授权
      final isAuthorized = await isDAppAuthorized(dappUrl);
      if (!isAuthorized) {
        throw Exception('DApp未授权');
      }
      
      // 根据不同的方法执行不同的操作
      switch (method) {
        case 'eth_sendTransaction':
          return await _sendTransaction(params, privateKey);
        case 'eth_sign':
          return await _signMessage(params, privateKey);
        case 'eth_getBalance':
          return await _getBalance(params);
        default:
          throw Exception('不支持的方法: $method');
      }
    } catch (e) {
      dev.log('DApp交互失败: $e');
      rethrow;
    }
  }
  
  // 验证DApp是否有效
  Future<bool> _validateDApp(String dappUrl) async {
    try {
      // 简单验证URL格式
      final uri = Uri.parse(dappUrl);
      if (!uri.isScheme('http') && !uri.isScheme('https')) {
        return false;
      }
      
      // 尝试访问DApp
      final response = await http.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // 发送交易
  Future<String> _sendTransaction(Map<String, dynamic> params, String privateKey) async {
    // 创建Web3客户端
    final client = Web3Client('https://mainnet.infura.io/v3/your-infura-key', http.Client());
    
    try {
      // 解析交易参数
      final from = params['from'];
      final to = params['to'];
      final value = params['value'] != null ? 
          EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(params['value'])) :
          EtherAmount.zero();
      final data = params['data'] ?? '0x';
      
      // 创建交易
      final transaction = Transaction(
        from: EthereumAddress.fromHex(from),
        to: EthereumAddress.fromHex(to),
        value: value,
        data: hexToBytes(data),
      );
      
      // 使用私钥签名并发送交易
      final credentials = EthPrivateKey.fromHex(privateKey);
      final txHash = await client.sendTransaction(credentials, transaction, chainId: 1);
      
      return txHash;
    } finally {
      client.dispose();
    }
  }
  
  // 签名消息
  Future<String> _signMessage(Map<String, dynamic> params, String privateKey) async {
    final message = params['message'];
    final credentials = EthPrivateKey.fromHex(privateKey);
    
    // 签名消息
    final signature = credentials.signPersonalMessageToUint8List(utf8.encode(message));
    return bytesToHex(signature);
  }
  
  // 获取余额
  Future<String> _getBalance(Map<String, dynamic> params) async {
    final address = params['address'];
    final client = Web3Client('https://mainnet.infura.io/v3/your-infura-key', http.Client());
    
    try {
      final balance = await client.getBalance(EthereumAddress.fromHex(address));
      return balance.getValueInUnit(EtherUnit.ether).toString();
    } finally {
      client.dispose();
    }
  }

  // 在DAppService类中添加
  Future<bool> connectWallet(String url, String walletAddress) async {
    try {
      // 这里可以添加连接钱包的逻辑
      // 例如保存连接记录、验证DApp等

      // 简单实现，直接返回成功
      return true;
    } catch (e) {
      dev.log('连接钱包失败: $e');
      return false;
    }
  }
  
  // 检查DApp是否已收藏
  Future<bool> isFavoriteDApp(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_dapps') ?? [];
      
      // 提取域名进行比较
      final host = Uri.parse(url).host;
      
      for (final favorite in favorites) {
        final favoriteData = json.decode(favorite);
        final favoriteUrl = favoriteData['url'];
        final favoriteHost = Uri.parse(favoriteUrl).host;
        
        if (favoriteHost == host) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      dev.log('检查DApp收藏状态失败: $e');
      return false;
    }
  }
  
  // 添加DApp到收藏
  Future<bool> addFavoriteDApp(String url, String name, String chainId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_dapps') ?? [];
      
      // 检查是否已存在
      if (await isFavoriteDApp(url)) {
        return true; // 已经收藏过了
      }
      
      // 创建收藏数据
      final dappData = {
        'name': name,
        'url': url,
        'chainId': chainId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // 添加到收藏列表
      favorites.add(json.encode(dappData));
      
      // 保存更新后的列表
      await prefs.setStringList('favorite_dapps', favorites);
      
      return true;
    } catch (e) {
      dev.log('添加DApp到收藏失败: $e');
      return false;
    }
  }
  
  // 从收藏中移除DApp
  Future<bool> removeFavoriteDApp(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_dapps') ?? [];
      
      // 提取域名进行比较
      final host = Uri.parse(url).host;
      
      // 过滤掉要移除的DApp
      final updatedFavorites = favorites.where((favorite) {
        final favoriteData = json.decode(favorite);
        final favoriteUrl = favoriteData['url'];
        final favoriteHost = Uri.parse(favoriteUrl).host;
        
        return favoriteHost != host;
      }).toList();
      
      // 保存更新后的列表
      await prefs.setStringList('favorite_dapps', updatedFavorites);
      
      return true;
    } catch (e) {
      dev.log('从收藏中移除DApp失败: $e');
      return false;
    }
  }
  
  // 获取所有收藏的DApp
  Future<List<Map<String, dynamic>>> getFavoriteDApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_dapps') ?? [];
      
      return favorites.map((favorite) {
        return Map<String, dynamic>.from(json.decode(favorite));
      }).toList();
    } catch (e) {
      dev.log('获取收藏DApp列表失败: $e');
      return [];
    }
  }
}