pragma solidity ^0.4.15;

import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./IterableMappingLib.sol";
import "./DateTimeLib.sol";

contract ShareHolders is Ownable {

  uint shareInitilized;
	IterableMappingLib.itmap shareHolders;
	uint public totalShares;
	uint public equityPrice;

	uint public minimumQuorum;
	uint public debatingPeriodInMinutes;
	Proposal[] public proposals;
	uint public numProposals;
	mapping (uint8 => uint) monthProfit;

	event ProposalAdded(uint proposalID, address proposalHolder, uint amountOfShare, string description);
	event Voted(uint proposalID, bool position, address voter);
	event ProposalTallied(uint proposalID, int result, uint quorum, bool active);
	event ChangeOfRules(uint newMinimumQuorum, uint newDebatingPeriodInMinutes);

	struct Proposal {			
		  address proposalHolder;
			uint amountOfShare;
			string description;
			uint votingDeadline;
			bool executed;
			bool proposalPassed;
			uint numberOfVotes;
			bytes32 proposalHash;
			Vote[] votes;
			mapping (address => bool) voted;
	}

	struct Vote {
			bool inSupport;
			address voter;
	}

  modifier onlyInitialization {
      require(shareInitilized < totalShares);
      _;
  }

  // contructor for initialize total share based on totalStartupShares
	function ShareHolders(uint totalStartupShares, uint minimumSharesToPassAVote, uint minutesForDebate) {
    
      changeVotingRules(minimumSharesToPassAVote, minutesForDebate);
  
      totalShares = totalStartupShares;
      shareInitilized = 0;    
			equityPrice = 0;
  }

  function setInitialShareHolder(address newshareholder, uint shares) onlyOwner onlyInitialization {
      require(shareInitilized + shares <= totalShares);
			IterableMappingLib.insert(shareHolders, newshareholder, shares);						
      shareInitilized += shares;    		
  }

	function shareOf(address who) public constant returns (uint256) {
    	return shareHolders.data[who].shares;
  }

	function balanceOf(address who) public constant returns (uint256) {
    	return shareHolders.data[who].balance;
  }

	function getshareInitilized() public constant returns (uint) {		
		return shareInitilized;
	}

	function addEquityBasedBalance(uint256 value) onlyOwner public constant returns (bool) {
    	
			uint256 total = 0;
			address lastaddress;

			for (uint i = IterableMappingLib.iterate_start(shareHolders); IterableMappingLib.iterate_valid(shareHolders, i); i = IterableMappingLib.iterate_next(shareHolders, i)) {
					var (shAddress, shares) = IterableMappingLib.iterate_get(shareHolders, i);
					
					uint256 balanceToAdd = value * shares / totalShares;
					total += balanceToAdd;
					lastaddress = shAddress;
					shareHolders.data[shAddress].balance += balanceToAdd;
			}
			// residual balance caused by approximations, added to the last shareholder...
			if (value > total && lastaddress != address(0)) {
					shareHolders.data[lastaddress].balance += (value - total);
			}

			uint8 month = DateTimeLib.getMonth(now); 
			if (month > 2) {
				monthProfit[month - 2] = 0;	
			} else if (month == 2) {
				monthProfit[10] = 0;	
			} else if (month == 1) {
				monthProfit[11] = 0;	
			}
			monthProfit[month] += value;

			return true;
  }

	function subBalance(address toWho, uint256 weiamount) onlyOwner public constant returns (bool) {
			shareHolders.data[toWho].balance -= weiamount;
			return true;
	}

   /**
     * Change voting rules
     *
     * Make so that proposals need tobe discussed for at least `minutesForDebate/60` hours
     * and all voters combined must own more than `minimumSharesToPassAVote` shares of token to be executed
     *
     * @param minimumSharesToPassAVote proposal can vote only if the sum of shares held by all voters exceed this number
     * @param minutesForDebate the minimum amount of delay between when a proposal is made and when it can be executed
		*/
	function changeVotingRules(uint minimumSharesToPassAVote, uint minutesForDebate) onlyOwner public {
			
			if (minimumSharesToPassAVote < 1 ) {
				minimumSharesToPassAVote = 1;
			}				
			minimumQuorum = minimumSharesToPassAVote;
			debatingPeriodInMinutes = minutesForDebate;
			ChangeOfRules(minimumQuorum, debatingPeriodInMinutes);
	}
	
	/**
		* Add Proposal
		*
		* Propose to issue an amount of new shares
		*
		* @param amount amount of share to add
		* @param voteDescription Description
		* @param voteSecretKey secret key for the proposal
		*/
	function newProposal(			
			uint amount,
			string voteDescription,
			string voteSecretKey,
			address proposalHolder
	)
			onlyOwner
			public			
	{
			require(amount > 0);
			uint proposalID = proposals.length++;
			Proposal storage p = proposals[proposalID];
			p.proposalHolder = proposalHolder;
			p.amountOfShare = amount;
			p.description = voteDescription;
			p.proposalHash = sha3(proposalHolder, amount, voteSecretKey);
			p.votingDeadline = now + (debatingPeriodInMinutes * 1 minutes);
			p.executed = false;
			p.proposalPassed = false;
			p.numberOfVotes = 0;
			
			ProposalAdded(proposalID, proposalHolder, amount, voteDescription);
			numProposals = proposals.length;
	}

	/**
		* Check if a proposal code matches
		*
		* @param proposalNumber ID number of the proposal to query
		* @param holder who create the proposal
		* @param amount amount of share to issue
		* @param voteSecretKey secret key of proposal
		*/
	function checkProposalCode(
			uint proposalNumber,
			address holder,
			uint amount,
			string voteSecretKey
	)		
			private
			constant
			returns (bool)
	{
			Proposal storage p = proposals[proposalNumber];
			return p.proposalHash == sha3(holder, amount, voteSecretKey);
	}

	/**
		* Log a vote for a proposal
		*
		* Vote `supportsProposal? in support of : against` proposal #`proposalNumber`
		*
		* @param proposalNumber number of proposal
		* @param supportsProposal either in favor or against it
		*/
	function vote(
			uint proposalNumber,
			bool supportsProposal,
			address shareHolder
	)
			onlyOwner
			public
	{
			require(proposalNumber < numProposals);
			Proposal storage p = proposals[proposalNumber];			
			require(p.voted[shareHolder] != true);

			uint voteID = p.votes.length++;
			p.votes[voteID] = Vote({inSupport: supportsProposal, voter: shareHolder});
			p.voted[shareHolder] = true;
			p.numberOfVotes = voteID + 1;
			Voted(proposalNumber,  supportsProposal, shareHolder);
	}

	/**
		* Finish vote
		*
		* Count the votes proposal #`proposalNumber` and execute it if approved
		*
		* @param proposalNumber proposal number
		* @param voteSecretKey optional: if the transaction contained a key, you need to send it
		*/
	function executeProposal(uint proposalNumber, string voteSecretKey) onlyOwner public {
			Proposal storage p = proposals[proposalNumber];

			// If it is past the voting deadline
			// and it has not already been executed
			// and the supplied code matches the proposal...
			require(now > p.votingDeadline && !p.executed	&& checkProposalCode(proposalNumber, p.proposalHolder, p.amountOfShare, voteSecretKey)); 

			// ...then tally the results
			uint quorum = 0;
			uint yea = 0;
			uint nay = 0;
			equityPrice = 0;

			for (uint i = 0; i < p.votes.length; ++i) {
					Vote storage v = p.votes[i];
					uint voteWeight = shareOf(v.voter);
					quorum += voteWeight;
					if (v.inSupport) {
							yea += voteWeight;
					} else {
							nay += voteWeight;
					}
			}

			require(quorum >= minimumQuorum); // Check if a minimum quorum has been reached

			if (yea > nay) {
					// Proposal passed; execute the transaction

					p.executed = true;
					// add new shares to totalshares
					totalShares += p.amountOfShare;					
					// set new equity price
					// 100 * profit in the previous solar month
					uint8 month = DateTimeLib.getMonth(now); 
					if (month > 1) {
						equityPrice = 100 * monthProfit[month - 1];
					} else {
						equityPrice = 100 * monthProfit[12];
					}				

					// for testing purpose
					if (equityPrice <= 0)
						equityPrice = 10;

					// require(equityPrice > 0);	

					p.proposalPassed = true;
			} else {
					// Proposal failed
					p.proposalPassed = false;
			}

			// Fire Events
			ProposalTallied(proposalNumber, int(yea - nay), quorum, p.proposalPassed);
	}	  
}
