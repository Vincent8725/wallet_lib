class Token {
  final String address;
  final String name;
  final String symbol;
  final int decimals;
  final double balance;
  final double price;
  final String chainType;
  final String logoUrl;

  Token({
    required this.address,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.balance,
    required this.price,
    required this.chainType,
    this.logoUrl = '',
  });

  // 从JSON创建Token对象
  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      address: json['address'],
      name: json['name'],
      symbol: json['symbol'],
      decimals: json['decimals'],
      balance: json['balance']?.toDouble() ?? 0.0,
      price: json['price']?.toDouble() ?? 0.0,
      chainType: json['chainType'],
      logoUrl: json['logoUrl'] ?? '',
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'name': name,
      'symbol': symbol,
      'decimals': decimals,
      'balance': balance,
      'price': price,
      'chainType': chainType,
      'logoUrl': logoUrl,
    };
  }

  // 创建余额更新后的Token
  Token copyWithBalance(double newBalance) {
    return Token(
      address: address,
      name: name,
      symbol: symbol,
      decimals: decimals,
      balance: newBalance,
      price: price,
      chainType: chainType,
      logoUrl: logoUrl,
    );
  }

  // 创建价格更新后的Token
  Token copyWithPrice(double newPrice) {
    return Token(
      address: address,
      name: name,
      symbol: symbol,
      decimals: decimals,
      balance: balance,
      price: newPrice,
      chainType: chainType,
      logoUrl: logoUrl,
    );
  }

  // 添加copyWith方法，方便更新价格
  Token copyWith({
    String? name,
    String? symbol,
    int? decimals,
    String? address,
    double? balance,
    double? price,
    String? chainType,
  }) {
    return Token(
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      decimals: decimals ?? this.decimals,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      price: price ?? this.price,
      chainType: chainType ?? this.chainType,
    );
  }
}