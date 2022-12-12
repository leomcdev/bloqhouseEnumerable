require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-gas-reporter");

const {
  BSCSCAN_API_KEY,
  BSCTESTNET_PRIVATE_KEY_1970,
  BSC_API_URL,
  BSC_MAINNET_PRIVATE_KEY,
} = process.env;

module.exports = {
  solidity: "0.8.4",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    // rinkeby: {
    //   url: ETH_API_URL,
    //   accounts: [`0x${PRIVATE_KEY}`],
    //   allowUnlimitedContractSize: true,
    // },
    BSCTestnet: {
      url: BSC_API_URL,
      accounts: [`0x${BSCTESTNET_PRIVATE_KEY_1970}`],
      allowUnlimitedContractSize: true,
    },
    BSCMAINNET: {
      url: BSC_API_URL,
      accounts: [`0x${BSC_MAINNET_PRIVATE_KEY}`],
      allowUnlimitedContractSize: true,
    },
    // mumbai: {
    //   url: POLYGONSCAN_API_URL,
    //   accounts: [`0x${PRIVATE_KEY}`],
    //   allowUnlimitedContractSize: true,
    // },
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  gasReporter: {
    currency: "USD",
    token: "BNB",
    gasPriceApi: "https://api.bscscan.com/api?module=proxy&action=eth_gasPrice",
    gasPrice: 5,
    coinmarketcap: "0431b70e-ffff-4061-81b0-fa361384d36c",
    // enabled: (process.env.REPORT_GAS) ? true : false
  },
  etherscan: {
    apiKey: BSCSCAN_API_KEY,
  },
};
