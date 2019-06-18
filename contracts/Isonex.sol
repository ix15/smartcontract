pragma solidity ^0.4.20;

import "./ERC20.sol";

contract IsonexTest is ERC20 {

    // 15M + Team (15 * 7 / 90)
    uint256 public tokenCap = 16166667 * 10**18;

    uint256 public minDepositAmount = 0.04 ether;

    bool public depositsHalted = false;
    bool public tradeable = false;

    uint256 public startBlock;
    uint256 public endBlock;

    uint256 public stage1EndBlocksFromStart = 5760; // 24*60*60/15 = 5760 = 1 Day
    uint256 public stage2EndBlocksFromStart = 161280; // 4*7*24*60*60/15 = 161280 = 1 month

    address public primaryWallet;
    address public secondaryWallet;
    address public vestingContract;
    bool private hasVestingContract = false;

    mapping (address => bool) public whitelist;

    // Conversion rate from IX15 to ETH
    struct Price { uint256 numerator; uint256 denominator; } 
    Price public currentPrice;

     // The amount of time that the secondary wallet must wait between price updates
    uint256 public priceUpdateInterval = 1 hours;

    mapping (uint256 => Price) public priceHistory;
    uint256 public currentPriceHistoryIndex = 0;

    // time for each withdrawal is set to the currentPriceHistoryIndex
    struct WithdrawalRequest { uint256 nummberOfTokens; uint256 time; }
    mapping (address => WithdrawalRequest) withdrawalRequests;

    function IsonexTest(address newSecondaryWallet, uint256 newPriceNumerator, uint256 newStartBlock, uint256 newEndBlock) public {
        require(newSecondaryWallet != address(0));
        require(newPriceNumerator > 0);
        name = "IsonexTest";
        symbol = "IX15Test";
        decimals = 18;
        primaryWallet = msg.sender;
        secondaryWallet = newSecondaryWallet;
        whitelist[primaryWallet] = true;
        whitelist[secondaryWallet] = true;
        startBlock = newStartBlock;
        endBlock = newEndBlock;
        currentPrice = Price(newPriceNumerator, 1000);
        currentPriceHistoryIndex = now;
    }
    
    function setVestingContract(address newVestingContract) external onlyPrimaryWallet {
        require(newVestingContract != address(0));
        vestingContract = newVestingContract;
        whitelist[vestingContract] = true;
        hasVestingContract = true;
    }

    // Primary and Secondary wallets may updated the current price. Secondary wallet has time and change size constrainst
    function updatePrice(uint256 newNumerator) external onlyPrimaryAndSecondaryWallets {
        require(newNumerator > 0);
        checkSecondaryWalletRestrictions(newNumerator);

        currentPrice.numerator = newNumerator;

        // After the token sale, map time to new Price
        priceHistory[currentPriceHistoryIndex] = currentPrice;
        currentPriceHistoryIndex = now;
        emit PriceUpdated(newNumerator, currentPrice.denominator);
    }

    // secondaryWallet can only increase price by up to 20% and only every priceUpdateInterval
    function checkSecondaryWalletRestrictions (uint256 newNumerator) view private 
      onlySecondaryWallet priceUpdateIntervalElapsed ifNewNumeratorGreater(newNumerator) {
        uint256 percentageDiff = safeSub(safeMul(newNumerator, 100) / currentPrice.numerator, 100);
        require(percentageDiff <= 20);
    }

    function updatePriceDenominator(uint256 newDenominator) external onlyPrimaryWallet {
        require(block.number > endBlock);
        require(newDenominator > 0);
        currentPrice.denominator = newDenominator;
        // map time to new Price
        priceHistory[currentPriceHistoryIndex] = currentPrice;
        currentPriceHistoryIndex = now;
        emit PriceUpdated(currentPrice.numerator, newDenominator);
    }

    function processDeposit(address participant, uint numberOfTokens) external onlyPrimaryWallet {
        require(block.number < endBlock);
        require(participant != address(0));
        whitelist[participant] = true;
        allocateTokens(participant, numberOfTokens);
        emit Whitelisted(participant);
        emit DepositProcessed(participant, numberOfTokens);
    }

    // When Eether is sent directly to the contract
    function() public payable {
        buyTokensFor(msg.sender);
    }

    function buyTokens() external payable {
        buyTokensFor(msg.sender);
    }
    
    function buyTokensFor(address participant) public payable onlyWhitelist {
        require(!depositsHalted);
        require(participant != address(0));
        require(msg.value >= minDepositAmount);
        require(block.number >= startBlock && block.number < endBlock);

        uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / getDenominator();
        allocateTokens(participant, tokensToBuy);

        // send ether to primaryWallet
        primaryWallet.transfer(msg.value);

        emit UserDeposited(msg.sender, participant, msg.value, tokensToBuy);
    }

    function getDenominator() public constant returns (uint256) {
        uint256 blocksSinceStartBlock = safeSub(block.number, startBlock);
        if (blocksSinceStartBlock < stage1EndBlocksFromStart) { // 24*60*60/15 = 5760 = 1 Day
            return currentPrice.denominator;
        } else if (blocksSinceStartBlock < stage2EndBlocksFromStart ) { // 4*7*24*60*60/15 = 161280 = 1 month
            return safeMul(currentPrice.denominator, 1025) / 1000; // 1.025 usd per token
        } else {
            return safeMul(currentPrice.denominator, 105) / 100; // 1.05 usd per token
        }
    }

    // 7 * 100 / 97 =  7.216494845360825 

    // 7.216494845360825 % of 97 => 7% of 100
    // 7.216494845360825*(X+Y)/100=Y
    // X=100Y/7.216494845360825 - y
    // X = 13.85714285714286 Y - Y
    // X = 12.85714285714286 * Y
    // Y = X/12.85714285714286

    // Or
    // (7 * 100 / 97)*(X+Y)/100=Y
    // ...
    // Y = 7 X / 90

    function allocateTokens(address participant, uint256 numberOfTokens) private {
        require(hasVestingContract);

        // 9.090909090909091% of total allocated for PR, Marketing, Team, Advisors
        uint256 additionalTokens = safeMul(numberOfTokens, 7) / 90;
           
        // check that token cap is not exceeded
        uint256 totalNewTokens = safeAdd(numberOfTokens, additionalTokens);
        require(safeAdd(totalSupply, totalNewTokens) <= tokenCap);
        
        // increase token supply, assign tokens to participant
        totalSupply = safeAdd(totalSupply, totalNewTokens);
        balances[participant] = safeAdd(balances[participant], numberOfTokens);
        balances[vestingContract] = safeAdd(balances[vestingContract], additionalTokens);

        emit Transfer(address(0), participant, numberOfTokens);
        emit Transfer(address(0), vestingContract, additionalTokens);
    }

    function verifyParticipant(address participant) external onlyPrimaryAndSecondaryWallets {
        whitelist[participant] = true;
        emit Whitelisted(participant);
    }

    function requestWithdrawal(uint256 amountOfTokensToWithdraw) external isTradeable onlyWhitelist {
        require(block.number > endBlock);
        require(amountOfTokensToWithdraw > 0);
        address participant = msg.sender;
        require(balanceOf(participant) >= amountOfTokensToWithdraw);
        require(withdrawalRequests[participant].nummberOfTokens == 0); // participant cannot have outstanding withdrawals
        balances[participant] = safeSub(balanceOf(participant), amountOfTokensToWithdraw);
        withdrawalRequests[participant] = WithdrawalRequest({nummberOfTokens: amountOfTokensToWithdraw, time: currentPriceHistoryIndex});
        emit WithdrawalRequested(participant, amountOfTokensToWithdraw);
    }

    function withdraw() external {
        address participant = msg.sender;
        uint256 nummberOfTokens = withdrawalRequests[participant].nummberOfTokens;
        require(nummberOfTokens > 0);
        uint256 requestTime = withdrawalRequests[participant].time;
        Price storage price = priceHistory[requestTime];
        require(price.numerator > 0);
        uint256 etherAmount = safeMul(nummberOfTokens, price.denominator) / price.numerator;
        withdrawalRequests[participant].nummberOfTokens = 0;
		
        // If the contract has enough Ether, then send the Ether to the participant and send the IX15 tokens to the primary wallet
        if (address(this).balance >= etherAmount) {
            // Move the Isonex tokens to the primary wallet
            balances[primaryWallet] = safeAdd(balances[primaryWallet], nummberOfTokens);
            // Send ether from the contract wallet to the participant
            participant.transfer(etherAmount);
            emit Withdrew(participant, etherAmount, nummberOfTokens);
        }
        else {
            // Send the tokens back to the participant
            balances[participant] = safeAdd(balances[participant], nummberOfTokens);
            emit Withdrew(participant, etherAmount, 0); // failed withdrawal
        }
    }

    function checkWithdrawValue(uint256 amountTokensToWithdraw) public constant returns (uint256 etherValue) {
        require(amountTokensToWithdraw > 0);
        require(balanceOf(msg.sender) >= amountTokensToWithdraw);
        uint256 withdrawValue = safeMul(amountTokensToWithdraw, currentPrice.denominator) / currentPrice.numerator;
        require(address(this).balance >= withdrawValue);
        return withdrawValue;
    }

    // allow the primaryWallet or secondaryWallet to add Ether to the contract
    function addLiquidity() external onlyPrimaryAndSecondaryWallets payable {
        require(msg.value > 0);
        emit LiquidityAdded(msg.value);
    }

    // allow the primaryWallet or secondaryWallet to remove Ether from contract
    function removeLiquidity(uint256 amount) external onlyPrimaryAndSecondaryWallets {
        require(amount <= address(this).balance);
        primaryWallet.transfer(amount);
        emit LiquidityRemoved(amount);
    }

    function changePrimaryWallet(address newPrimaryWallet) external onlyPrimaryWallet {
        require(newPrimaryWallet != address(0));
        primaryWallet = newPrimaryWallet;
    }

    function changeSecondaryWallet(address newSecondaryWallet) external onlyPrimaryWallet {
        require(newSecondaryWallet != address(0));
        secondaryWallet = newSecondaryWallet;
    }

    function changePriceUpdateInterval(uint256 newPriceUpdateInterval) external onlyPrimaryWallet {
        priceUpdateInterval = newPriceUpdateInterval;
    }

    function updateStartBlock(uint256 newStartBlock) external onlyPrimaryWallet {
        require(block.number < startBlock);
        require(block.number < newStartBlock);
        startBlock = newStartBlock;
    }

    function updateEndBlock(uint256 newEndBlock) external onlyPrimaryWallet {
        require(block.number < endBlock);
        require(block.number < newEndBlock);
        endBlock = newEndBlock;
    }

    function updateStage1EndBlocksFromStart(uint256 newStage1EndBlocksFromStart) external onlyPrimaryWallet {
        require(block.number < safeAdd(startBlock, stage1EndBlocksFromStart));
        require(block.number < safeAdd(startBlock, newStage1EndBlocksFromStart));
        stage1EndBlocksFromStart = newStage1EndBlocksFromStart;
    }

    function updateStage2EndBlocksFromStart(uint256 newStage2EndBlocksFromStart) external onlyPrimaryWallet {
        require(block.number < safeAdd(startBlock, stage2EndBlocksFromStart));
        require(block.number < safeAdd(startBlock, newStage2EndBlocksFromStart));
        stage2EndBlocksFromStart = newStage2EndBlocksFromStart;
    }

    function haltDeposits() external onlyPrimaryWallet {
        depositsHalted = true;
    }

    function unhaltDeposits() external onlyPrimaryWallet {
        depositsHalted = false;
    }

    function enableTrading() external onlyPrimaryWallet {
        require(block.number > endBlock);
        tradeable = true;
    }

    function claimTokens(address _token) external onlyPrimaryWallet {
        require(_token != address(0));
        ERC20Interface token = ERC20Interface(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(primaryWallet, balance);
    }

    // override transfer and transferFrom to add is tradeable modifier
    function transfer(address _to, uint256 _value) public isTradeable returns (bool success) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public isTradeable returns (bool success) {
        return super.transferFrom(_from, _to, _value);
    }
	
    // I added these, remove them

    function isInWhitelist(address participant) external constant returns (bool) {
        return whitelist[participant];
    }

    // Events

    event PriceUpdated(uint256 numerator, uint256 denominator);
    event DepositProcessed(address indexed participant, uint256 numberOfTokens);
    event Whitelisted(address indexed participant);
    event WithdrawalRequested(address indexed participant, uint256 numberOfTokens);
    event Withdrew(address indexed participant, uint256 etherAmount, uint256 numberOfTokens);
    event LiquidityAdded(uint256 ethAmount);
    event LiquidityRemoved(uint256 ethAmount);
    event UserDeposited(address indexed participant, address indexed beneficiary, uint256 ethValue, uint256 numberOfTokens);

    // Modifiers

    modifier onlyWhitelist {
        require(whitelist[msg.sender]);
        _;
    }

    modifier onlyPrimaryWallet {
        require(msg.sender == primaryWallet);
        _;
    }

    modifier onlySecondaryWallet {
        if (msg.sender == secondaryWallet)
		_;
    }

    modifier onlyPrimaryAndSecondaryWallets {
        require(msg.sender == secondaryWallet || msg.sender == primaryWallet);
        _;
    }

    modifier priceUpdateIntervalElapsed {
        require(safeSub(now, priceUpdateInterval) >= currentPriceHistoryIndex);
        _;
    }

    modifier ifNewNumeratorGreater (uint256 newNumerator) {
        if (newNumerator > currentPrice.numerator)
        _;
    }

    modifier isTradeable { // exempt vestingContract and primaryWallet to allow dev allocations
        require(tradeable || msg.sender == primaryWallet || msg.sender == vestingContract);
        _;
    }
}