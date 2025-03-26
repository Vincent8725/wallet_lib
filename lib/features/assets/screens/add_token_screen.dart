import 'package:flutter/material.dart';
import '../../../core/services/wallet_service.dart';
import '../../../models/token.dart';

class AddTokenScreen extends StatefulWidget {
  final String address;
  final String chainType;

  const AddTokenScreen({
    Key? key,
    required this.address,
    required this.chainType,
  }) : super(key: key);

  @override
  _AddTokenScreenState createState() => _AddTokenScreenState();
}

class _AddTokenScreenState extends State<AddTokenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenAddressController = TextEditingController();
  final _walletService = WalletService();

  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  Token? _foundToken;

  @override
  void dispose() {
    _tokenAddressController.dispose();
    super.dispose();
  }

  Future<void> _searchToken() async {
    final tokenAddress = _tokenAddressController.text.trim();
    if (tokenAddress.isEmpty) {
      setState(() {
        _errorMessage = '请输入代币合约地址';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundToken = null;
    });

    try {
      final token = await _walletService.getTokenInfo(
        widget.address,
        tokenAddress,
        widget.chainType,
      );

      setState(() {
        _foundToken = token;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '查询代币失败: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _addToken() async {
    if (_foundToken == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _walletService.addToken(
        widget.address,
        _foundToken!,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('代币添加成功'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = '添加代币失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '添加代币失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加代币'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tokenAddressController,
                decoration: InputDecoration(
                  labelText: '代币合约地址',
                  hintText: '输入代币的合约地址',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _isSearching ? null : _searchToken,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入代币合约地址';
                  }
                  if (!value.startsWith('0x') || value.length != 42) {
                    return '请输入有效的合约地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_isSearching)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_foundToken != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '代币信息',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTokenInfoRow('名称', _foundToken!.name),
                        _buildTokenInfoRow('符号', _foundToken!.symbol),
                        _buildTokenInfoRow(
                            '精度', _foundToken!.decimals.toString()),
                        _buildTokenInfoRow('合约地址', _foundToken!.address),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _addToken,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('添加代币'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
