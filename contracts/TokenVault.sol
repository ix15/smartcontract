pragma solidity ^0.4.13;

import './Token.sol';

contract TokenValault {

    Token public Contract;
    address beneficiary;

    function TokenValault(address _contractAddress) {
        require(_contractAddress != address(0));
        Contract = Token(_contractAddress);
        beneficiary = msg.sender;
    }

    function checkBalance() constant returns (uint256 tokenBalance) {
        return Contract.balanceOf(this);
    }

    function claim() external {
        require(msg.sender == beneficiary);
        //require(block.number > fundingEndBlock);
        uint256 balance = Contract.balanceOf(this);
        // in reverse order so stages changes don't carry within one claim
        //fourth_release(balance);
        //third_release(balance);
        //second_release(balance);
        //first_release(balance);
        init_claim(balance);
    }

    function init_claim(uint256 balance) {//private atStage(Stages.initClaim) {
        //firstRelease = now + 26 weeks; // assign 4 claiming times
        //secondRelease = firstRelease + 26 weeks;
        //thirdRelease = secondRelease + 26 weeks;
        //fourthRelease = thirdRelease + 26 weeks;
        uint256 amountToTransfer = safeMul(balance, 53846153846) / 100000000000;
        Contract.transfer(beneficiary, amountToTransfer); // now 46.153846154% tokens left
        //nextStage();
    }

    
	function safeMul(uint a, uint b) internal returns (uint) {
		uint c = a * b;
		assert(a == 0 || c / a == b);
		return c;
	}
}