pragma solidity ^0.4.20;
// check public fields

import "./ERC20.sol";

contract IsonexTest is ERC20 {

    //uint256 public tokenCap = 114942528 * 10**18; // using a 13% share for team. We probably want to change this to 10

    uint256 public tokenCap = 111111111 * 10**18;

    uint256 public minDepositAmount = 0.04 ether; // The minimum amount of ether allowed when depositing using the depositTo function

    bool public halted = false;
    bool public tradeable = false;

    struct Price { uint256 numerator; uint256 denominator; } // The number of Isonex tokens per Ether
    Price public currentPrice;
    mapping (uint256 => Price) public priceHistory;
    uint256 public previousPriceUpdateTime = 0;
    uint256 public priceUpdateInterval = 1 hours; // The amount of time that the control wallet must wait between price updates

    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;

    address public etherWallet; // change this name - maybe main wallet
    address public controlWallet; // change this name - maybe limited wallet
    address public vestingContract; // change name?

    mapping (address => bool) public whitelist;

    struct WithdrawalRequest { uint256 nummberOfTokens; uint256 time; } // time for each withdrawal is set to the previousPriceUpdateTime
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
        require(safeSub(now, priceUpdateInterval) >= previousPriceUpdateTime);
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
    event Whitelisted(address indexed participant);
    event WithdrawalRequested(address indexed participant, uint256 amountTokens);
    event Withdrew(address indexed participant, uint256 etherAmount, uint256 tokenAmount);
    event LiquidityAdded(uint256 ethAmount);
    event RemoveLiquidity(uint256 ethAmount);
    event UserDeposited(address indexed participant, address indexed beneficiary, uint256 ethValue, uint256 amountTokens);

    function IsonexTest(address controlWalletInput) public {

        name = "IsonexTest";
        symbol = "IX25Test";
        decimals = 18;

        require(controlWalletInput != address(0));
        etherWallet = msg.sender;
        previousPriceUpdateTime = now;
        whitelist[etherWallet] = true;
        currentPrice = Price(1000000, 1000); // 1 token = 1 usd at ICO start
        controlWallet = controlWalletInput;
        whitelist[controlWallet] = true;

        fundingStartBlock = block.number + 10;
        fundingEndBlock = block.number + 2666; // ~ 5 days on testnet
    }

    function verifyParticipant(address participant) external onlyManagingWallets {
        whitelist[participant] = true;
        emit Whitelisted(participant);
    }

    // I added this, maybe remove it
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

    function deposit() external payable {
        depositTo(msg.sender);
    }

    function getIcoDenominator() public constant returns (uint256) {
        uint256 icoDuration = safeSub(block.number, fundingStartBlock);
        uint256 denominator;
        //if (icoDuration < 2880) { // #blocks = 24*60*60/30 = 2880
        if (icoDuration < 10) { // #blocks = 24*60*60/30 = 2880
            return currentPrice.denominator;
        //} else if (icoDuration < 80640 ) { // #blocks = 4*7*24*60*60/30 = 80640
        } else if (icoDuration < 20 ) { // #blocks = 4*7*24*60*60/30 = 80640
            denominator = safeMul(currentPrice.denominator, 105) / 100;
            return denominator;
        } else {
            denominator = safeMul(currentPrice.denominator, 110) / 100;
            return denominator;
        }
    }

    function depositTo(address participant) public payable onlyWhitelist {
        //require(!halted);
        require(participant != address(0));
        require(msg.value >= minDepositAmount);
        require(block.number >= fundingStartBlock && block.number < fundingEndBlock);
        //uint256 icoDenominator = icoDenominatorPrice();
        //uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / icoDenominator;
		
		uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / getIcoDenominator();

        //allocateTokens(participant, tokensToBuy);
        allocateTokens(participant, tokensToBuy);
		
        // send ether to fundWallet
        //fundWallet.transfer(msg.value);
        etherWallet.transfer(msg.value);
		
        //Buy(msg.sender, participant, msg.value, tokensToBuy);
        emit UserDeposited(msg.sender, participant, msg.value, msg.value);
    }

    function allocateTokens(address participant, uint256 amountTokens) private {
        //require(vestingSet);
        // 13% of total allocated for PR, Marketing, Team, Advisors
       	//uint256 developmentAllocation = safeMul(amountTokens, 14942528735632185) / 100000000000000000;
        uint256 developmentAllocation = safeMul(amountTokens, 11111111111111111) / 100000000000000000; // need to check that this is a 10% increase
           
        // check that token cap is not exceeded
        uint256 newTokens = safeAdd(amountTokens, developmentAllocation);
        require(safeAdd(totalSupply, newTokens) <= tokenCap);
        // increase token supply, assign tokens to participant
        totalSupply = safeAdd(totalSupply, newTokens);
        balances[participant] = safeAdd(balances[participant], amountTokens);
        balances[vestingContract] = safeAdd(balances[vestingContract], developmentAllocation);
    }

    function allocatePresaleTokens(address participant, uint amountTokens) external onlyFundWallet {
        require(block.number < fundingEndBlock);
        require(participant != address(0));
        whitelist[participant] = true; // automatically whitelist accepted presale
        allocateTokens(participant, amountTokens);
        emit Whitelisted(participant);
        //AllocatePresale(participant, amountTokens);
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

    function pendingWithdrawalRequestOf(address participant) constant returns (uint256 tokens) {
        return withdrawalRequests[participant].nummberOfTokens;
    }

	//function requestWithdrawal(uint256 amountOfTokensToWithdraw) external isTradeable onlyWhitelist {
    function requestWithdrawal(uint256 amountOfTokensToWithdraw) external onlyWhitelist {

        require(block.number > fundingEndBlock);
        require(amountOfTokensToWithdraw > 0);

        address participant = msg.sender;
		
        require(balanceOf(participant) >= amountOfTokensToWithdraw);
        require(withdrawalRequests[participant].nummberOfTokens == 0); // participant cannot have outstanding withdrawals
        balances[participant] = safeSub(balanceOf(participant), amountOfTokensToWithdraw);
        withdrawalRequests[participant] = WithdrawalRequest({nummberOfTokens: amountOfTokensToWithdraw, time: previousPriceUpdateTime});
        emit WithdrawalRequested(participant, amountOfTokensToWithdraw);
    }

    function withdraw() external {
        address participant = msg.sender;
        uint256 tokenAmount = withdrawalRequests[participant].nummberOfTokens;
        require(tokenAmount > 0); // participant must have requested a withdrawal
        uint256 requestTime = withdrawalRequests[participant].time;
        // obtain the next price that was set after the request
        Price price = priceHistory[requestTime];
        require(price.numerator > 0); // price must have been set
        //uint256 withdrawValue = safeMul(tokens, price.denominator) / price.numerator;

        uint256 etherAmount = safeMul(tokenAmount, currentPrice.denominator) / currentPrice.numerator;

        withdrawalRequests[participant].nummberOfTokens = 0;
		
        // if contract ethbal > then send + transfer tokens to fundWallet, otherwise give tokens back
        //if (this.balance >= withdrawValue)
        //    enact_withdrawal_greater_equal(participant, withdrawValue, tokens);
        //else
            //enact_withdrawal_less(participant, withdrawValue, tokens);
        
		enact_withdrawal_greater_equal(participant, etherAmount, tokenAmount);
    }

    function updateFundingStartBlock(uint256 newFundingStartBlock) external onlyFundWallet {
       //require(block.number < fundingStartBlock);
        //require(block.number < newFundingStartBlock);
        fundingStartBlock = newFundingStartBlock;
    }

    function updateFundingEndBlock(uint256 newFundingEndBlock) external onlyFundWallet {
        //require(block.number < fundingEndBlock);
        //require(block.number < newFundingEndBlock);
        fundingEndBlock = newFundingEndBlock;
    }

	// allows controlWallet to update the price within a time contstraint, allows fundWallet complete control
    function updatePrice(uint256 newNumerator) external onlyManagingWallets {
        require(newNumerator > 0);
        require_limited_change(newNumerator);
        // either controlWallet command is compliant or transaction came from fundWallet
        currentPrice.numerator = newNumerator;
        // maps time to new Price (if not during ICO)
        priceHistory[previousPriceUpdateTime] = currentPrice;
        previousPriceUpdateTime = now;
        emit PriceUpdate(newNumerator, currentPrice.denominator);
    }

    function require_limited_change (uint256 newNumerator)
        private
        onlyControlWallet
        priceUpdateIntervalElapsed
        newNumeratorGreater(newNumerator)
    {
        uint256 percentage_diff = 0;
        percentage_diff = safeMul(newNumerator, 100) / currentPrice.numerator;
        percentage_diff = safeSub(percentage_diff, 100);
        // controlWallet can only increase price by max 20% and only every priceUpdateInterval
        require(percentage_diff <= 20);
    }

    function enact_withdrawal_greater_equal(address participant, uint256 etherAmount, uint256 tokenAmount) private {
		// assert(this.balance >= withdrawValue);
        // balances[fundWallet] = safeAdd(balances[fundWallet], tokens);
        // participant.transfer(withdrawValue);
        // Withdraw(participant, tokens, withdrawValue);

		// Make sure we have enough ether in the contract to send to the participant
		assert(this.balance >= etherAmount);
		// Move the Isonex tokens to the ether wallet
		balances[etherWallet] = safeAdd(balances[etherWallet], tokenAmount);
		// Send ether frmm the contract wallet to the participant
        participant.transfer(etherAmount);
        emit Withdrew(participant, etherAmount, tokenAmount);
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

	// if ether is sent this contract, then handle it
    function() public payable {
		// TODO: why do we need this check	
        require(tx.origin == msg.sender);
        depositTo(msg.sender);
    }


    function kill() external {

		// very bad, anyone can kill it and the ether is not even going back to the owner!!!!
       	//if (owner == msg.sender) {
          selfdestruct(etherWallet);
       //}
    }

    function setVestingContract(address vestingContractInput) { //external onlyFundWallet {
        require(vestingContractInput != address(0));
        vestingContract = vestingContractInput;
        whitelist[vestingContract] = true;
        //vestingSet = true;
    }


    // prevent transfers until trading allowed
    function transfer(address _to, uint256 _value) public isTradeable returns (bool success) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public isTradeable returns (bool success) {
        return super.transferFrom(_from, _to, _value);
    }
	


	

    

}