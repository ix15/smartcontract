var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic = 'lyrics category autumn offer biology empty clay horse bar wait notable comfort';
module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas:   4500000,

    },
    // ropsten: {
    //   network_id: 3,
    //   host: "localhost",
    //   port:  8545,
    //   gas:   2900000
    // },
    ropsten: {
      network_id: 3,
      gas:   4500000,
      provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/YB2gyYdgEDYofYvis6m7"),
    },
    
    rpc: {
      host: 'localhost',
      post:8080
        }
  }
};
