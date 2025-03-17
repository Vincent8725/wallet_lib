import 'package:flutter/material.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/services/wallet_storage_service.dart';
import '../../../models/wallet.dart';

class ImportWalletScreen extends StatefulWidget {
  @override
  _ImportWalletScreenState createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mnemonicController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _nameController = TextEditingController(); // 添加名称控制器
  
  final _walletService = WalletService();
  final _storageService = WalletStorageService();
  
  bool _isLoading = false;
  bool _useMnemonic = true; // 默认使用助记词导入
  
  @override
  void dispose() {
    _mnemonicController.dispose();
    _privateKeyController.dispose();
    _nameController.dispose(); // 释放控制器
    super.dispose();
  }
  
  Future<void> _importWallet() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入钱包名称')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Wallet wallet;
      
      if (_useMnemonic) {
        // 通过助记词导入
        wallet = await _walletService.createWalletFromMnemonic(
          _mnemonicController.text.trim(),
        );
      } else {
        // 通过私钥导入
        wallet = await _walletService.createWalletFromPrivateKey(
          _privateKeyController.text.trim(),
        );
      }
      
      // 添加钱包名称
      final namedWallet = wallet.copyWithName(_nameController.text.trim());
      
      // 保存钱包
      await _storageService.saveWallet(namedWallet);
      
      // 设置为当前钱包
      await _storageService.setCurrentWallet(namedWallet.address);
      
      // 返回上一页
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入钱包失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('导入钱包'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 添加钱包名称输入框
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '钱包名称',
                  hintText: '请输入钱包名称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入钱包名称';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // 选择导入方式
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('助记词'),
                      value: true,
                      groupValue: _useMnemonic,
                      onChanged: (value) {
                        setState(() {
                          _useMnemonic = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('私钥'),
                      value: false,
                      groupValue: _useMnemonic,
                      onChanged: (value) {
                        setState(() {
                          _useMnemonic = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // 助记词或私钥输入
              if (_useMnemonic)
                TextFormField(
                  controller: _mnemonicController,
                  decoration: InputDecoration(
                    labelText: '助记词',
                    hintText: '请输入12个单词的助记词，用空格分隔',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入助记词';
                    }
                    final words = value.trim().split(' ');
                    if (words.length != 12 && words.length != 24) {
                      return '助记词应该包含12个或24个单词';
                    }
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _privateKeyController,
                  decoration: InputDecoration(
                    labelText: '私钥',
                    hintText: '请输入私钥',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入私钥';
                    }
                    if (value.length < 64) {
                      return '私钥格式不正确';
                    }
                    return null;
                  },
                ),
              
              SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _importWallet,
                child: _isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : Text('导入钱包'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}