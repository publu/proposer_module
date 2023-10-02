import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import * as dotenv from "dotenv";

dotenv.config();

const mnemonic = process.env.MNEMONIC;
const token = process.env.INFURA_TOKEN;
const etherscanApiKey = process.env.ETHERSCANTOKEN;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: `https://base-goerli.publicnode.com`,
      },
    },
    localhost: {
      url: "http://localhost:8545",
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${token}`,
      accounts: [process.env.MATIC_KEY],
      gasPrice: 25000000000,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${token}`,
      accounts: [process.env.MATIC_KEY],
      gasPrice: 25000000000,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${token}`,
      accounts: [process.env.MATIC_KEY],
      gasPrice: 25000000000,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${token}`,
      accounts: [process.env.MATIC_KEY],
      gasPrice: 41000000000,
    },
    xdai: {
      url: "https://dai.poa.network",
      accounts: [process.env.MATIC_KEY],
      gasPrice: 1000000000,
    },
    volta: {
      url: "https://volta-rpc.energyweb.org",
      accounts: [process.env.MATIC_KEY],
      gasPrice: 1,
    },
    ewc: {
      url: "https://rpc.energyweb.org",
      accounts: [process.env.MATIC_KEY],
      gasPrice: 1,
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org",
      accounts: [process.env.MATIC_KEY],
      gasPrice: 5000000000,
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: [process.env.MATIC_KEY],
      gasPrice: 47000000000,
    },
    polygon: {
      url: "https://polygon-rpc.com/",
      accounts: [process.env.MATIC_KEY]
    },
    celo: {
      url: "https://1rpc.io/celo",
      accounts: [process.env.MATIC_KEY],
      gasPrice: 15000000000,
    },
    baseg: {
      url: "https://base-goerli.publicnode.com",
      accounts: [process.env.MATIC_KEY],
      gasPrice: 300000000,
    },
    sepolia: {
      url: "https://eth-sepolia-public.unifra.io",
      accounts: [process.env.MATIC_KEY],
    },
  },
  etherscan: {
    apiKey: etherscanApiKey,
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: false,
      },
    },
  },
};

export default config;