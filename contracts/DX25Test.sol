// etherWallet contains the ether that is deposited
// the etherWallet is used to deploy the contracts
// the contract itself contains any ether that may be withdrawn by invetors (without requiring liquidation)




// check this
pragma solidity ^0.4.13;

contract DX25Test {

// public only for testing
	address public etherWallet;
    string public name = "DX25Test";
    string public symbol = "DX25Test";
    uint8 public decimals = 18;
    uint256 public totalSupply;

	// need to decide a cap
    uint256 public tokenCap = 80000000 * 10**18;

    mapping (address => uint256) balances;
    mapping (address => WithdrawalRequest) withdrawalRequests;

    uint256 public previousUpdateTime = 0;

	struct WithdrawalRequest {
        uint256 tokens;
        uint256 time; // time for each withdrawal is set to the previousUpdateTime
    }

// public only for testing
	address public vestingContract;

    //mapping (address => bool) public whitelist;

 	// modifier onlyWhitelist {
    //     require(whitelist[msg.sender]);
    //     _;
    //}

	modifier onlyInvestors {
        require(balances[msg.sender] > 0);
        _;
    }

	event StateChanged_Event(
        string newState
    );

	event Logged_Event(
        string message,
		uint256 uint2561
    );


    event WithdrawalRequested_Event(address indexed participant, uint256 amountTokens);

    event Withdrew_Event(address indexed participant, uint256 etherAmount, uint256 tokenAmount);


	ContractState state = ContractState.PreIco;

	function DX25Test() {
		etherWallet = msg.sender;
		previousUpdateTime = now;
	}

	function getDecimals() constant returns (uint8) {
		return decimals;
	}

	function getName() constant returns (string) {
        return name;
    }

	function getState() constant returns (string) {

		if (state == ContractState.PreIco) {
			return "Pre Ico";
		} else if (state == ContractState.Ico) {
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


    //function depositTo(address participant) public payable onlyWhitelist {
    function depositTo(address participant) public payable {
        //require(!halted);
        require(participant != address(0));
        //require(msg.value >= minAmount);
        //require(block.number >= fundingStartBlock && block.number < fundingEndBlock);
		require(state == ContractState.Ico);
        //uint256 icoDenominator = icoDenominatorPrice();
        //uint256 tokensToBuy = safeMul(msg.value, currentPrice.numerator) / icoDenominator;
		
		uint256 tokensToBuy = safeMul(msg.value, 1000000) / 1000;

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
        //require(safeAdd(totalSupply, newTokens) <= tokenCap);
        // increase token supply, assign tokens to participant
        totalSupply = safeAdd(totalSupply, newTokens);
        balances[participant] = safeAdd(balances[participant], amountTokens);
        balances[vestingContract] = safeAdd(balances[vestingContract], developmentAllocation);
    }

	function balanceOf(address participant) constant returns (uint256 balance) {
        return balances[participant];
    }

	function pendingWithdrawalRequestOf(address participant) constant returns (uint256 tokens) {
        return withdrawalRequests[participant].tokens;
    }

	//function requestWithdrawal(uint256 amountTokensToWithdraw) external isTradeable onlyWhitelist {
	function requestWithdrawal(uint256 amountOfTokensToWithdraw) external onlyInvestors {	

		Logged_Event("requestWithdrawal", amountOfTokensToWithdraw);

        //require(block.number > fundingEndBlock);
        require(amountOfTokensToWithdraw > 0);

        address participant = msg.sender;
		
        require(balanceOf(participant) >= amountOfTokensToWithdraw);
        require(withdrawalRequests[participant].tokens == 0); // participant cannot have outstanding withdrawals
        balances[participant] = safeSub(balanceOf(participant), amountOfTokensToWithdraw);
        withdrawalRequests[participant] = WithdrawalRequest({tokens: amountOfTokensToWithdraw, time: previousUpdateTime});
        WithdrawalRequested_Event(participant, amountOfTokensToWithdraw);
    }

	function withdraw() external onlyInvestors {
        address participant = msg.sender;
        uint256 tokenAmount = withdrawalRequests[participant].tokens;
        require(tokenAmount > 0); // participant must have requested a withdrawal
        //uint256 requestTime = withdrawalRequests[participant].time;
        // obtain the next price that was set after the request
        //Price price = prices[requestTime];
        //require(price.numerator > 0); // price must have been set
        //uint256 withdrawValue = safeMul(tokens, price.denominator) / price.numerator;

        uint256 etherAmount = safeMul(tokenAmount, 1000) / 1000000;

        withdrawalRequests[participant].tokens = 0;
		
        // if contract ethbal > then send + transfer tokens to fundWallet, otherwise give tokens back
        //if (this.balance >= withdrawValue)
        //    enact_withdrawal_greater_equal(participant, withdrawValue, tokens);
        //else
            //enact_withdrawal_less(participant, withdrawValue, tokens);
        
		enact_withdrawal_greater_equal(participant, etherAmount, tokenAmount);
    }

	function enact_withdrawal_greater_equal(address participant, uint256 etherAmount, uint256 tokenAmount) private {
		// assert(this.balance >= withdrawValue);
        // balances[fundWallet] = safeAdd(balances[fundWallet], tokens);
        // participant.transfer(withdrawValue);
        // Withdraw(participant, tokens, withdrawValue);

		// Make sure we have enough ether in the contract to send to the participant
		assert(this.balance >= etherAmount);
		// Move the DX25 tokens to the ether wallet
		balances[etherWallet] = safeAdd(balances[etherWallet], tokenAmount);
		// Send ether frmm the contract wallet to the participant
        participant.transfer(etherAmount);
        Withdrew_Event(participant, etherAmount, tokenAmount);
    }

	
	// allow fundWallet or controlWallet to add ether to contract
    //function addLiquidity() external onlyManagingWallets payable {
    function addLiquidity() external payable {
        require(msg.value > 0);
        //AddLiquidity(msg.value);
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
        //whitelist[vestingContract] = true;
        //vestingSet = true;
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