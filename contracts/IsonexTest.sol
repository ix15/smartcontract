// check this
pragma solidity ^0.4.13;

contract IsonexTest {

// public only for testing
	address public etherWallet;
	address public controlWallet;

    uint256 public waitTime = 5 hours;


    string public name = "IsonexTest";
    string public symbol = "IsonexTest";
    uint8 public decimals = 18;
    uint256 public totalSupply;

	// need to decide a cap
    uint256 public tokenCap = 114942528 * 10**18; // using a 13% share for team

    mapping (address => uint256) balances;
    mapping (address => WithdrawalRequest) withdrawalRequests;
    mapping (uint256 => Price) public prices;
    mapping (address => bool) public whitelist;

    Price public currentPrice;
    uint256 public minAmount = 0.04 ether;

	
	 // crowdsale parameters
    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;

	struct Price { // tokensPerEth
        uint256 numerator;
        uint256 denominator;
    }

    uint256 public previousUpdateTime = 0;

	struct WithdrawalRequest {
        uint256 tokens;
        uint256 time; // time for each withdrawal is set to the previousUpdateTime
    }

// public only for testing
	address public vestingContract;

    //mapping (address => bool) public whitelist;

 	modifier onlyWhitelist {
        require(whitelist[msg.sender]);
        _;
    }

	modifier onlyFundWallet {
        require(msg.sender == etherWallet);
        _;
    }

	modifier only_if_controlWallet {
        if (msg.sender == controlWallet)
		_;
    }

	modifier onlyManagingWallets {
        require(msg.sender == controlWallet || msg.sender == etherWallet);
        _;
    }

    modifier require_waited {
        require(safeSub(now, waitTime) >= previousUpdateTime);
        _;
    }

    modifier only_if_increase (uint256 newNumerator) {
        if (newNumerator > currentPrice.numerator)
        _;
    }

	event StateChanged_Event(
        string newState
    );

    event PriceUpdate(uint256 numerator, uint256 denominator);

    event Whitelisted_Event(address indexed participant);


    event WithdrawalRequested_Event(address indexed participant, uint256 amountTokens);

    event Withdrew_Event(address indexed participant, uint256 etherAmount, uint256 tokenAmount);

    event AddLiquidity(uint256 ethAmount);
    event RemoveLiquidity(uint256 ethAmount);

	ContractState state = ContractState.PreIco;

	function IsonexTest(address controlWalletInput) {
        require(controlWalletInput != address(0));
		etherWallet = msg.sender;
		previousUpdateTime = now;
		whitelist[etherWallet] = true;
		currentPrice = Price(1000000, 1000); // 1 token = 1 usd at ICO start
        controlWallet = controlWalletInput;
        whitelist[controlWallet] = true;

		fundingStartBlock = block.number + 10;
		fundingEndBlock = block.number + 2666; // ~ 5 days on testnet
	}

	function getDecimals() constant returns (uint8) {
		return decimals;
	}

	function getName() constant returns (string) {
        return name;
    }

	function verifyParticipant(address participant) external onlyManagingWallets {
        whitelist[participant] = true;
        Whitelisted_Event(participant);
    }

	function isInWhitelist(address participant) constant returns (bool) {
		return whitelist[participant];
	}

	// function getState() constant returns (string) {

	// 	if (state == ContractState.PreIco) {
	// 		return "Pre Ico";
	// 	} else if (state == ContractState.Ico) {
	// 		return "Ico";
	// 	} else {
	// 		return "Post Ico";
	// 	}

	// }

	function getState() constant returns (string) {

		if (block.number < fundingStartBlock) {
			return "Pre Ico";
		} else if (block.number < fundingEndBlock) {
			return "Ico";
		} else {
			return "Post Ico";
		}

	}

	function nextState() {
		if (state == ContractState.PreIco) {
			state = ContractState.Ico;
		} else if (state == ContractState.Ico) {
			state = ContractState.PostIco;
		} else {
			state = ContractState.PreIco;
		}

		var newStateString = getState();

		StateChanged_Event(newStateString);
	}

	enum ContractState {
		PreIco,
		Ico,
		PostIco
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

	// Deposit tokens



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
        require(msg.value >= minAmount);
        require(block.number >= fundingStartBlock && block.number < fundingEndBlock);
		// require(state == ContractState.Ico);
        //uint256 icoDenominator = icoDenominatorPrice();
        //uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / icoDenominator;
		
		uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / getIcoDenominator();

        //allocateTokens(participant, tokensToBuy);
        allocateTokens(participant, tokensToBuy);
		
        // send ether to fundWallet
        //fundWallet.transfer(msg.value);
        etherWallet.transfer(msg.value);
		
        //Buy(msg.sender, participant, msg.value, tokensToBuy);
        UserDeposited(msg.sender, participant, msg.value, msg.value);
    }

	event UserDeposited(address indexed participant, address indexed beneficiary, uint256 ethValue, uint256 amountTokens);


	function allocateTokens(address participant, uint256 amountTokens) private {
        //require(vestingSet);
        // 13% of total allocated for PR, Marketing, Team, Advisors
       	uint256 developmentAllocation = safeMul(amountTokens, 14942528735632185) / 100000000000000000;
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
        Whitelisted_Event(participant);(participant);
        //AllocatePresale(participant, amountTokens);
    }

	function balanceOf(address participant) constant returns (uint256 balance) {
        return balances[participant];
    }

	function pendingWithdrawalRequestOf(address participant) constant returns (uint256 tokens) {
        return withdrawalRequests[participant].tokens;
    }

	//function requestWithdrawal(uint256 amountOfTokensToWithdraw) external isTradeable onlyWhitelist {
	function requestWithdrawal(uint256 amountOfTokensToWithdraw) external onlyWhitelist {

        require(block.number > fundingEndBlock);
        require(amountOfTokensToWithdraw > 0);

        address participant = msg.sender;
		
        require(balanceOf(participant) >= amountOfTokensToWithdraw);
        require(withdrawalRequests[participant].tokens == 0); // participant cannot have outstanding withdrawals
        balances[participant] = safeSub(balanceOf(participant), amountOfTokensToWithdraw);
        withdrawalRequests[participant] = WithdrawalRequest({tokens: amountOfTokensToWithdraw, time: previousUpdateTime});
        WithdrawalRequested_Event(participant, amountOfTokensToWithdraw);
    }

	function withdraw() external {
        address participant = msg.sender;
        uint256 tokenAmount = withdrawalRequests[participant].tokens;
        require(tokenAmount > 0); // participant must have requested a withdrawal
        uint256 requestTime = withdrawalRequests[participant].time;
        // obtain the next price that was set after the request
        Price price = prices[requestTime];
        require(price.numerator > 0); // price must have been set
        //uint256 withdrawValue = safeMul(tokens, price.denominator) / price.numerator;

        uint256 etherAmount = safeMul(tokenAmount, currentPrice.denominator) / currentPrice.numerator;

        withdrawalRequests[participant].tokens = 0;
		
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
        prices[previousUpdateTime] = currentPrice;
        previousUpdateTime = now;
        PriceUpdate(newNumerator, currentPrice.denominator);
    }

    function require_limited_change (uint256 newNumerator)
        private
        only_if_controlWallet
        require_waited
        only_if_increase(newNumerator)
    {
        uint256 percentage_diff = 0;
        percentage_diff = safeMul(newNumerator, 100) / currentPrice.numerator;
        percentage_diff = safeSub(percentage_diff, 100);
        // controlWallet can only increase price by max 20% and only every waitTime
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
        Withdrew_Event(participant, etherAmount, tokenAmount);
    }

	
	// allow fundWallet or controlWallet to add ether to contract
    function addLiquidity() external onlyManagingWallets payable {
        require(msg.value > 0);
        AddLiquidity(msg.value);
    }

    // allow fundWallet to remove ether from contract
    function removeLiquidity(uint256 amount) external onlyManagingWallets {
        require(amount <= this.balance);
        etherWallet.transfer(amount);
        RemoveLiquidity(amount);
    }

    function changeFundWallet(address newFundWallet) external onlyFundWallet {
        require(newFundWallet != address(0));
        etherWallet = newFundWallet;
    }

    function changeControlWallet(address newControlWallet) external onlyFundWallet {
        require(newControlWallet != address(0));
        controlWallet = newControlWallet;
    }

    function changeWaitTime(uint256 newWaitTime) external onlyFundWallet {
        waitTime = newWaitTime;
    }

	// if ether is sent this contract, then handle it
    function() payable {
		// TODO: why do we need this check	
        require(tx.origin == msg.sender);
        depositTo(msg.sender);
    }


	function kill() {

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
    //function transfer(address _to, uint256 _value) isTradeable returns (bool success) {
    // function transfer(address _to, uint256 _value) returns (bool success) {
    //     return super.transfer(_to, _value);
    // }
    // //function transferFrom(address _from, address _to, uint256 _value) isTradeable returns (bool success) {
    // function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {		
    //     return super.transferFrom(_from, _to, _value);
    // }

	event Transfer(address indexed _from, address indexed _to, uint256 _value);

	//function transfer(address _to, uint256 _value) onlyPayloadSize(2) returns (bool success) { isTradeable
	function transfer(address _to, uint256 _value) returns (bool success) {
        require(_to != address(0));
        require(balances[msg.sender] >= _value && _value > 0);		// documentation says transfer of 0 must be treated as a transfer and fire the transfer event
        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        Transfer(msg.sender, _to, _value);

        return true;
    }

    mapping (address => mapping (address => uint256)) allowed;

	function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

	event Approval(address indexed _owner, address indexed _spender, uint256 _value);

 	// To change the approve amount you first have to reduce the addresses'
    //  allowance to zero by calling 'approve(_spender, 0)' if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address _spender, uint256 _value) onlyPayloadSize(2) returns (bool success) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);

        return true;
    }

	 function changeApproval(address _spender, uint256 _oldValue, uint256 _newValue) onlyPayloadSize(3) returns (bool success) {
        require(allowed[msg.sender][_spender] == _oldValue);
        allowed[msg.sender][_spender] = _newValue;
        Approval(msg.sender, _spender, _newValue);

        return true;
    }

    //function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3) returns (bool success) { isTradeable
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        require(_to != address(0));
        require(balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0);
        balances[_from] = safeSub(balances[_from], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
        Transfer(_from, _to, _value);

        return true;
    }

	modifier onlyPayloadSize(uint numWords) {
    	assert(msg.data.length >= numWords * 32 + 4);
     	_;
  	}

	//

	function safeMul(uint a, uint b) internal returns (uint) {
		uint c = a * b;
		assert(a == 0 || c / a == b);
		return c;
	}

	function safeAdd(uint a, uint b) internal returns (uint) {
		uint c = a + b;
		assert(c>=a && c>=b);
		return c;
	}

	function safeSub(uint a, uint b) internal returns (uint) {
		assert(b <= a);
		return a - b;
	}
}