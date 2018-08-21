pragma solidity ^0.4.20;
// check public fields
// change fundingstart to icostart? or maybe
// Set claiming period to 26 weeks  

import "./ERC20.sol";

contract IsonexTest is ERC20 {

    uint256 public tokenCap = 110000000 * 10**18;

    uint256 public minDepositAmount = 0.04 ether;

    bool public halted = false;
    bool public tradeable = false;

    struct Price { uint256 numerator; uint256 denominator; } // The number of Isonex tokens per Ether
    Price public currentPrice;
    mapping (uint256 => Price) public priceHistory;
    uint256 public currentPriceTimeWindow = 0;
    uint256 public priceUpdateInterval = 1 hours; // The amount of time that the control wallet must wait between price updates

    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;

    address public etherWallet; // change this name - maybe main wallet
    address public controlWallet; // change this name - maybe limited wallet
    address public vestingContract; // change name?
    bool private vestingSet = false;

    mapping (address => bool) public whitelist;

    struct WithdrawalRequest { uint256 nummberOfTokens; uint256 time; } // time for each withdrawal is set to the currentPriceTimeWindow
    mapping (address => WithdrawalRequest) withdrawalRequests;

    modifier onlyWhitelist {
        require(whitelist[msg.sender]);
        _;
    }

    modifier onlyFundWallet {
        require(msg.sender == etherWallet);
        _;
    }

    modifier onlyControlWallet {
        if (msg.sender == controlWallet)
		_;
    }

    modifier onlyManagingWallets {
        require(msg.sender == controlWallet || msg.sender == etherWallet);
        _;
    }

    modifier priceUpdateIntervalElapsed {
        require(safeSub(now, priceUpdateInterval) >= currentPriceTimeWindow);
        _;
    }

    modifier newNumeratorGreater (uint256 newNumerator) {
        if (newNumerator > currentPrice.numerator)
        _;
    }

    modifier isTradeable { // exempt vestingContract and fundWallet to allow dev allocations
        require(tradeable || msg.sender == etherWallet || msg.sender == vestingContract);
        _;
    }

    event PriceUpdate(uint256 numerator, uint256 denominator);
    event AllocatePresale(address indexed participant, uint256 numberOfTokens);
    event Whitelisted(address indexed participant);
    event WithdrawalRequested(address indexed participant, uint256 numberOfTokens);
    event Withdrew(address indexed participant, uint256 etherAmount, uint256 numberOfTokens);
    event LiquidityAdded(uint256 ethAmount);
    event RemoveLiquidity(uint256 ethAmount);
    event UserDeposited(address indexed participant, address indexed beneficiary, uint256 ethValue, uint256 numberOfTokens);

    function IsonexTest(address controlWalletInput, uint256 priceNumeratorInput, uint256 fundingStartBlockInput, uint256 fundingEndBlockInput) public {
        require(controlWalletInput != address(0));
        require(priceNumeratorInput > 0);
        name = "IsonexTest";
        symbol = "IX25Test";
        decimals = 18;
        etherWallet = msg.sender;
        controlWallet = controlWalletInput;
        whitelist[etherWallet] = true;
        whitelist[controlWallet] = true;
        currentPrice = Price(priceNumeratorInput, 1000); // 1 token = 1 usd at ICO start
        fundingStartBlock = fundingStartBlockInput;
        fundingEndBlock = fundingEndBlockInput;
        currentPriceTimeWindow = now; // maybe change to block number or something
    }

    
    function setVestingContract(address vestingContractInput) external onlyFundWallet {
        require(vestingContractInput != address(0));
        vestingContract = vestingContractInput;
        whitelist[vestingContract] = true;
        vestingSet = true;
    }

    // allows controlWallet to update the price within a time contstraint, allows fundWallet complete control
    function updatePrice(uint256 newNumerator) external onlyManagingWallets {
        require(newNumerator > 0);
        applySecondaryWalletChangeRestrictions(newNumerator);
        currentPrice.numerator = newNumerator;
        // maps time to new Price (if not during ICO)
        priceHistory[currentPriceTimeWindow] = currentPrice;
        currentPriceTimeWindow = now;
        emit PriceUpdate(newNumerator, currentPrice.denominator);
    }

    // controlWallet can only increase price by max 20% and only every priceUpdateInterval
    function applySecondaryWalletChangeRestrictions (uint256 newNumerator) private onlyControlWallet priceUpdateIntervalElapsed newNumeratorGreater(newNumerator) {
        uint256 percentageDiff = safeSub(safeMul(newNumerator, 100) / currentPrice.numerator, 100);
        require(percentageDiff <= 20);
    }

    function updatePriceDenominator(uint256 newDenominator) external onlyFundWallet {
        require(block.number > fundingEndBlock);
        require(newDenominator > 0);
        currentPrice.denominator = newDenominator;
        // maps time to new Price
        priceHistory[currentPriceTimeWindow] = currentPrice;
        currentPriceTimeWindow = now;
        emit PriceUpdate(currentPrice.numerator, newDenominator);
    }

    // 9.090909090909091 % of 99 => 9% of 100
    // 9.090909090909091*(X+Y)/100=Y
    // X=100Y/9.090909090909091 - y
    // X = 11Y - Y
    // Y = X/10
    
    function allocateTokens(address participant, uint256 numberOfTokens) private {
        require(vestingSet);
        // 9.090909090909091% of total allocated for PR, Marketing, Team, Advisors
        uint256 additionTokens = numberOfTokens / 10;
           
        // check that token cap is not exceeded
        uint256 totalNumberOfTokens = safeAdd(numberOfTokens, additionTokens);
        require(safeAdd(totalSupply, totalNumberOfTokens) <= tokenCap);
        // increase token supply, assign tokens to participant
        totalSupply = safeAdd(totalSupply, totalNumberOfTokens);
        balances[participant] = safeAdd(balances[participant], numberOfTokens);
        balances[vestingContract] = safeAdd(balances[vestingContract], additionTokens);
        emit Transfer(address(0), participant, numberOfTokens); // Added this so that token ownership is shown in etherscan
        emit Transfer(address(0), vestingContract, additionTokens);
    }

    function allocatePresaleTokens(address participant, uint numberOfTokens) external onlyFundWallet {
        require(block.number < fundingEndBlock);
        require(participant != address(0));
        whitelist[participant] = true;
        allocateTokens(participant, numberOfTokens);
        emit Whitelisted(participant);
        emit AllocatePresale(participant, numberOfTokens);
    }

    function verifyParticipant(address participant) external onlyManagingWallets {
        whitelist[participant] = true;
        emit Whitelisted(participant);
    }

    function deposit() external payable {
        depositTo(msg.sender);
    }
    
    function depositTo(address participant) public payable onlyWhitelist {
        require(!halted);
        require(participant != address(0));
        require(msg.value >= minDepositAmount);
        require(block.number >= fundingStartBlock && block.number < fundingEndBlock);
        uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / getStagedDenominator();
        allocateTokens(participant, tokensToBuy);
        // send ether to fundWallet
        etherWallet.transfer(msg.value);
        //Buy(msg.sender, participant, msg.value, tokensToBuy);
        emit UserDeposited(msg.sender, participant, msg.value, tokensToBuy);
    }

    function getStagedDenominator() public constant returns (uint256) {
        uint256 blocksSinceFundingStartBlock = safeSub(block.number, fundingStartBlock);
        //if (icoDuration < 2880) { // #blocks = 24*60*60/30 = 2880
        if (blocksSinceFundingStartBlock < 5760) { //24*60*60/15 1 Day
            return currentPrice.denominator;
        //} else if (icoDuration < 80640 ) { // #blocks = 4*7*24*60*60/30 = 80640
        } else if (blocksSinceFundingStartBlock < 11520 ) { // 2 Days
            return safeMul(currentPrice.denominator, 105) / 100;
        } else {
            return safeMul(currentPrice.denominator, 110) / 100;
        }
    }






    function requestWithdrawal(uint256 amountOfTokensToWithdraw) external isTradeable onlyWhitelist {
        require(block.number > fundingEndBlock);
        require(amountOfTokensToWithdraw > 0);
        address participant = msg.sender;
        require(balanceOf(participant) >= amountOfTokensToWithdraw);
        require(withdrawalRequests[participant].nummberOfTokens == 0); // participant cannot have outstanding withdrawals
        balances[participant] = safeSub(balanceOf(participant), amountOfTokensToWithdraw);
        withdrawalRequests[participant] = WithdrawalRequest({nummberOfTokens: amountOfTokensToWithdraw, time: currentPriceTimeWindow});
        emit WithdrawalRequested(participant, amountOfTokensToWithdraw);
    }

    function withdraw() external {
        address participant = msg.sender;
        uint256 nummberOfTokens = withdrawalRequests[participant].nummberOfTokens;
        require(nummberOfTokens > 0); // participant must have requested a withdrawal
        uint256 requestTime = withdrawalRequests[participant].time;
        // obtain the next price that was set after the request
        Price price = priceHistory[requestTime];
        require(price.numerator > 0); // price must have been set
        uint256 etherAmount = safeMul(nummberOfTokens, price.denominator) / price.numerator;
        withdrawalRequests[participant].nummberOfTokens = 0;
		
        // Make sure we have enough ether in the contract to send to the participant
        assert(this.balance >= etherAmount);

        // if contract ethbal > then send + transfer tokens to fundWallet, otherwise give tokens back
        if (this.balance >= etherAmount) {
            // Move the Isonex tokens to the ether wallet
            balances[etherWallet] = safeAdd(balances[etherWallet], nummberOfTokens);
            // Send ether from the contract wallet to the participant
            participant.transfer(etherAmount);
            emit Withdrew(participant, etherAmount, nummberOfTokens);
        }
        else {
            balances[participant] = safeAdd(balances[participant], nummberOfTokens);
            emit Withdrew(participant, etherAmount, 0); // failed withdrawal
        }
    }

    function checkWithdrawValue(uint256 amountTokensToWithdraw) public constant returns (uint256 etherValue) {
        require(amountTokensToWithdraw > 0);
        require(balanceOf(msg.sender) >= amountTokensToWithdraw);
        uint256 withdrawValue = safeMul(amountTokensToWithdraw, currentPrice.denominator) / currentPrice.numerator;
        require(this.balance >= withdrawValue);
        return withdrawValue;
    }

    // allow fundWallet or controlWallet to add ether to contract
    function addLiquidity() external onlyManagingWallets payable {
        require(msg.value > 0);
        emit LiquidityAdded(msg.value);
    }

    // allow fundWallet to remove ether from contract
    function removeLiquidity(uint256 amount) external onlyManagingWallets {
        require(amount <= this.balance);
        etherWallet.transfer(amount);
        emit RemoveLiquidity(amount);
    }

    function changeFundWallet(address newFundWallet) external onlyFundWallet {
        require(newFundWallet != address(0));
        etherWallet = newFundWallet;
    }

    function changeControlWallet(address newControlWallet) external onlyFundWallet {
        require(newControlWallet != address(0));
        controlWallet = newControlWallet;
    }

    function changePriceUpdateInterval(uint256 newPriceUpdateInterval) external onlyFundWallet {
        priceUpdateInterval = newPriceUpdateInterval;
    }

    function updateFundingStartBlock(uint256 newFundingStartBlock) external onlyFundWallet {
        require(block.number < fundingStartBlock);
        require(block.number < newFundingStartBlock);
        fundingStartBlock = newFundingStartBlock;
    }

    function updateFundingEndBlock(uint256 newFundingEndBlock) external onlyFundWallet {
        require(block.number < fundingEndBlock);
        require(block.number < newFundingEndBlock);
        fundingEndBlock = newFundingEndBlock;
    }

    function halt() external onlyFundWallet {
        halted = true;
    }

    function unhalt() external onlyFundWallet {
        halted = false;
    }

    function enableTrading() external onlyFundWallet {
        require(block.number > fundingEndBlock);
        tradeable = true;
    }

    // if ether is sent this contract, then handle it
    function() public payable {
		// TODO: why do we need this check. Consider removing it. Complier is complaining and online they say to never use origin
        //require(tx.origin == msg.sender); // important to find out what this is?? maybe this is why we never got transactions?????????????
        depositTo(msg.sender);
    }

    function claimTokens(address _token) external onlyFundWallet {
        require(_token != address(0));
        ERC20Interface token = ERC20Interface(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(etherWallet, balance);
    }

    // prevent transfers until trading allowed
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

    function getContractBalance() public constant returns (uint256) {
        return this.balance;
    }

    function getEtherWalletBalance() public constant returns (uint256) {
        return etherWallet.balance;
    }

    function getVestingContractBalance() public constant returns (uint256) {
        return balances[vestingContract];
    }

    function pendingWithdrawalRequestOf(address participant) constant returns (uint256 tokens) {
        return withdrawalRequests[participant].nummberOfTokens;
    }

}