// 基础调试和工具函数
(function() {
  // 创建调试函数
  window.walletDebug = function(message) {
    console.log('[Wallet Debug]', message);
  };
  
  // 用于存储请求回调的映射
  window.web3Requests = {};
  window.requestId = 0;
  
  // 解析和拒绝请求的辅助函数
  window.resolveWeb3Request = function(id, result) {
    try {
      if (window.web3Requests[id]) {
        var parsedResult = JSON.parse(result);
        window.web3Requests[id].resolve(parsedResult);
        delete window.web3Requests[id];
      }
    } catch(e) {
      console.error('解析结果失败:', e);
    }
  };
  
  window.rejectWeb3Request = function(id, error) {
    try {
      if (window.web3Requests[id]) {
        window.web3Requests[id].reject(new Error(error));
        delete window.web3Requests[id];
      }
    } catch(e) {
      console.error('拒绝请求失败:', e);
    }
  };
  
  // 创建以太坊提供者
  window.initEthereumProvider = function(walletAddress, isConnected) {
    window.ethereum = {
      isMetaMask: true,
      networkVersion: '1',
      chainId: '0x1',
      selectedAddress: walletAddress,
      _events: { accountsChanged: [] },
      isConnected: function() { return isConnected; },
      
      // 启用钱包
      enable: function() {
        walletDebug('调用enable方法');
        return this.request({ method: 'eth_requestAccounts' });
      },
      
      // 请求方法实现
      request: function(payload) {
        walletDebug('请求方法: ' + payload.method);
        
        // 账户请求处理
        if (payload.method === 'eth_requestAccounts' || payload.method === 'eth_accounts') {
          walletDebug('请求账户');
          return new Promise(function(resolve, reject) {
            var id = String(window.requestId++);
            window.web3Requests[id] = { resolve: resolve, reject: reject };
            
            try {
              var message = JSON.stringify({
                id: id,
                method: payload.method,
                params: payload.params || {}
              });
              
              if (window.FlutterWeb3) {
                window.FlutterWeb3.postMessage(message);
              } else {
                reject(new Error('FlutterWeb3通道未定义'));
              }
            } catch(e) {
              reject(e);
            }
          });
        }
        
        // 其他请求处理
        return new Promise(function(resolve, reject) {
          var id = String(window.requestId++);
          window.web3Requests[id] = { resolve: resolve, reject: reject };
          
          try {
            var message = JSON.stringify({
              id: id,
              method: payload.method,
              params: payload.params || {}
            });
            
            if (window.FlutterWeb3) {
              window.FlutterWeb3.postMessage(message);
            } else {
              reject(new Error('FlutterWeb3通道未定义'));
            }
          } catch(e) {
            reject(e);
          }
        });
      },
      
      // 事件监听
      on: function(eventName, callback) {
        if (eventName === 'accountsChanged') {
          this._events.accountsChanged.push(callback);
          callback([walletAddress]);
        }
        return this;
      },
      
      // 移除事件监听
      removeListener: function(eventName, callback) {
        if (eventName === 'accountsChanged' && this._events.accountsChanged) {
          this._events.accountsChanged = this._events.accountsChanged.filter(
            function(cb) { return cb !== callback; }
          );
        }
        return this;
      }
    };
    
    // 兼容旧版Web3
    if (typeof window.web3 === 'undefined') {
      window.web3 = {
        currentProvider: window.ethereum
      };
    }
    
    // 触发provider事件
    if (typeof window.dispatchEvent === 'function') {
      try {
        window.dispatchEvent(new Event('ethereum#initialized'));
      } catch(e) {
        console.error('触发事件失败:', e);
      }
    }
    
    walletDebug('以太坊提供者初始化完成: ' + walletAddress);
    return window.ethereum;
  };
  
  // 通知DApp钱包已连接
  window.notifyWalletConnection = function(walletAddress) {
    try {
      walletDebug('正在通知DApp钱包已连接');
      
      if (!window.ethereum) {
        walletDebug('ethereum对象不存在，尝试初始化');
        window.initEthereumProvider(walletAddress, true);
      }
      
      // 设置地址
      window.ethereum.selectedAddress = walletAddress;
      
      // 触发事件
      if (window.ethereum._events && window.ethereum._events.accountsChanged) {
        walletDebug('触发accountsChanged事件');
        window.ethereum._events.accountsChanged.forEach(function(callback) {
          if (typeof callback === 'function') {
            callback([walletAddress]);
          }
        });
      }
      
      // 更新DApp状态
      try {
        // 设置本地存储
        window.localStorage.setItem('WEB3_CONNECT_CACHED_PROVIDER', '"injected"');
        window.localStorage.setItem('WALLET_CONNECTED', 'true');
        
        // 处理常见UI元素
//        var connectButtons = document.querySelectorAll('button:contains("Connect"), button:contains("连接"), [data-testid="navbar-connect-wallet"]');
//        if (connectButtons.length > 0) {
//          walletDebug('模拟点击连接按钮');
//          connectButtons[0].click();
//        }
        
        // 触发自定义事件
        window.dispatchEvent(new CustomEvent('walletConnected', {
          detail: { address: walletAddress }
        }));
      } catch(e) {
        console.error('更新DApp状态失败:', e);
      }
      
      walletDebug('钱包连接通知完成');
    } catch(e) {
      console.error('通知DApp钱包连接失败:', e);
    }
  };
  
  // 检测DApp是否需要连接钱包
  window.checkDAppNeedsWallet = function() {
    try {
      // 检查页面上是否有连接钱包的按钮
      var hasConnectButton = document.querySelectorAll('button:contains("Connect"), button:contains("连接"), [data-testid="navbar-connect-wallet"]').length > 0;
      
      // 检查是否有Web3相关对象
      var hasWeb3Objects = typeof window.web3 !== 'undefined' || 
                          typeof window.ethereum !== 'undefined' || 
                          document.querySelector('script[src*="web3"]') !== null;
      
      walletDebug('DApp需要钱包检测结果: ' + (hasConnectButton || hasWeb3Objects));
      return hasConnectButton || hasWeb3Objects;
    } catch(e) {
      console.error('检测DApp需求失败:', e);
      return false;
    }
  };
  
  walletDebug('基础脚本已注入');
})();
