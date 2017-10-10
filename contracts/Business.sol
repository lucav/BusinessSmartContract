pragma solidity ^0.4.15;

import "./ShareHolders.sol";

contract Business is Ownable {

	ShareHolders public businessShareHolders;

	event ReceivedEther(address indexed sender, uint weiamount);
	event Withdraw(address indexed who, uint weiamount);
	event Transfer(address indexed from, address indexed to, uint256 value);
	event NewShareHolder(address indexed shareHolder, uint shares);

	modifier onlyShareholders {
			require(businessShareHolders.shareOf(msg.sender) > 0);
			_;
	}

	function Business(uint totalStartupShares, uint minimumSharesToPassAVote, uint minutesForDebate) {
      businessShareHolders = new ShareHolders(totalStartupShares, minimumSharesToPassAVote, minutesForDebate);
	}

	function setInitialShareHolder(address newshareholder, uint shares) onlyOwner external {
			businessShareHolders.setInitialShareHolder(newshareholder, shares);
			NewShareHolder(newshareholder, shares);
	}

  function () payable {
			require(businessShareHolders.addEquityBasedBalance(msg.value));
      ReceivedEther(msg.sender, msg.value);
  }

	function withdrawFund(uint weiamount) external {
			require(weiamount > 0);
			require(businessShareHolders.shareOf(msg.sender) > 0); // if msg.sender is a shareholder
			require(businessShareHolders.balanceOf(msg.sender) >= weiamount);

			require(businessShareHolders.subBalance(msg.sender, weiamount));

      msg.sender.transfer(weiamount);
      Withdraw(msg.sender, weiamount);			
	}
	
	function balanceOf(address who) external constant returns (uint256) {
    	return businessShareHolders.balanceOf(who);
  }
	function shareOf(address who) external constant returns (uint256) {
    	return businessShareHolders.shareOf(who);
  }

	function transferTo(address _to, uint256 _weiamount) external {
    require(_to != address(0));
		require(_weiamount > 0);
		require(businessShareHolders.shareOf(msg.sender) > 0); // if msg.sender is a shareholder
		require(businessShareHolders.balanceOf(msg.sender) >= _weiamount);

		require(businessShareHolders.subBalance(msg.sender, _weiamount));

		_to.transfer(_weiamount);
    Transfer(msg.sender, _to, _weiamount);
  }

	function getBusinessBalance() external constant returns (uint) {
		return this.balance;
	}

	function getTotalShares() public constant returns (uint) {		
		return businessShareHolders.totalShares();
	}

	function getshareInitilized() public constant returns (uint) {		
		return businessShareHolders.getshareInitilized();
	}

	function newProposal(uint amount, string voteDescription, string voteSecretKey) onlyShareholders external {
 
		businessShareHolders.newProposal(amount, voteDescription, voteSecretKey, msg.sender);

		// if (!businessShareHolders.delegatecall(bytes4(sha3("newProposal(amount, voteDescription, voteSecretKey)")), amount, voteDescription, voteSecretKey)) {
		// 		revert();
		// }
		
	}

	function vote(uint proposalNumber, bool supportsProposal) onlyShareholders external {
		businessShareHolders.vote(proposalNumber, supportsProposal, msg.sender);		
	}

	function executeProposal(uint proposalNumber, string voteSecretKey) onlyShareholders external {
		businessShareHolders.executeProposal(proposalNumber, voteSecretKey);
	}

	function buyShares(uint shares) payable external {
		require(msg.value > 0);
		require(shares > 0);
		require(businessShareHolders.equityPrice() > 0);
		require(getshareInitilized() < getTotalShares());

		uint shareToSell = getTotalShares() - getshareInitilized();
		require(shares <= shareToSell);
		uint totalPrice = (shares / shareToSell) * businessShareHolders.equityPrice();

		require(totalPrice <= msg.value);
		businessShareHolders.setInitialShareHolder(msg.sender, shares);

		NewShareHolder(msg.sender, shares);
	}
}