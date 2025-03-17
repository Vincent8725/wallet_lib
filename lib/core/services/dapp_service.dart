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
      print('DApp授权失败: $e');
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
      print('撤销DApp授权失败: $e');
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
      print('DApp交互失败: $e');
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
          EtherAmount.fromUnitAndValue(EtherUnit.wei, BigInt.parse(params['value'])) : 
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
    final signature = await credentials.signPersonalMessage(utf8.encode(message));
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
      print('连接钱包失败: $e');
      return false;
    }
  }
}