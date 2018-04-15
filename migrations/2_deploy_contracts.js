var ConvertLib = artifacts.require("./ConvertLib.sol");
var MetaCoin = artifacts.require("./MetaCoin.sol");
var People = artifacts.require("./People.sol");
var IsonexTest = artifacts.require("./IsonexTest.sol");
var TokenValault = artifacts.require("./TokenValault.sol");
Promise.allNamed = require("../utils/sequentialPromiseNamed.js")

module.exports = function(deployer, network, accounts) {
  // deployer.deploy(ConvertLib);
  // deployer.link(ConvertLib, MetaCoin);
  
  // const controlWallet = accounts[1]
  const controlWallet = '0xFE4141fc06A2Af2f8585854dc0A00Fd6925c5D9e';

  deployer.deploy(IsonexTest, controlWallet).then(() => {
    return deployer.deploy(TokenValault, IsonexTest.address);
  }).then(() => {

    return Promise.allNamed({
      isonexTestI: () => IsonexTest.deployed(),
      tokenValaultI: () => TokenValault.deployed()
    });

  }).then(instances => {
    instances.isonexTestI.setVestingContract(instances.tokenValaultI.address);
  });

};
