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
		uint pointDifference;  // 404 means error
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
		
        uint resultCode = uint(resultBytes[0]);
        if (resultCode == 70) {//F
            gameResult.winningTeam = 2;
        } else if (resultCode == 84) { //T
             gameResult.winningTeam = 1;
        } else {
             gameResult.winningTeam = 5;
        }
        
        uint size = 0;
        for (uint i = 1; i < resultBytes.length; i ++) {
            if (uint(resultBytes[i]) == 0) break;
            size ++;
        }
        
        int sum = 0;
        int base = 10;
        bool first =  true;
        for (i = size - 1; i >= 0; i --) {
            int curr = int(resultBytes[i]);
            if (first == true) {
                sum += curr;
                first = false;
                continue;
            }
            sum += curr * base;
            base = base * 10;
        }
        gameResult.pointDifference = uint(sum);
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
	
	/// this function will try to settle the game result. The user calls it with
	/// the unix time of current time. If time is lower, does not allow endGame
	/// if time is bigger, fetch data. If error, kickout the user
	
	function endGame(uint currTime) 
	payable
	public
	{
		if (currTime > unixGameEndTime) {
	        check_score();
		}
	}
	
	function kickUser(address user) internal
	{
	    delete playerInfo[user];
	}
	
	/************************** Player Functions *******************************/

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
	    distributePrize(gameResult);
	}
	
	address[] winners;    // both point and winnning team
	address[] subWinners; // only winning team
	function distributePrize(Result r) private {
		uint count = 0;
		uint subCount = 0;
		for (uint i = 0; i < players.length; i++) {
			address player = players[i];
			if (playerInfo[player].winningTeam == r.winningTeam) {
			    subWinners.push(player);
			    if (playerInfo[player].numberSelected == r.pointDifference) {
			        winners.push(player);
			        count++;
			    }
				subCount++;
			}
			delete playerInfo[player];  // delete the player after insnsertion.
		}
        
        if (count > 0) {
            // people winning points and win/lose
		    uint winnerEtherAmount = totalBet / winners.length;
		    for (i = 0; i < count; i++) {
		    	if ( winners[i] != address(0)) { 
		    		// not null
		    		winners[i].transfer(winnerEtherAmount);
		    	}
		    }
		    emit PrizeDistributed(address(this), winners, winnerEtherAmount);
        } else if (subCount > 0) {
            // only winning the win/loss portion, split the sub_winning
            winnerEtherAmount = totalBet / subWinners.length;
		    for (i = 0; i < subCount; i++) {
		    	if ( subWinners[i] != address(0)) { 
		    		// not null
		    		subWinners[i].transfer(winnerEtherAmount);
		    	}
		    }
		    emit PrizeDistributed(address(this), subWinners, winnerEtherAmount);
 
        } else {
        	// no one wins
        	for (i = 0; i < players.length; i++) {
		    	if ( players[i] != address(0)) { 
		    		// not null
		    		players[i].transfer(playerInfo[players[i].amountBet]);
		    	}
		    }
        }
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
