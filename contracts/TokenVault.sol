pragma solidity ^0.4.20;

import "./ERC20Interface.sol";

contract TokenVault {

    ERC20Interface public IsonexContract;
    address beneficiary;
    uint256 public endBlock;

    uint256 public firstRelease;
    uint256 public secondRelease;
    uint256 public thirdRelease;
    uint256 public fourthRelease;

    modifier atStage(Stages _stage) {
        if(stage == _stage) _;
    }

    Stages public stage = Stages.initClaim;

    enum Stages {
        initClaim,
        firstRelease,
        secondRelease,
        thirdRelease,
        fourthRelease
    }

    function TokenVault(address _contractAddress, uint256 endBlockInput) public {
        require(_contractAddress != address(0));
        IsonexContract = ERC20Interface(_contractAddress);
        beneficiary = msg.sender;
        endBlock = endBlockInput;
    }

    function changeBeneficiary(address newBeneficiary) external {
        require(newBeneficiary != address(0));
        require(msg.sender == beneficiary);
        beneficiary = newBeneficiary;
    }

    function updateEndBlock(uint256 newEndBlock) external {
        require(msg.sender == beneficiary);
        require(block.number < endBlock);
        require(block.number < newEndBlock);
        endBlock = newEndBlock;
    }

    function checkBalance() public constant returns (uint256 tokenBalance) {
        return IsonexContract.balanceOf(this);
    }

    function claim() external {
        require(msg.sender == beneficiary);
        require(block.number > endBlock);
        uint256 balance = IsonexContract.balanceOf(this);
        // in reverse order so stages changes don't carry within one claim
        fourth_release(balance);
        third_release(balance);
        second_release(balance);
        first_release(balance);
        init_claim(balance);
    }

    function nextStage() private {
        stage = Stages(uint256(stage) + 1);
    }

    // 7.216494845360825 % (7 * 100 / 97) of all IX15 tokens are held by this contract

    // first claim releaes 2 units for expenses and 1 unit for team (3 / 7 = 0.4285714285714286 % of contract balance)
    // second claim releases is 1 unit
    // third claim releases is 1 unit
    // fourth claim releases is 1 unit
    // fifth claim releases is 1 unit
    function init_claim(uint256 balance) private atStage(Stages.initClaim) {
        firstRelease = now + 26 weeks; // assign 4 claiming times
        secondRelease = firstRelease + 26 weeks;
        thirdRelease = secondRelease + 26 weeks;
        fourthRelease = thirdRelease + 26 weeks;
        uint256 amountToTransfer = safeMul(balance, 4285714285714286) / 10000000000000000;
        IsonexContract.transfer(beneficiary, amountToTransfer); // now 46.153846154% tokens left
        nextStage();
    }

    function first_release(uint256 balance) private atStage(Stages.firstRelease) {
        require(now > firstRelease);
        uint256 amountToTransfer = balance / 4;
        IsonexContract.transfer(beneficiary, amountToTransfer); // send 25 % of team releases
        nextStage();
    }

    function second_release(uint256 balance) private atStage(Stages.secondRelease) {
        require(now > secondRelease);
        uint256 amountToTransfer = balance / 3;
        IsonexContract.transfer(beneficiary, amountToTransfer); // send 25 % of team releases
        nextStage();
    }

    function third_release(uint256 balance) private atStage(Stages.thirdRelease) {
        require(now > thirdRelease);
        uint256 amountToTransfer = balance / 2;
        IsonexContract.transfer(beneficiary, amountToTransfer); // send 25 % of team releases
        nextStage();
    }
    
    function fourth_release(uint256 balance) private atStage(Stages.fourthRelease) {
        require(now > fourthRelease);
        IsonexContract.transfer(beneficiary, balance); // send remaining 25 % of team releases
    }

    function claimOtherTokens(address _token) external {
        require(msg.sender == beneficiary);
        require(_token != address(0));
        ERC20Interface token = ERC20Interface(_token);
        require(token != IsonexContract);
        uint256 balance = token.balanceOf(this);
        token.transfer(beneficiary, balance);
    }

    function safeMul(uint a, uint b) pure internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }
}