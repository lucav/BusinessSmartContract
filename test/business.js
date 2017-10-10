var Business = artifacts.require("Business");
var ShareHolders = artifacts.require("ShareHolders");

contract('Business', function(accounts) {
  
  var business;

  var account_one = accounts[0];
  var account_two = accounts[1];
  var account_thr = accounts[2];

  var amount = 100;
  var voteDescription = "test";
  var voteSecretKey = "key";
  
  // beforeEach(function() {
  //     return Business.new(100, 51, 120)
  //     .then(function(instance) {
  //       business = instance;
  //     });
  // });
    
  it("should initialize shareholders", async function() {

    console.log("accounts: ",account_one, " ", account_two, " ", account_thr);

    business = await Business.new(100, 51, 0);

    try {
      await business.setInitialShareHolder(account_one, 60);    
      await business.setInitialShareHolder(account_two, 40);
    } catch (error){
      console.log(error);
      assert.fail();
    }

    assert.equal(60, await business.shareOf.call(account_one));
    assert.equal(40, await business.shareOf.call(account_two));
    assert.equal(100, await business.getshareInitilized.call());

  });
  
  it("should create a new proposal", async function() {
    
      var proposalId = -1;

      var bsh = await business.businessShareHolders.call();
      var businessShareHolders = await ShareHolders.at(bsh);
      var events = await businessShareHolders.ProposalAdded();
      
      // watch for changes
      await events.watch(function(error, event){
        if (!error){
          proposalId = event.args.proposalID.toNumber();
          console.log("proposalId: ", proposalId);
          console.log("proposalHolder: ", event.args.proposalHolder);
        }          
      });

      try {
        await business.newProposal(amount, voteDescription, voteSecretKey, {from: account_one});
      } catch (error) {
        console.log(error);
        await events.stopWatching();
        assert.fail();
      }

      await events.stopWatching();

      assert(proposalId == 0);
      var c = await businessShareHolders.numProposals.call();
      assert(c == 1, "proposal count is not 1 but ", c);
      
  });

    
  it("should submit a vote", async function() {
    
      var proposalId = 0;
      var bsh = await business.businessShareHolders.call();
      var businessShareHolders = await ShareHolders.at(bsh);
      events = await businessShareHolders.Voted();
      await events.watch(function(error, event){
        if (!error){
          console.log("Voted: ", event.args.voter, " ", event.args.position);
        }          
      });

      try {
        await business.vote(proposalId, true, {from: account_one});
      } catch (error) {
        console.log(error);
        await events.stopWatching();
        assert.fail();
      }
      await events.stopWatching();
  });

  it("should submit 2nd vote from account_two", async function() {
    
      var proposalId = 0;
      var bsh = await business.businessShareHolders.call();
      var businessShareHolders = await ShareHolders.at(bsh);
      events = await businessShareHolders.Voted();
      await events.watch(function(error, event){
        if (!error){
          console.log("Voted: ", event.args.voter, " ", event.args.position);
        }          
      });

      try {
        await business.vote(proposalId, false, {from: account_two});
      } catch (error) {
        console.log(error);
        await events.stopWatching();
        assert.fail();
      }
      await events.stopWatching();
  });

  it("should executeProposal", async function() {
          
      var proposalId = 0;

      var bsh = await business.businessShareHolders.call();
      var businessShareHolders = await ShareHolders.at(bsh);
      events = await businessShareHolders.ProposalTallied();
      await events.watch(function(error, event){
        if (!error){
          console.log("ProposalTallied!");
          console.log("Vote difference: ", event.args.result.toNumber());
          console.log("Total votes: ", event.args.quorum.toNumber());
          console.log("Result: ", event.args.active);
        }          
      });

      try {
        await business.executeProposal(proposalId, voteSecretKey, {from: account_one});
      } catch (error) {
        console.log(error);
        await events.stopWatching();
        assert.fail();
      }
      await events.stopWatching();
  });

  it("new shareholder should buy 50 for 5 eth", async function() {
    
    var buyAmount = 50;
    var buyCost = 5000000000000000000; // 5 eth

    events = await business.NewShareHolder();
    await events.watch(function(error, event){
      if (!error){
        console.log("NewShareHolder!");
        console.log("ShareHolder: ", event.args.shareHolder);
        console.log("Shares bought: ", event.args.shares.toNumber());
      }          
    });

    try {
      await business.buyShares(buyAmount, {from: account_thr, value: buyCost});
    } catch (error) {
      console.log(error);
      await events.stopWatching();
      assert.fail();
    }
    await events.stopWatching();
  });

});
