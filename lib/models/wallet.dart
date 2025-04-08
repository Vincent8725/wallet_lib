class Wallet {
  final String address;
  final String privateKey;
  final String mnemonic;
  final String name;
  final String chainType;
  final double balance;
  final Map<String, double> balances; // 添加 balances 字段
  
  Wallet({
    required this.address,
    required this.privateKey,
    required this.mnemonic,
    this.name = '',
    required this.chainType,
    this.balance = 0.0,
    Map<String, double>? balances, // 添加 balances 参数
  }) : balances = balances ?? {chainType: balance}; // 初始化 balances
  
  // 复制并更新名称
  Wallet copyWithName(String name) {
    return Wallet(
      address: address,
      privateKey: privateKey,
      mnemonic: mnemonic,
      name: name,
      chainType: chainType,
      balance: balance,
      balances: balances, // 保留 balances
    );
  }
  
  // 复制并更新余额
  Wallet copyWithBalance(String chainType, double balance) {
    final updatedBalances = Map<String, double>.from(balances);
    updatedBalances[chainType] = balance;
    
    return Wallet(
      address: address,
      privateKey: privateKey,
      mnemonic: mnemonic,
      name: name,
      chainType: this.chainType,
      balance: chainType == this.chainType ? balance : this.balance,
      balances: updatedBalances, // 更新 balances
    );
  }
  
  // 复制并更新链类型
  Wallet copyWithChainType(String chainType) {
    return Wallet(
      address: address,
      privateKey: privateKey,
      mnemonic: mnemonic,
      name: name,
      chainType: chainType,
      balance: balances[chainType] ?? balance, // 使用新链类型的余额
      balances: balances, // 保留 balances
    );
  }
  
  // 获取短地址
  String get shortAddress {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  // 获取指定链的余额
  double getBalance(String chainType) {
    return balances[chainType] ?? 0.0;
  }
  
  // 添加 toJson 和 fromJson 方法
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'privateKey': privateKey,
      'mnemonic': mnemonic,
      'name': name,
      'chainType': chainType,
      'balance': balance,
      'balances': balances,
    };
  }
  
  factory Wallet.fromJson(Map<String, dynamic> json) {
    final balancesJson = json['balances'];
    Map<String, double> balances = {};
    
    if (balancesJson != null) {
      balancesJson.forEach((key, value) {
        balances[key] = (value is int) ? value.toDouble() : value;
      });
    }
    
    return Wallet(
      address: json['address'],
      privateKey: json['privateKey'],
      mnemonic: json['mnemonic'],
      name: json['name'] ?? '',
      chainType: json['chainType'],
      balance: (json['balance'] is int) ? (json['balance'] as int).toDouble() : json['balance'],
      balances: balances,
    );
  }
}