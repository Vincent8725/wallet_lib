import 'package:flutter/material.dart';
import 'dapp_browser_screen.dart';

class DAppScreen extends StatefulWidget {
  @override
  _DAppScreenState createState() => _DAppScreenState();
}

class _DAppScreenState extends State<DAppScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  late TabController _tabController;
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  
  // 轮播图数据
  final List<Map<String, dynamic>> _banners = [
    {
      'image': 'assets/images/banner1.jpg',
      'url': 'https://app.uniswap.org',
      'title': 'Uniswap V3 - 领先的去中心化交易所'
    }
  ];
  
  // 热门DApp数据
  final List<Map<String, dynamic>> _hotDApps = [
    {'name': 'Uniswap', 'url': 'https://app.uniswap.org', 'icon': 'assets/icons/uniswap.png'},
    {'name': 'OpenSea', 'url': 'https://opensea.io', 'icon': 'assets/icons/opensea.png'},
    {'name': 'Aave', 'url': 'https://app.aave.com', 'icon': 'assets/icons/aave.png'},
    {'name': 'Compound', 'url': 'https://app.compound.finance', 'icon': 'assets/icons/compound.png'},
    {'name': 'dYdX', 'url': 'https://dydx.exchange', 'icon': 'assets/icons/dydx.png'},
    {'name': 'Curve', 'url': 'https://curve.fi', 'icon': 'assets/icons/curve.png'},
    {'name': 'SushiSwap', 'url': 'https://app.sushi.com', 'icon': 'assets/icons/sushiswap.png'},
    {'name': 'Balancer', 'url': 'https://app.balancer.fi', 'icon': 'assets/icons/balancer.png'},
    {'name': '1inch', 'url': 'https://app.1inch.io', 'icon': 'assets/icons/1inch.png'},
    {'name': 'Yearn', 'url': 'https://yearn.finance', 'icon': 'assets/icons/yearn.png'},
  ];
  
  // 收藏的DApp数据
  final List<Map<String, dynamic>> _favoriteDApps = [
    {'name': 'Uniswap', 'url': 'https://app.uniswap.org', 'icon': 'assets/icons/uniswap.png'},
    {'name': 'OpenSea', 'url': 'https://opensea.io', 'icon': 'assets/icons/opensea.png'},
    {'name': 'Aave', 'url': 'https://app.aave.com', 'icon': 'assets/icons/aave.png'},
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 自动轮播
    Future.delayed(Duration.zero, () {
      _startAutoScroll();
    });
  }
  
  void _startAutoScroll() {
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        if (_currentBannerIndex < _banners.length - 1) {
          _currentBannerIndex++;
        } else {
          _currentBannerIndex = 0;
        }
        
        _bannerController.animateToPage(
          _currentBannerIndex,
          duration: Duration(milliseconds: 800),
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
  
  void _navigateToDApp(String url) {
    if (url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DAppBrowserScreen(initialUrl: url),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 地址输入框
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: '输入DApp URL',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (value) {
                        _navigateToDApp(value);
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.arrow_forward),
                    onPressed: () {
                      _navigateToDApp(_urlController.text.trim());
                    },
                  ),
                ],
              ),
            ),
            
            // 轮播图 - 使用Flutter自带的PageView
            Container(
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
                          _navigateToDApp(banner['url']);
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 10),
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
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
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
                                    style: TextStyle(
                                      color: Colors.white,
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
                          margin: EdgeInsets.symmetric(horizontal: 4),
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
            
            SizedBox(height: 16),
            
            // 选项卡
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: '热门'),
                Tab(text: '收藏'),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
            ),
            
            // 选项卡内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 热门DApp
                  _buildDAppGrid(_hotDApps),
                  
                  // 收藏的DApp
                  _buildDAppGrid(_favoriteDApps),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDAppGrid(List<Map<String, dynamic>> dapps) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
            _navigateToDApp(dapp['url']);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
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
              SizedBox(height: 8),
              Text(
                dapp['name'],
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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