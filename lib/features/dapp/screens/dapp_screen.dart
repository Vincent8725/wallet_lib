import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dapp_browser_screen.dart';
import '../../../core/services/wallet_storage_service.dart';

class DAppScreen extends StatefulWidget {
  const DAppScreen({super.key});

  @override
  _DAppScreenState createState() => _DAppScreenState();
}

class _DAppScreenState extends State<DAppScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  late TabController _tabController;
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  
  // 从配置文件加载的数据
  List<Map<String, dynamic>> _banners = [];
  Map<String, List<Map<String, dynamic>>> _dappCategories = {};
  List<String> _tabNames = [];
  bool _isLoading = true;
  
  // 添加钱包服务
  final WalletStorageService _walletService = WalletStorageService();
  String _currentChainId = ''; // 当前钱包的链ID
  
  @override
  void initState() {
    super.initState();
    _loadCurrentWallet();
    _loadDAppConfig();
  }
  
  // 加载当前钱包信息
  Future<void> _loadCurrentWallet() async {
    try {
      final wallet = await _walletService.getCurrentWallet();
      if (wallet != null) {
        setState(() {
          // 将链类型转换为链ID格式
          _currentChainId = _getChainIdFromType(wallet.chainType);
        });
      }
    } catch (e) {
      dev.log('加载当前钱包失败: $e');
    }
  }

  // 将链类型转换为链ID
  String _getChainIdFromType(String chainType) {
    // 根据链类型返回对应的链ID
    switch (chainType.toUpperCase()) {
      case 'ETH':
        return '0x1';
      case 'BSC':
        return '0x38';
      default:
        return '0x1'; // 默认以太坊主网
    }
  }

  // 根据链ID获取链类型
  String _getChainTypeFromId(String chainId) {
    switch (chainId) {
      case '0x1':
        return 'ETH';
      case '0x38':
        return 'BSC';
      default:
        return 'ETH';
    }
  }

  // 加载DApp配置
  Future<void> _loadDAppConfig() async {
    try {
      // 读取配置文件
      final String jsonString = await rootBundle.loadString('assets/config/dapps.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      setState(() {
        // 加载轮播图数据
        if (jsonData.containsKey('banners')) {
          _banners = List<Map<String, dynamic>>.from(jsonData['banners']);
        }

        // 加载DApp分类数据
        _dappCategories = {};
        _tabNames = [];

        // 遍历所有键，排除'banners'
        jsonData.forEach((key, value) {
          if (key != 'banners') {
            _tabNames.add(key);
            _dappCategories[key] = List<Map<String, dynamic>>.from(value);
          }
        });

        // 初始化TabController
        _tabController = TabController(length: _tabNames.length, vsync: this);
        _isLoading = false;
      });

      // 启动轮播
      Future.delayed(Duration.zero, () {
        _startAutoScroll();
      });
    } catch (e) {
      dev.log('加载DApp配置失败: $e');
      setState(() {
        _isLoading = false;
        // 设置默认值
        _tabController = TabController(length: 1, vsync: this);
      });
    }
  }

  void _startAutoScroll() {
    if (_banners.isEmpty) return;

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (_currentBannerIndex < _banners.length - 1) {
          _currentBannerIndex++;
        } else {
          _currentBannerIndex = 0;
        }

        _bannerController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );

        _startAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tabController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  // 修改导航方法，添加链ID检查
  void _navigateToDApp(Map<String, dynamic> dapp) {
    final String url = dapp['url'] ?? '';
    final String name = dapp['name'] ?? '';
    final String dappChainId = dapp['chainId'] ?? '0x1';

    if (url.isEmpty) return;

    // 检查链ID是否匹配
    if (_currentChainId != dappChainId) {
      _showChainMismatchDialog(dapp);
    } else {
      // 链ID匹配，直接打开DApp，并传递chainId参数
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DAppBrowserScreen(
            initialUrl: url,
            name: name,
            chainId: dappChainId, // 添加chainId参数
          ),
        ),
      );
    }
  }

  // 显示链不匹配对话框
  void _showChainMismatchDialog(Map<String, dynamic> dapp) {
    final String dappName = dapp['name'] ?? 'DApp';
    final String dappChainId = dapp['chainId'] ?? '0x1';
    final String dappChainType = _getChainTypeFromId(dappChainId);
    final String currentChainType = _getChainTypeFromId(_currentChainId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('链不匹配'),
        content: Text(
          '$dappName需要在${dappChainType}链上运行，但您当前选择的是${currentChainType}链。\n\n'
          '您想切换到${dappChainType}链并继续吗？'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // 切换链
              await _switchChain(dappChainType);

              // 切换后再次检查并打开DApp
              if (_currentChainId == dappChainId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DAppBrowserScreen(
                      initialUrl: dapp['url'],
                      name: dapp['name'] ?? '',
                      chainId: dappChainId, // 添加chainId参数
                    ),
                  ),
                );
              }
            },
            child: const Text('切换并继续'),
          ),
        ],
      ),
    );
  }

  // 切换链方法
  Future<void> _switchChain(String chainType) async {
    try {
      // 获取当前钱包
      final wallet = await _walletService.getCurrentWallet();

      if (wallet != null) {
        // 更新钱包链类型
        final updatedWallet = wallet.copyWithChainType(chainType);

        // 保存更新后的钱包
        await _walletService.saveWallet(updatedWallet);

        // 设置为当前钱包
        await _walletService.setCurrentWallet(updatedWallet.address);

        // 更新当前链ID
        setState(() {
          _currentChainId = _getChainIdFromType(chainType);
        });

        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已切换到 $chainType 链')),
        );
      }
    } catch (e) {
      dev.log('切换链失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换链失败: $e')),
      );
    }
  }

  // 处理URL输入
  void _handleUrlInput(String url) {
    if (url.isEmpty) return;

    // 导航到DApp，使用当前链ID
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DAppBrowserScreen(
          initialUrl: url,
          chainId: _currentChainId, // 添加当前链ID
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 36, // 设置固定高度
          child: TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: '输入DApp URL',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18), // 减小图标尺寸
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none, // 保持无边框
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), // 减小垂直内边距
              isDense: true, // 使输入框更紧凑
            ),
            style: const TextStyle(fontSize: 13), // 减小字体大小
            onSubmitted: (value) {
              _handleUrlInput(value);
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              _handleUrlInput(_urlController.text.trim());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // 轮播图 - 使用Flutter自带的PageView
            _banners.isEmpty
            ? const SizedBox(height: 180)
            : SizedBox(
              height: 180,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _bannerController,
                    itemCount: _banners.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentBannerIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final banner = _banners[index];
                      return GestureDetector(
                        onTap: () {
                          _navigateToDApp(banner);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[300],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  banner['image'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: Icon(Icons.image, size: 50, color: Colors.grey[600]),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black87, Colors.transparent],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    banner['title'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // 显示链标识
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getChainTypeFromId(banner['chainId'] ?? '0x1'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // 指示器
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_banners.length, (index) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentBannerIndex == index
                                ? Theme.of(context).primaryColor
                                : Colors.grey[400],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 选项卡 - 从配置文件中获取
            if (_tabNames.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: TabBar(
                  controller: _tabController,
                  tabs: _tabNames.map((name) => Tab(text: name.toUpperCase(), height: 30,)).toList(),
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  isScrollable: true, // 设置为true使标签可滚动，从而实现左对齐
                  indicatorSize: TabBarIndicatorSize.label, // 指示器宽度与标签文本同宽
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8), // 标签间距
                  dividerColor: Colors.transparent, // 去除分割线
                  padding: const EdgeInsets.symmetric(horizontal: 4), // 设置TabBar的内边距为零
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
                  tabAlignment: TabAlignment.start,
                ),
              ),

            // 选项卡内容
            Expanded(
              child: _tabNames.isEmpty 
              ? const Center(child: Text('没有可用的DApp'))
              : TabBarView(
                controller: _tabController,
                children: _tabNames.map((name) {
                  // 获取当前分类的DApp列表
                  final dapps = _dappCategories[name] ?? [];
                  return _buildDAppGrid(dapps);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDAppGrid(List<Map<String, dynamic>> dapps) {
    if (dapps.isEmpty) {
      return const Center(child: Text('暂无DApp'));
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: dapps.length,
      itemBuilder: (context, index) {
        final dapp = dapps[index];
        return GestureDetector(
          onTap: () {
            _navigateToDApp(dapp);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        dapp['icon'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              dapp['name'].substring(0, 1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
  
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dapp['name'],
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}