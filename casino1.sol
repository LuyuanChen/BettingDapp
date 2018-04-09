pragma solidity ^0.4.20;

contract Casino {
	address owner;

	uint minimumBet = 100 finney;
	uint totalBet;
	uint numberOfBets;
	uint maxAmountOfBets = 1;
	address[] players;
	address[] dataSources;
	address[] dataSourcesSubmitted;
	
	uint requiredDataSource = 3; 
	uint totalDataSource = 5;

	uint public constant LIMIT_AMOUNT_BETS = 100; //TODO, can only be set by owner
    event Bet(address indexed sender, uint indexed bet);
    event DataSubmitted(address indexed sender, uint indexed result);
    event PrizeDistributed(address indexed sender, address[] indexed winners, uint prize);
    
	struct Player {
		uint amountBet;
		uint numberSelected;
	}

	// map from play address to the amount/number for the bet
	mapping(address => Player) playerInfo;
	mapping(address => uint) dataSubmitted;

	function Casino(uint _minimumBet, uint _requiredDataSource, uint _totalDataSource) 
	public 
	{

		owner = msg.sender;
		if (_minimumBet > 0) minimumBet = _minimumBet;
		if (_requiredDataSource >= 1 && _requiredDataSource <= _totalDataSource) 
		    requiredDataSource = _requiredDataSource;
    	if (_totalDataSource >= 1 && _requiredDataSource <= _totalDataSource) 
    	    totalDataSource = _totalDataSource;
	}
	
	function addDataSource(address dataSource) 
	public
	{
	    require (msg.sender == owner); //only the owner can add a data source
	    require (dataSource != owner);
	    require (dataSourcesSubmitted.length < totalDataSource);
	    //datasource cannot be a player and vice versa
	    require (!checkExists(dataSources, dataSource));
	    require (!checkExists(players, dataSource));
	    dataSources.push(dataSource);
	}
	
	function submitData(uint data) 
	public
	{
	    require (numberOfBets >= maxAmountOfBets);
	    require (checkExists(dataSources, msg.sender));
	    require (!checkExists(dataSourcesSubmitted, msg.sender));
	    dataSubmitted[msg.sender] = data;
	    dataSourcesSubmitted.push(msg.sender);
        potentiallyDistributePrize();
	}
	
	function potentiallyDistributePrize() private {
        if (dataSourcesSubmitted.length < requiredDataSource) return;
        if (numberOfBets < maxAmountOfBets) return;
	    // the data sources have to agree
	    uint agreement = 0;
	    bool first = true;
	    
	    for(uint i = 0; i < dataSourcesSubmitted.length; i++){
	        address dataSource = dataSourcesSubmitted[i];
	        if (first == true) {
	            agreement = dataSubmitted[dataSource];
	            first = false;
	   
	        } else {
	        
	            if (agreement != dataSubmitted[dataSource]) {
	                kill(); //TODO, return money too!
	                return;
	            } 
	        }
	    }
	    distributePrize(agreement);
	}

	function kill()
	public 
	{
		if(msg.sender == owner)
			selfdestruct(owner);
	}

	// To bet for a number between 1 and 10 both inclusive
	function bet(uint number) 
    public
	payable 
	{
		require(!checkExists(players, msg.sender));
		require(!checkExists(dataSources, msg.sender));
		require(number >= 1 && number <= 10);
    	require(msg.value >= minimumBet);

		playerInfo[msg.sender].amountBet = msg.value;
		playerInfo[msg.sender].numberSelected = number;
		numberOfBets += 1;
		players.push(msg.sender);
		totalBet += msg.value;
        emit Bet(msg.sender, number);
        potentiallyDistributePrize();
	}
	
	function checkExists(address [] people, address person) private returns(bool) 
	{
		for(uint i = 0; i < people.length; i++){
			if(people[i] == person) 
				return true;
		}
		return false;
	}

	function generateNumberWinner() private {
		uint numberGenerated = block.number % 10 + 1;
        distributePrize(numberGenerated);
	}
	
	uint step1 = 0;
	
	address[] winners;
	function distributePrize(uint winner) private {
	    //address[] memory winners;
		uint count = 0; 
        step1 = 1;
		for (uint i = 0; i < players.length; i++) {
			address player = players[i];
			if (playerInfo[player].numberSelected == winner) {
			    //winners[count] = player; //problematic
			    winners.push(player);
				count++;
			}
			delete playerInfo[player];  // delete the player after insnsertion.
		}

		// delete all data in players by setting the length???
		players.length = 0;

		uint winnerEtherAmount = totalBet / winners.length;
		for (i = 0; i < count; i++) {
			if ( winners[i] != address(0)) { 
				// not null
				winners[i].transfer(winnerEtherAmount);
			}
		}
		emit PrizeDistributed(address(this), winners, winnerEtherAmount);
	}
}
