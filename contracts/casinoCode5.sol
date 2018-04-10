pragma solidity ^0.4.20;

contract Casino {
	address owner;

	uint minBet = 100 finney;
	uint maxBet = 1000 finney;
	
	uint totalBet;
	
	uint numPlayers;
	uint public constant MAX_NUM_PLAYERS = 100;
    
	struct Player {
		uint amountBet;
		uint numberSelected; // TODO, need to make this to adapt different betting scheme
		int datasource;
	}
	
	address[] players;
	mapping(address => Player) playerInfo;
	
	//a data structure to store all the data sources, should be immutable upon construction!
	string[] datasources;
	int chosenDatasource = -1;
	
	//https://ethereum.stackexchange.com/questions/11556/use-string-type-or-bytes32
	string constant datasource1 = "av17pn1rh1.execute-api.us-east-1.amazonaws.com/dev";
	string datasourceString = "";
	
	
	// Control various stages of the contract
	bool mayBet = false;
	bool maySubmit = false;
	 
    event Bet(address indexed sender, uint indexed bet);
	event SelectDataSource(address indexed sender, uint indexed bet);
	//event DataSubmitted();
    event PrizeDistributed(address indexed sender, address[] indexed winners, uint prize);
 

	/************************** Owner Functions *******************************/
	function Casino(uint _minBet, uint _maxBet) 
	public 
	{

		owner = msg.sender;
		if (_minBet > 0) minBet = _minBet;
    	if (_maxBet >= _minBet) maxBet = _maxBet;
		
    	datasources.push(datasource1);
	    datasourceString = strConcat(datasourceString, "0 : ");
	    datasourceString = strConcat(datasourceString, datasource1);
	    datasourceString = strConcat(datasourceString, "  |  ");
		
		mayBet = true;
	}
	
	mapping(uint => uint) tally;
	function stopBetting()
	public
	{
		require (mayBet);
	    require (msg.sender == owner);
		mayBet = false;
		maySubmit = true;
		
	    bool first = true;
	    
		for (uint i = 0; i < datasources.length; i ++) {
			tally[i] = 0;
		}
	    for(i = 0; i < players.length; i++){
	        int datasource = playerInfo[players[i]].datasource;
	        if (datasource < 0) continue;
	        
			tally[uint(datasource)] = tally[uint(datasource)] + 1;
	    }
		uint max = 0;
	    for (i = 0; i < datasources.length; i ++) { // simple tie breaking, just chose the second one!
			if (tally[i] >= max) {
				max = tally[i];
				chosenDatasource = int(i);
			}
		}
	}
	
	function submitData(uint data)  //TODO, check that it is coming from the expected data source.
	public
	{
		require (maySubmit);
	    require (msg.sender == owner);
        distributePrize(data); // TODO
	}
	
	/************************** Player Functions *******************************/

	// To bet for a number between 1 and 10 both inclusive
	function bet(uint number) 
    public
	payable 
	{
		require (mayBet);
		require(!checkExists(players, msg.sender));
    	require(msg.value >= minBet && msg.value <= maxBet);

		playerInfo[msg.sender].amountBet = msg.value;
		playerInfo[msg.sender].numberSelected = number;
		playerInfo[msg.sender].datasource = -1; // use default for now.
		
		numPlayers += 1;
		players.push(msg.sender);
		totalBet += msg.value;
		
        emit Bet(msg.sender, number);
	}
	
	// https://ethereum.stackexchange.com/questions/729/how-to-concatenate-strings-in-solidity
	function showDataSource() 
	public 
	returns (string)
	{
		return datasourceString;
	}
	
	function showChosenDataSource() 
	public 
	returns (string)
	{
		require (!mayBet);
		require (chosenDatasource >= 0);
		return datasources[uint(chosenDatasource)];
	}
	
	function selectDataSource(uint dataSourceNum)
    public 
    {
		require (mayBet);
        require(checkExists(players, msg.sender));
        require(dataSourceNum >= 0 && dataSourceNum < datasources.length);
        playerInfo[msg.sender].datasource = int(dataSourceNum);
		emit SelectDataSource(msg.sender, dataSourceNum);
    }
   
	
	/************************** Helper Functions *******************************/
	
	function potentiallyDistributePrize() private {
        //if (numPlayers < maxAmountOfBets) return;
	    // the data sources have to agree
        uint agreement = 0;
	    distributePrize(agreement);
	}
	
	address[] winners;
	function distributePrize(uint winner) private {
		uint count = 0; 
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
	
	function kill()
	public 
	{
		if(msg.sender == owner)
			selfdestruct(owner);
	}

	function checkExists(address [] people, address person) private returns(bool) 
	{
		for(uint i = 0; i < people.length; i++){
			if(people[i] == person) 
				return true;
		}
		return false;
	}
	
	function strConcat(string _a, string _b) private returns (string){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory babbs = new string(_ba.length + _bb.length);
        bytes memory babb = bytes(babbs);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babb[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) babb[k++] = _bb[i];
        return string(babb);
    }

}
