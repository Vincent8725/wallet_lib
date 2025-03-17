class ChainConfig {
  final String id;
  final String name;
  final String symbol;
  final String rpcUrl;
  final String explorerUrl;
  final String apiUrl;
  final String apiKey;
  final int chainId;
  final String iconPath;

  const ChainConfig({
    required this.id,
    required this.name,
    required this.symbol,
    required this.rpcUrl,
    required this.explorerUrl,
    required this.apiUrl,
    required this.apiKey,
    required this.chainId,
    required this.iconPath,
  });
}

class ChainConfigs {
  static const ethereum = ChainConfig(
    id: 'ETH',
    name: 'Ethereum',
    symbol: 'ETH',
    rpcUrl: 'https://eth-mainnet.nodereal.io/v1/1659dfb40aa24bbb8153a677b98064d7',
    explorerUrl: 'https://etherscan.io',
    apiUrl: 'https://api.etherscan.io/api',
    apiKey: 'UQ1WW93CZDMRIDA9ABKMI7VHCEKJS133T4',
    chainId: 1,
    iconPath: 'assets/icons/eth.png',
  );
  
  static const bsc = ChainConfig(
    id: 'BSC',
    name: 'Binance Smart Chain',
    symbol: 'BNB',
    rpcUrl: 'https://bsc-dataseed.binance.org',
    explorerUrl: 'https://bscscan.com',
    apiUrl: 'https://api.bscscan.com/api',
    apiKey: '5K6793HKFUABAAFTY52U9RKEXB6NARJ29C',
    chainId: 56,
    iconPath: 'assets/icons/bnb.png',
  );
  
  static const Map<String, ChainConfig> chains = {
    'ETH': ethereum,
    'BSC': bsc,
  };
  
  static List<ChainConfig> get supportedChains => chains.values.toList();
  
  static ChainConfig getChainConfig(String chainType) {
    return chains[chainType] ?? ethereum;
  }
}