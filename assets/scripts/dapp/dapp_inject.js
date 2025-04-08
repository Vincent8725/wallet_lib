(function () {
  // 重写 console 方法
  console.log = function (...args) {
    const formatted = args.map(arg =>
      typeof arg === 'object' ? JSON.stringify(arg) : arg
    ).join(' ');

    window.Logger.postMessage(formatted);
  };

  // 事件监听器集合
  const eventListeners = {
    accountsChanged: [],
    chainChanged: [],
    connect: [],
    disconnect: [],
    requestError: []
  };

  console.log("DApp注入脚本开始执行");

  // 模拟ethereum对象
  window.ethereum = {
    isMetaMask: true,
    chainId: "0x1",
    selectedAddress: "",
    networkVersion: "1",
    _events: eventListeners,
    // 添加MetaMask特有属性
    _metamask: {
      isUnlocked: true,
      isEnabled: true,
      isApproved: true
    },

    // 核心方法
    enable: function () {
      console.log("调用enable方法");
      return this.request({ method: "eth_requestAccounts" });
    },

    request: async function (payload) {
      console.log("请求方法:", payload.method, payload.params);
      
      // 特殊处理eth_accounts和eth_requestAccounts
      if (payload.method === "eth_accounts" || payload.method === "eth_requestAccounts") {
        if (this.selectedAddress) {
          console.log("直接返回账户:", [this.selectedAddress]);
          return Promise.resolve([this.selectedAddress]);
        }
      }
      
      // 特殊处理wallet_requestPermissions
      if (payload.method === "wallet_requestPermissions") {
        if (this.selectedAddress) {
          console.log("处理权限请求，返回账户权限:", this.selectedAddress);
          return Promise.resolve([{
            parentCapability: "eth_accounts",
            caveats: [{
              type: "restrictReturnedAccounts",
              value: [this.selectedAddress]
            }]
          }]);
        }
      }
      
      // 特殊处理某些请求，避免不必要的Flutter通信
      if (payload.method === "eth_chainId") {
        return Promise.resolve(this.chainId);
      } else if (payload.method === "net_version") {
        return Promise.resolve(this.chainId.replace("0x", ""));
      }
      
      return new Promise((resolve, reject) => {
        try {
          // 生成唯一请求ID
          const requestId = Date.now().toString();

          // 存储回调函数
          window._web3Callbacks = window._web3Callbacks || {};
          window._web3Callbacks[requestId] = { resolve, reject };

          // 转发请求到Flutter
          if (window.FlutterWeb3) {
            window.FlutterWeb3.postMessage(
              JSON.stringify({
                id: requestId,
                method: payload.method,
                params: payload.params || [],
                chainId: this.chainId
              })
            );
            console.log("请求已发送到Flutter:", requestId);
          } else {
            console.error("FlutterWeb3通道未定义");
            reject(new Error("FlutterWeb3通道未定义"));
          }
        } catch (e) {
          console.error("请求处理错误:", e);
          reject(e);
        }
      });
    },

    // 事件监听
    on: function (event, callback) {
      console.log("注册事件监听:", event);
      if (event in eventListeners) {
        eventListeners[event].push(callback);

        // 如果是accountsChanged事件，且已有地址，立即触发一次
        if (event === "accountsChanged" && this.selectedAddress) {
          setTimeout(function() { callback([window.ethereum.selectedAddress]); }, 0);
        }
        // 如果是chainChanged事件，立即触发一次
        if (event === "chainChanged") {
          setTimeout(function() { callback(window.ethereum.chainId); }, 0);
        }
        // 如果是connect事件，且已有地址，立即触发一次
        if (event === "connect" && this.selectedAddress) {
          setTimeout(function() { callback({ chainId: window.ethereum.chainId }); }, 0);
        }
      }
      return this;
    },

    // 移除事件监听
    removeListener: function (event, callback) {
      if (event in eventListeners) {
        const index = eventListeners[event].indexOf(callback);
        if (index !== -1) {
          eventListeners[event].splice(index, 1);
        }
      }
      return this;
    },

    // 触发事件（由宿主App调用）
    triggerEvent: function (eventName, data) {
      console.log("触发事件:", eventName, data);
      if (eventName in eventListeners) {
        for (let i = 0; i < eventListeners[eventName].length; i++) {
          try {
            eventListeners[eventName][i](data);
          } catch (e) {
            console.error("事件回调执行错误:", e);
          }
        }
      }
    },

    // 添加兼容方法
    send: function(method, params) {
      if (typeof method === 'string') {
        return this.request({ method, params });
      } else {
        return this.request(method);
      }
    },
    
    sendAsync: function(payload, callback) {
      this.request(payload)
        .then(result => callback(null, { id: payload.id, jsonrpc: '2.0', result }))
        .catch(error => callback(error));
    },
    
    // 检查是否已连接
    isConnected: function () {
      return this.selectedAddress !== null && this.selectedAddress !== "";
    }
  };

  // 处理请求响应
  window.resolveWeb3Request = function (requestId, result) {
    console.log("解析Web3请求:", requestId, result);
    if (window._web3Callbacks && window._web3Callbacks[requestId]) {
      const callback = window._web3Callbacks[requestId];
      if (callback && callback.resolve) {
        callback.resolve(typeof result === 'string' ? JSON.parse(result) : result);
        delete window._web3Callbacks[requestId];
      }
    }
  };

  window.rejectWeb3Request = function (requestId, error) {
    console.log("拒绝Web3请求:", requestId, error);
    if (window._web3Callbacks && window._web3Callbacks[requestId]) {
      const callback = window._web3Callbacks[requestId];
      if (callback && callback.reject) {
        callback.reject(new Error(error));
        delete window._web3Callbacks[requestId];
      }
    }
  };

  // 兼容旧版web3
  if (typeof window.web3 === "undefined") {
    window.web3 = {
      currentProvider: window.ethereum
    };
  };

  window.initialize = function (chainId, address) {
    window.ethereum.chainId = chainId;
    window.ethereum.networkVersion = chainId.replace("0x", "");
    window.ethereum.selectedAddress = address;
    console.log("初始化Web3:", chainId, window.ethereum.networkVersion, address);
    
    // 设置本地存储，帮助DApp识别连接状态
    try {
      localStorage.setItem("metamask-is-connected", "true");
      localStorage.setItem("metamask-is-unlocked", "true");
      localStorage.setItem("metamask-connected-wallet", address);
      localStorage.setItem("walletconnect", JSON.stringify({"connected":true,"accounts":[address]}));
      localStorage.setItem("WEB3_CONNECT_CACHED_PROVIDER", '"injected"');
    } catch(e) {
      console.error("设置本地存储失败:", e);
    }
    
    // 触发事件
    if (address) {
      window.ethereum.triggerEvent("accountsChanged", [address]);
      window.ethereum.triggerEvent("connect", { chainId: chainId });
    }
  };

  // 移除 dappController 对象，直接使用 window 方法

  console.log("DApp注入脚本执行完成");
})();

