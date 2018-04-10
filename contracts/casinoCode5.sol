pragma solidity ^0.4.20;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";


contract Casino is usingOraclize {
	address owner;

	uint minBet = 100 finney;
	uint maxBet = 1000 finney;
	
	uint totalBet;
	
	uint numPlayers;
	uint public constant MAX_NUM_PLAYERS = 100;
	
	// Oracle
    event newOraclizeQuery(string description);

    // player can bet on the point difference or the winning team. Winning condition for point is guess it right and the winning team
	// winner of points takes all, if none, ones guessing the winning team will split the pool
	struct Player {
		uint typeBet;  // 1 for guessing points, 2 for guessing win-loss
		uint numberSelected;  // the point difference
		uint winningTeam;  // 1 for team1, 2 for team2
		uint amountBet;
		int datasource;
	}
	
	address[] players;
	mapping(address => Player) playerInfo;
	
	//a data structure to store all the data sources, should be immutable upon construction!
	string[] datasources;
	int chosenDatasource = -1;
	string url = "";
	
	//https://ethereum.stackexchange.com/questions/11556/use-string-type-or-bytes32
	string constant datasource1 = "av17pn1rh1.execute-api.us-east-1.amazonaws.com/dev/";
	string datasourceString = "";
	
	// Control various stages of the contract
	bool mayBet = false;
	bool maySubmit = false;
	
	string team1Code = "";
	string team2Code = "";
	string matchDate = "";

	struct Result {
		uint winningTeam;
		uint pointDifference;
	}
	Result gameResult;
	uint unixGameEndTime;

	 
    event Bet(address indexed sender, uint indexed bet);
	event SelectDataSource(address indexed sender, uint indexed bet);
	//event DataSubmitted();
    event PrizeDistributed(address indexed sender, address[] indexed winners, uint prize);
    
    /**************************** Data sources ********************************/
    function check_score() public payable {
        emit newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
		// TODO: add true date
        oraclize_query("URL", url);
	}

    function __callback(bytes32 myid, string result) {
        require(msg.sender == oraclize_cbAddress());
		// TODO update/distribute T5 -> Result{winningTeam=1, pointDifference=5}
		bytes memory resultBytes = bytes(result);
		
        bytes memory teamByte = new bytes(1);
        teamByte[0] = resultBytes[0];
        gameResult.winningTeam = string(teamByte);
        
        bytes memory scoreBytes = new bytes(resultBytes.length - 1);
        for (uint i = 1; i < resultBytes.length; i ++) {
            scoreBytes = resultBytes[i];
        }
        gameResult.pointDifference = string(scoreBytes);
    }
 

	/************************** Owner Functions *******************************/
	function Casino(uint _minBet, uint _maxBet, string t1Code, string t2Code, 
	uint _unixGameEndTime) 
	public 
	{

		owner = msg.sender;
		if (_minBet > 0) minBet = _minBet;
    	if (_maxBet >= _minBet) maxBet = _maxBet;
    	if (_unixGameEndTime > 1523300000) unixGameEndTime = _unixGameEndTime;
    	team1Code = t1Code;
    	team2Code = t2Code;
		
    	datasources.push(datasource1);
	    datasourceString = strConcat(datasourceString, "0 : ");
	    datasourceString = strConcat(datasourceString, datasource1);
	    datasourceString = strConcat(datasourceString, "  |  ");
		
		mayBet = true;
		oraclize_setProof(proofType_TLSNotary);
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
		
		url = strConcat(url, datasources[uint(chosenDatasource)]);
		url = strConcat(url, team1Code);
		url = strConcat(url, "/");
		url = strConcat(url, team2Code);
		url = strConcat(url, "/");
		url = strConcat(url, matchDate);
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
	function bet(uint teamWon, uint pointDiff, uint betType) 
    public
	payable 
	{
		require (mayBet);
		require(!checkExists(players, msg.sender));
    	require(msg.value >= minBet && msg.value <= maxBet);
    	require(teamWon == 1 || teamWon == 2);
    	require(betType == 1 || betType == 2);
    	

		playerInfo[msg.sender].amountBet = msg.value;
		playerInfo[msg.sender].numberSelected = pointDiff;
		playerInfo[msg.sender].typeBet = betType;
		playerInfo[msg.sender].winningTeam = teamWon;
		playerInfo[msg.sender].datasource = -1; // use default for now.
		
		numPlayers += 1;
		players.push(msg.sender);
		totalBet += msg.value;
		
        emit Bet(msg.sender, teamWon);
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
	
	function strConcat(string _a, string _b) internal returns (string){
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
