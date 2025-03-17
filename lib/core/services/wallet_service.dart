import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3;
import 'package:bip39/bip39.dart' as bip39;
import 'package:hex/hex.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/chain_config.dart';
import '../../models/wallet.dart';
import '../../models/transaction.dart';
import '../../models/token.dart';
import '../../models/wallet.dart' as wallet_model;
import '../config/chain_config.dart';

class WalletService {
  // 通过助记词创建钱包
  Future<Wallet> createWalletFromMnemonic(String mnemonic) async {
    try {
      // 验证助记词
      if (!bip39.validateMnemonic(mnemonic)) {
        throw Exception('无效的助记词');
      }

      // 从助记词生成种子
      final seed = bip39.mnemonicToSeedHex(mnemonic);

      // 从种子派生私钥
      final master = await ED25519_HD_KEY.getMasterKeyFromSeed(
          HEX.decode(seed));
      final privateKey = HEX.encode(master.key);

      // 从私钥创建以太坊凭证
      final credentials = web3.EthPrivateKey.fromHex(privateKey);
      final address = await credentials.extractAddress();

      // 创建钱包模型
      return wallet_model.Wallet(
        address: address.hex,
        privateKey: privateKey,
        mnemonic: mnemonic,
        chainType: 'ETH',
      );
    } catch (e) {
      throw Exception('创建钱包失败: $e');
    }
  }

  // 通过私钥创建钱包
  Future<wallet_model.Wallet> createWalletFromPrivateKey(
      String privateKey) async {
    try {
      // 验证私钥格式
      if (!privateKey.startsWith('0x')) {
        privateKey = '0x$privateKey';
      }

      // 创建以太坊凭证
      final credentials = web3.EthPrivateKey.fromHex(privateKey);
      final address = await credentials.extractAddress();

      // 创建钱包模型
      return wallet_model.Wallet(
        address: address.hex,
        privateKey: privateKey.startsWith('0x')
            ? privateKey.substring(2)
            : privateKey,
        mnemonic: '', // 从私钥无法恢复助记词
        chainType: 'ETH',
      );
    } catch (e) {
      throw Exception('创建钱包失败: $e');
    }
  }

  // 生成新的随机助记词
  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  // 获取钱包余额
  Future<double> getBalance(String address, String chainType) async {
    try {
      final chainConfig = ChainConfigs.getChainConfig(chainType);
      final client = web3.Web3Client(chainConfig.rpcUrl, http.Client());

      try {
        // 确保地址格式正确
        if (!address.startsWith('0x')) {
          address = '0x$address';
        }

        final ethAddress = web3.EthereumAddress.fromHex(address);
        final balance = await client.getBalance(ethAddress);

        // 将余额从Wei转换为ETH/BNB
        final ethBalance = balance.getValueInUnit(web3.EtherUnit.ether);

        return ethBalance;
      } finally {
        client.dispose();
      }
    } catch (e) {
      print('获取余额失败: $e');
      return 0.0;
    }
  }

  // 获取交易记录
  Future<List<Transaction>> getTransactions(String address,
      String chainType) async {
    try {
      // 确保地址格式正确
      if (!address.startsWith('0x')) {
        address = '0x$address';
      }

      final chainConfig = ChainConfigs.getChainConfig(chainType);

      // 使用对应链的区块浏览器API获取交易记录
      final url = '${chainConfig.apiUrl}?module=account&action=txlist'
          '&address=$address'
          '&startblock=0'
          '&endblock=99999999'
          '&sort=desc'
          '&apikey=${chainConfig.apiKey}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == '1' && data['message'] == 'OK') {
          final List<dynamic> txList = data['result'];

          // 将API返回的交易数据转换为Transaction对象
          return txList.map((tx) {
            final timestamp = int.parse(tx['timeStamp']);
            final value = BigInt.parse(tx['value']);
            final valueInEth = web3.EtherAmount.fromBigInt(
                web3.EtherUnit.wei, value)
                .getValueInUnit(web3.EtherUnit.ether);

            return Transaction(
              hash: tx['hash'],
              from: tx['from'],
              to: tx['to'],
              value: valueInEth,
              status: tx['txreceipt_status'] == '1' ? '成功' : '失败',
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
              gasUsed: int.parse(tx['gasUsed']),
              gasPrice: BigInt.parse(tx['gasPrice']),
              chainType: chainType,
            );
          }).toList();
        }
      }

      return [];
    } catch (e) {
      print('获取交易记录失败: $e');
      return [];
    }
  }

  // 获取代币价格（美元）
  Future<double> getTokenPrice(String chainType) async {
    try {
      final symbol = chainType == 'BSC' ? 'binancecoin' : 'ethereum';
      final url = 'https://api.coingecko.com/api/v3/simple/price?ids=$symbol&vs_currencies=usd';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data[symbol]['usd'].toDouble();
      }

      return 0.0;
    } catch (e) {
      print('获取${chainType}价格失败: $e');
      return 0.0;
    }
  }

  // 发送交易
  Future<String> sendTransaction({
    required String privateKey,
    required String toAddress,
    required double amount,
    required String chainType,
  }) async {
    try {
      final chainConfig = ChainConfigs.getChainConfig(chainType);
      final client = web3.Web3Client(chainConfig.rpcUrl, http.Client());

      try {
        // 创建凭证
        final credentials = web3.EthPrivateKey.fromHex(privateKey);

        // 确保地址格式正确
        if (!toAddress.startsWith('0x')) {
          toAddress = '0x$toAddress';
        }

        // 获取当前Gas价格
        final gasPrice = await client.getGasPrice();

        // 估算Gas用量
        final gasLimit = 21000; // 标准ETH转账的Gas限制

        // 创建交易
        final transaction = web3.Transaction(
          to: web3.EthereumAddress.fromHex(toAddress),
          value: web3.EtherAmount.fromBigInt(
            web3.EtherUnit.ether,
            BigInt.from(amount * 1e18),
          ),
          gasPrice: gasPrice,
          maxGas: gasLimit,
        );

        // 发送交易
        final txHash = await client.sendTransaction(
          credentials,
          transaction,
          chainId: chainConfig.chainId,
        );

        return txHash;
      } finally {
        client.dispose();
      }
    } catch (e) {
      print('发送交易失败: $e');
      throw Exception('发送交易失败: $e');
    }
  }

  // 获取Web3客户端
  web3.Web3Client getWeb3Client(String chainType) {
    final chainConfig = ChainConfigs.getChainConfig(chainType);
    return web3.Web3Client(chainConfig.rpcUrl, http.Client());
  }

  // 获取代币列表
  Future<List<Token>> getTokens(String address, String chainType) async {
    try {
      // 从本地存储获取代币列表
      final prefs = await SharedPreferences.getInstance();
      final key = 'tokens_${chainType}_$address';
      final tokensJson = prefs.getStringList(key) ?? [];

      List<Token> tokens = [];
      for (var tokenJson in tokensJson) {
        final tokenMap = jsonDecode(tokenJson);
        tokens.add(Token.fromJson(tokenMap));
      }

      // 如果没有代币，添加默认代币
      if (tokens.isEmpty) {
        if (chainType == 'ETH') {
          // 为ETH链添加USDT默认代币
          final usdtToken = Token(
            address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', // 以太坊主网USDT合约地址
            name: 'Tether USD',
            symbol: 'USDT',
            decimals: 6,
            balance: 0.0,
            price: 1.0,
            chainType: 'ETH',
          );
          tokens.add(usdtToken);
          await _saveTokens(address, chainType, tokens);
        } else if (chainType == 'BSC') {
          // 为BSC链添加BNB默认代币
          final bnbToken = Token(
            address: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c', // BSC上的BNB合约地址
            name: 'Binance Coin',
            symbol: 'BNB',
            decimals: 18,
            balance: 0.0,
            price: 300.0,
            chainType: 'BSC',
          );
          tokens.add(bnbToken);
          await _saveTokens(address, chainType, tokens);
        }
      }

      // 更新代币余额和价格
      List<Token> updatedTokens = [];
      for (var token in tokens) {
        try {
          final balance = await getTokenBalance(
              address, token.address, chainType);
          final price = await getTokenPrice(token.symbol);
          updatedTokens.add(
              token.copyWithBalance(balance).copyWithPrice(price));
        } catch (e) {
          // 如果获取余额失败，仍然添加原始代币
          updatedTokens.add(token);
        }
      }

      // 保存更新后的代币列表
      await _saveTokens(address, chainType, updatedTokens);

      return updatedTokens;
    } catch (e) {
      print('获取代币列表失败: $e');
      return [];
    }
  }

  // 获取代币信息
  Future<Token> getTokenInfo(String walletAddress, String tokenAddress,
      String chainType) async {
    final client = getWeb3Client(chainType);

    // 创建ERC20合约接口
    final erc20Abi = web3.ContractAbi.fromJson(erc20AbiJson, 'ERC20');
    final tokenContract = web3.DeployedContract(
      erc20Abi,
      web3.EthereumAddress.fromHex(tokenAddress),
    );

    // 获取代币信息
    final nameFunction = tokenContract.function('name');
    final symbolFunction = tokenContract.function('symbol');
    final decimalsFunction = tokenContract.function('decimals');

    final nameResult = await client.call(
      contract: tokenContract,
      function: nameFunction,
      params: [],
    );
    final symbolResult = await client.call(
      contract: tokenContract,
      function: symbolFunction,
      params: [],
    );
    final decimalsResult = await client.call(
      contract: tokenContract,
      function: decimalsFunction,
      params: [],
    );

    final name = nameResult[0].toString();
    final symbol = symbolResult[0].toString();
    final decimals = decimalsResult[0] as BigInt;

    // 获取代币余额
    final balance = await getTokenBalance(
        walletAddress, tokenAddress, chainType);

    // 获取代币价格
    final price = await getTokenPrice(symbol);

    return Token(
      address: tokenAddress,
      name: name,
      symbol: symbol,
      decimals: decimals.toInt(),
      balance: balance,
      price: price,
      chainType: chainType,
    );
  }

  // 获取代币余额
  Future<double> getTokenBalance(String walletAddress, String tokenAddress,
      String chainType) async {
    final client = getWeb3Client(chainType);

    // 创建ERC20合约接口
    final erc20Abi = web3.ContractAbi.fromJson(erc20AbiJson, 'ERC20');
    final tokenContract = web3.DeployedContract(
      erc20Abi,
      web3.EthereumAddress.fromHex(tokenAddress),
    );

    // 获取余额
    final balanceFunction = tokenContract.function('balanceOf');
    final balanceResult = await client.call(
      contract: tokenContract,
      function: balanceFunction,
      params: [web3.EthereumAddress.fromHex(walletAddress)],
    );

    final balance = balanceResult[0] as BigInt;
    final decimalsFunction = tokenContract.function('decimals');
    final decimalsResult = await client.call(
      contract: tokenContract,
      function: decimalsFunction,
      params: [],
    );
    final decimals = decimalsResult[0] as BigInt;

    // 转换为可读余额
    return balance / BigInt.from(10).pow(decimals.toInt());
  }

  // // 获取代币价格
  // Future<double> getTokenPrice(String symbol) async {
  //   try {
  //     // 这里可以接入价格API，如CoinGecko或Binance
  //     // 简化起见，这里返回模拟价格
  //     if (symbol == 'ETH') return 2500.0;
  //     if (symbol == 'BNB') return 300.0;
  //     if (symbol == 'USDT') return 1.0;
  //     if (symbol == 'USDC') return 1.0;
  //     return 0.0;
  //   } catch (e) {
  //     print('获取代币价格失败: $e');
  //     return 0.0;
  //   }
  // }

  // 添加代币
  Future<bool> addToken(String walletAddress, Token token) async {
    try {
      // 获取现有代币列表
      final tokens = await getTokens(walletAddress, token.chainType);

      // 检查代币是否已存在
      final existingToken = tokens.where((t) =>
      t.address.toLowerCase() == token.address.toLowerCase()).toList();
      if (existingToken.isNotEmpty) {
        // 代币已存在，更新余额和价格
        final index = tokens.indexOf(existingToken.first);
        tokens[index] = token;
      } else {
        // 添加新代币
        tokens.add(token);
      }

      // 保存代币列表
      return await _saveTokens(walletAddress, token.chainType, tokens);
    } catch (e) {
      print('添加代币失败: $e');
      return false;
    }
  }

  // 保存代币列表到本地存储
  Future<bool> _saveTokens(String walletAddress, String chainType,
      List<Token> tokens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tokens_${chainType}_$walletAddress';

      final tokensJson = tokens.map((token) => jsonEncode(token.toJson()))
          .toList();
      return await prefs.setStringList(key, tokensJson);
    } catch (e) {
      print('保存代币列表失败: $e');
      return false;
    }
  }

  // ERC20合约ABI
  final String erc20AbiJson = '''
  [
    {
      "constant": true,
      "inputs": [],
      "name": "name",
      "outputs": [{"name": "", "type": "string"}],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "symbol",
      "outputs": [{"name": "", "type": "string"}],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "decimals",
      "outputs": [{"name": "", "type": "uint8"}],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [{"name": "owner", "type": "address"}],
      "name": "balanceOf",
      "outputs": [{"name": "", "type": "uint256"}],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';
}