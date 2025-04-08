import 'package:flutter/material.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../../../models/wallet.dart';

class CreateWalletScreen extends StatefulWidget {
  @override
  _CreateWalletScreenState createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen>
    with SingleTickerProviderStateMixin {
  final _walletService = WalletService();
  final _storageService = WalletStorageService();
  final _nameController = TextEditingController(); // 添加名称控制器

  // 表单控制器
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();

  late TabController _tabController; // 添加TabController声明

  String _mnemonic = '';
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateMnemonic();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mnemonicController.dispose();
    _privateKeyController.dispose();
    _nameController.dispose(); // 释放控制器
    super.dispose();
  }

  // 生成随机助记词
  void _generateMnemonic() {
    final mnemonic = _walletService.generateMnemonic();
    setState(() {
      _mnemonicController.text = mnemonic;
      _mnemonic = mnemonic; // 同时更新_mnemonic变量
    });
  }

  // 通过助记词创建钱包
  Future<void> _createWalletFromMnemonic() async {
    final mnemonic = _mnemonicController.text.trim();
    if (mnemonic.isEmpty) {
      setState(() {
        _errorMessage = '请输入助记词';
      });
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '请输入钱包名称';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 创建钱包
      final wallet = await _walletService.createWalletFromMnemonic(mnemonic);

      // 添加钱包名称
      final namedWallet = wallet.copyWithName(_nameController.text.trim());

      _navigateToSuccess(namedWallet);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 通过私钥创建钱包
  Future<void> _createWalletFromPrivateKey() async {
    final privateKey = _privateKeyController.text.trim();
    if (privateKey.isEmpty) {
      setState(() {
        _errorMessage = '请输入私钥';
      });
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '请输入钱包名称';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 创建钱包
      final wallet =
          await _walletService.createWalletFromPrivateKey(privateKey);

      // 添加钱包名称
      final namedWallet = wallet.copyWithName(_nameController.text.trim());

      _navigateToSuccess(namedWallet);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 导航到成功页面
  void _navigateToSuccess(Wallet wallet) async {
    // 保存钱包到本地存储
    final success = await _storageService.saveWallet(wallet);

    if (success) {
      // 设置为当前钱包
      await _storageService.setCurrentWallet(wallet.address);

      // 返回到上一页面，并传递成功标志
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = '保存钱包失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('创建钱包'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '助记词'),
            Tab(text: '私钥'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 助记词标签页
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 添加钱包名称输入框
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '钱包名称',
                    hintText: '请输入钱包名称',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                ),
                SizedBox(height: 16),

                TextField(
                  controller: _mnemonicController,
                  decoration: InputDecoration(
                    labelText: '助记词',
                    hintText: '输入12个单词，用空格分隔',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: _generateMnemonic,
                      tooltip: '生成随机助记词',
                    ),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 8),
                Text(
                  '请妥善保管您的助记词，它是恢复钱包的唯一凭证',
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createWalletFromMnemonic,
                  child: _isLoading
                      ? CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text('创建钱包'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),

          // 私钥标签页
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 添加钱包名称输入框
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '钱包名称',
                    hintText: '请输入钱包名称',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                ),
                SizedBox(height: 16),

                TextField(
                  controller: _privateKeyController,
                  decoration: InputDecoration(
                    labelText: '私钥',
                    hintText: '输入钱包私钥',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '请妥善保管您的私钥，它是控制钱包资产的唯一凭证',
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createWalletFromPrivateKey,
                  child: _isLoading
                      ? CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text('导入钱包'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
