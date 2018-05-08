var IsonexTest = artifacts.require("./IsonexTest.sol");
var TokenValault = artifacts.require("./TokenValault.sol");
Promise.allNamed = require("../utils/sequentialPromiseNamed.js")

module.exports = function(deployer, network, accounts) {
  
  // const controlWallet = accounts[1]
  const controlWallet = '0xFE4141fc06A2Af2f8585854dc0A00Fd6925c5D9e';

  var priceNumerator = 1000000; 


	// #blocks = 6*7*24*60*60/15 = 241920
	// var blocksInSixWeeks = 241920; //  + 2666 was 5 days on testnet
	// var fundingStartBlock = 3157163 + 5; // web3.eth.blockNumber + 5; // current block number
	// var fundingEndBlock = fundingStartBlock + blocksInSixWeeks; // TODO: confirm block values



  // var currentBlockNumber = web3.eth.blockNumber;
  
  web3.eth.getBlockNumber(function(error, currentBlockNumber) { 

    if (error) {
      return;
    }

    var blockTime = 15;

    var currentDateTimeInUTC = new Date(Date.now());
  
    var icoStartDateInUTC = new Date(Date.UTC(2018, 4, 8, 7, 0, 0));
    var secondsToIcoStart = (icoStartDateInUTC.getTime() - currentDateTimeInUTC.getTime()) / 1000;
    var blockToIcoStart = secondsToIcoStart / blockTime;
  
    var icoEndDateInUTC = new Date(Date.UTC(2018, 4, 11, 17, 0, 0)); 
    var secondsToIcoEnd = (icoEndDateInUTC.getTime() - currentDateTimeInUTC.getTime()) / 1000;
    var blockToIcoEnd = secondsToIcoEnd / blockTime;
  
    
    var fundingStartBlock = Math.ceil(currentBlockNumber + blockToIcoStart);
    var fundingEndBlock = Math.ceil(currentBlockNumber + blockToIcoEnd);
  
  
    deployer.deploy(IsonexTest, controlWallet, priceNumerator, fundingStartBlock, fundingEndBlock).then(() => {
      return deployer.deploy(TokenValault, IsonexTest.address, fundingEndBlock);
    }).then(() => {
  
      return Promise.allNamed({
        isonexTestI: () => IsonexTest.deployed(),
        tokenValaultI: () => TokenValault.deployed()
      });
  
    }).then(instances => {
      instances.isonexTestI.setVestingContract(instances.tokenValaultI.address);
    });

  });


};