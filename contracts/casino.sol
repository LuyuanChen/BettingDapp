pragma solidity ^0.4.11;

contract Casino {
	address owner;

	uint minimumBet = 100 finney;
	uint totalBet;
	uint numberOfBets;
	uint maxAmountOfBets = 100;
	address[] players;

	uint public constant LIMIT_AMOUNT_BETS = 100;

	struct Player {
		uint amountBet;
		uint numberSelected;
	}

	// map from play address to the amount/number for the bet
	mapping(address => Player) playerInfo;




	function Casino(uint _minimumBet) {
		owner = msg.sender;

		if (_minimumBet > 0) minumumBet = _minimumBet;
	}

	function kill() {
		if(msg.sender == owner)
			selfdestruct(owner);
	}

	// To bet for a number between 1 and 10 both inclusive
	function bet(uint number) payable {
		assert(checkPlayerExists(msg.sender) == false);
		assert(number >= 1 && number <= 10);
		assert(msg.value >= minimumBet);

		playerInfo[msg.sender].amountBet = msg.value;
		playerInfo[msg.sender].numberSelected = number;
		numberOfBets += 1;
		players.push(msg.sender);
		totalBet += msg.value;

		if(numberOfBets >= maxAmountOfBets) 
			generateNumberWinner();
	}

	function checkPlayerExists(address player) returns(bool) {
		for(uint i = 0; i < players.length; i++){
			if(players[i] == player) 
				return true;
		}
		return false;
	}

	function generateNumberWinner() {
		uint numberGenerated = block.number % 10 + 1;

		address[100] memory winners;
		uint count = 0; 

		for (uint i = 0; i < players.length; i++) {
			address player = players[i];
			if (playerInfo[player].numberSelected == numberGenerated)j {
				winners[count] = player;
				count++；
			}
			delete playerInfo[player];  // delete the player after insnsertion.
		}

		// delete all data in players by setting the length???
		players.length = 0;

		uint winnerEtherAmount = totalBet / winners.length;
		for (i = 0; i < count, i++) {
			if (if winners[i] != address(0)) { 
				// not null
				winners[i].transfer(winnerEtherAmount);
			}
		}
	}

