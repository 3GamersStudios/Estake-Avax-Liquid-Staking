//import OZ Plugins
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");


/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity:{
      version: "0.8.3",
  },
  defaultNetwork: "avaxTest",
  networks:{
    hardhat:{

    },
    avaxTest:{
      url:"https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts:["0x214620e955f9b497eb6a3c4a33650c48a415a127ac1d42f01b23729f255e612d"],
    }
  },

    etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "MBE39UVUYWTFG1UDQW3XPHB4EF6UHBR555",
  },
};

