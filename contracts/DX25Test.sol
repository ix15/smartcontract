// check this
pragma solidity ^0.4.13;

contract DX25Test {

	event StateChanged(
        string newState
    );

	address owner;
    string public name = "DX25Test";
    string public symbol = "DX25Test";
    uint8 public decimals = 18;
    uint256 public totalSupply;

	ContractState state = ContractState.PreIco;

	function DX25Test() {
		owner = msg.sender;
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

		StateChanged(newStateString);
	}

	enum ContractState {
		PreIco,
		Ico,
		PostIco
	}

	function kill() {
       if (owner == msg.sender) {
          selfdestruct(owner);
       }
    }
}