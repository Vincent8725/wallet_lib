(function () {
  // 重写 console 方法
  console.log = function (...args) {
    const formatted = args.map(arg =>
      typeof arg === 'object' ? JSON.stringify(arg) : arg
    ).join(' ');

    window.Logger.postMessage(formatted);
  };

  // 定义默认链参数（以太坊主网）
  const DEFAULT_CHAIN = {
    chainId: "0x1",
    chainName: "Ethereum Mainnet",
    rpcUrl: "https://mainnet.infura.io/v3/your-project-id",
    blockExplorerUrl: "https://etherscan.io"
  };

  // 存储当前链和账户信息
  let currentChain = DEFAULT_CHAIN;
  let selectedAddress = null;

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
    chainId: currentChain.chainId,
    selectedAddress: selectedAddress,
    networkVersion: currentChain.chainId.replace("0x", ""),
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
        if (selectedAddress) {
          console.log("直接返回账户:", [selectedAddress]);
          return Promise.resolve([selectedAddress]);
        }
      }
      
      // 特殊处理wallet_requestPermissions
      if (payload.method === "wallet_requestPermissions") {
        if (selectedAddress) {
          console.log("处理权限请求，返回账户权限:", selectedAddress);
          return Promise.resolve([{
            parentCapability: "eth_accounts",
            caveats: [{
              type: "restrictReturnedAccounts",
              value: [selectedAddress]
            }]
          }]);
        }
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
                chainId: currentChain.chainId
              })
            );
            console.log("请求已发送到Flutter:", requestId);
          } else {
            console.error("FlutterWeb3通道未定义");
            reject(new Error("FlutterWeb3通道未定义"));
          }

          // 特殊处理某些请求
          if (payload.method === "eth_chainId") {
            resolve(currentChain.chainId);
          } else if (payload.method === "net_version") {
            resolve(currentChain.chainId.replace("0x", ""));
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
        if (event === "accountsChanged" && selectedAddress) {
          setTimeout(function () { callback([selectedAddress]); }, 0);
        }
        // 如果是chainChanged事件，立即触发一次
        if (event === "chainChanged") {
          setTimeout(function () { callback(currentChain.chainId); }, 0);
        }
        // 如果是connect事件，且已有地址，立即触发一次
        if (event === "connect" && selectedAddress) {
          setTimeout(function () { callback({ chainId: currentChain.chainId }); }, 0);
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

    // 切换链
    switchChain: async function (chainId) {
      // 通知宿主App切换链
      await this.request({ method: "wallet_switchEthereumChain", params: [{ chainId: chainId }] });
      this.chainId = chainId;
      this.triggerEvent("chainChanged", chainId);
    },

    // 连接钱包
    connect: async function () {
      const accounts = await this.request({ method: "eth_requestAccounts" });
      selectedAddress = accounts[0];
      this.selectedAddress = selectedAddress;
      this.triggerEvent("accountsChanged", [selectedAddress]);
      this.triggerEvent("connect", { chainId: currentChain.chainId });
      return accounts;
    },

    // 检查是否已连接
    isConnected: function () {
      return selectedAddress !== null;
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
  }

  // 暴露公共方法
  window.dappController = {
    setChain: function (chain) {
      console.log("设置链:", chain, window.ethereum.chainId);
      currentChain = chain;
      if(window.ethereum.chainId == chain.chainId) return;
      window.ethereum.chainId = chain.chainId;
      window.ethereum.networkVersion = chain.chainId.replace("0x", "");
      // 触发链变更事件
      window.ethereum.triggerEvent("chainChanged", chain.chainId);
    },
    
    switchChain: function (chainId) {
      console.log("切换链:", chainId, window.ethereum.chainId);
      if(window.ethereum.chainId == chainId) return;
      window.ethereum.chainId = chainId;
      window.ethereum.networkVersion = chainId.replace("0x", "");
      // 触发链变更事件
      window.ethereum.triggerEvent("chainChanged", chainId);
    },
    
    setAccount: function (address) {
      if (!address) return;
      console.log("设置账户:", address, window.ethereum.selectedAddress);
      if(window.ethereum.selectedAddress == address) return;
      
      selectedAddress = address;
      window.ethereum.selectedAddress = address;
      console.log("设置账户完成:", window.ethereum.selectedAddress, window.ethereum.chainId);
      
      // 设置本地存储，帮助DApp识别连接状态
      try {
        localStorage.setItem("metamask-is-connected", "true");
        localStorage.setItem("metamask-is-unlocked", "true");
        localStorage.setItem("metamask-connected-wallet", address);
        localStorage.setItem("walletconnect", JSON.stringify({"connected":true,"accounts":[address]}));
        localStorage.setItem("WEB3_CONNECT_CACHED_PROVIDER", '"injected"');
        console.log("设置本地存储完成");
      } catch(e) {
        console.error("设置本地存储失败:", e);
      }
      
      // 触发账户变更事件
      window.ethereum.triggerEvent("accountsChanged", [address]);
      
      // 触发连接事件
      window.ethereum.triggerEvent("connect", { chainId: window.ethereum.chainId });
    },

    autoConnect: function (chainId,address) {
      console.log("开始自动连接流程");
      window.ethereum.chainId = currentChain.id = chainId;
      window.ethereum.selectedAddress = selectedAddress = address;
      
       window.ethereum.request({
         method: 'wallet_requestPermissions',
         params: [{ eth_accounts: {} }]
       }).then(function(permissions) {
         console.log("权限请求成功:", permissions);
         window.ethereum.connect();
         // 权限请求成功后，再次请求账户
         window.ethereum.request({ method: 'eth_requestAccounts' })
           .then(accounts => {
             console.log("账户请求成功:", accounts);
             // 再次触发事件
             window.ethereum.triggerEvent("connect", { chainId: currentChain.chainId });
             window.ethereum.triggerEvent("accountsChanged", accounts);
           })
           .catch(error => console.error("账户请求失败:", error));
       }).catch(function(error) {
         console.error("权限请求失败:", error);
       });
    }

  };

  console.log("DApp注入脚本执行完成");
})();

