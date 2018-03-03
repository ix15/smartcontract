var ConvertLib = artifacts.require("./ConvertLib.sol");
var MetaCoin = artifacts.require("./MetaCoin.sol");
var People = artifacts.require("./People.sol");
var DX25Test = artifacts.require("./DX25Test.sol");
var TokenValault = artifacts.require("./TokenValault.sol");
Promise.allNamed = require("../utils/sequentialPromiseNamed.js")

module.exports = function(deployer) {
  // deployer.deploy(ConvertLib);
  // deployer.link(ConvertLib, MetaCoin);
  // deployer.deploy(MetaCoin);
  //deployer.deploy(People);
  
  deployer.deploy(DX25Test).then(() => {
    return deployer.deploy(TokenValault, DX25Test.address);
  }).then(() => {

    return Promise.allNamed({
      dX25TestI: () => DX25Test.deployed(),
      tokenValaultI: () => TokenValault.deployed()
    });

  }).then(instances => {
    instances.dX25TestI.setVestingContract(instances.tokenValaultI.address);
  });

};
