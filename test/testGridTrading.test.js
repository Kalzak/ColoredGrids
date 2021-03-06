const GridTrading = artifacts.require("GridTrading");

/*
 * Naming convention for token variables:
 * a = account
 * T = token
 * It = Incoming trade
 * Ot = Outgoing trade
 *
 * eg: a0T = all owned tokens by account 0
 * eg: a0T0 = account 0, token 0
 * eg: a1It3 = account 1, incoming trade 3
 * eg: a1It = all incoming trades to the account 1
 * eg: a2Ot0 = account 2, outgonig trade 0
 * eg: a2Ot = all outgoing trades from the account 2
 */

contract("GridTrading", (accounts) => {
	it("sendTrade creates an entry in incomingTrades for the recipient", async() => {
		const instance = await GridTrading.deployed();
		// Create grids on two accounts so a trade can be conducted
		await instance.generateGrid({from: accounts[0], value: 20000000000000000});
		await instance.generateGrid({from: accounts[1], value: 20000000000000000});
		// Get tokenIds for grids on accounts
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Start a trade
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[0], {from: accounts[0]});
		let a1It = await getIncomingTrades(instance, accounts[1]);
		assert.equal(a1It.length, 1, "New trade did not update the incomingTrade array");
	});

	it("sendTrade reverts on an invalid subgridId", async() => {
		const instance = await GridTrading.deployed();
		// Get tokenIds for grids on accounts
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Start a trade
		const truffleAssert = require("truffle-assertions");
		await truffleAssert.reverts(instance.sendTrade(accounts[1], 0, a0T[0], a1T[0], {from: accounts[0]}), "Trade to recipient already exists");
	});

	it("sendTrade creates an entry in outgoingTrades for the sender", async() => {
		const instance = await GridTrading.deployed();
		let a0Ot = await getOutgoingTrades(instance, accounts[0]);
		assert.equal(a0Ot.length, 1, "New trade did not update the outgoingTrade array");
	});

	it("sendTrade creates an entry in the trades mapping", async() => {
		const instance = await GridTrading.deployed();
		let a1It = await instance.getIncomingTrades(accounts[1]);
		let tradeObject = await instance.getTradeDetails(a1It[0]);
		// Confirm that the trade is correct by seeing if the sender is the same
		assert.equal(tradeObject.sender, accounts[0], "Sender in trade object does not match");
	});

	it("withdrawTrade removes the entry in outgoingTrades and incomingTrades when there is 1 trade", async() => {
		let instance = await GridTrading.deployed();
		// Get the tradeId of the current trade to be removed
		let a0Ot = await getOutgoingTrades(instance, accounts[0]);
		let a1It = await getIncomingTrades(instance, accounts[1]);
		assert.equal(a0Ot.length, 1, "Expected initial value of account0's outgoingTrades is incorrect");
		assert.equal(a1It.length, 1, "Expected initial value of account1's incomingTrades is incorrect");
		// Withdraw the trade
		await instance.withdrawTrade(a0Ot[0], {from: accounts[0]});
		// Check the length of lists has changes
		a0Ot = await getOutgoingTrades(instance, accounts[0]);
		a1It = await getIncomingTrades(instance, accounts[1]);
		assert.equal(a0Ot.length, 0, "Expected value of account0's outgoingTrades is not 0");
		assert.equal(a1It.length, 0, "Expected value of account1's incomingTrades is not 0");

	});

	it("sendTrade reverts on an invalid subgridId", async() => {
		const instance = await GridTrading.deployed();
		// Get tokenIds for grids on accounts
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Start a trade
		const truffleAssert = require("truffle-assertions");
		await truffleAssert.reverts(instance.sendTrade(accounts[1], 49, a0T[0], a1T[0], {from: accounts[0]}), "Invalid subgrid");
	});

	it("withdrawTrade removes the entry in outgoingTrades and incomingTrades when there is >1 trades", async() => {
		let instance = await GridTrading.deployed();
		// Generate tokens needed for trade	
		await instance.generateGrid({from: accounts[1], value: 20000000000000000});
		await instance.generateGrid({from: accounts[2], value: 20000000000000000});
		// Get tokens owned by 3 users
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		let a2T = await getOwnedTokens(instance, accounts[2]);
		// Send trade offers
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[0], {from: accounts[0]});
		await instance.sendTrade(accounts[1], 0, a2T[0], a1T[1], {from: accounts[2]});
		// Get the trade ID of the trade to be removed
		let a1It = await getIncomingTrades(instance, accounts[1]);
		assert.equal(a1It.length, 2, "Expected initial value of incoming is incorrect");
		// Withdraw the trade
		await instance.withdrawTrade(a1It[0], {from: accounts[0]});
		// Check if the number of incoming trades has reduced to 1
		a1It = await getIncomingTrades(instance, accounts[1]);
		assert.equal(a1It.length, 1, "Expected the number of incomingTrades to account1 to be 1");
		// Clean up by withdrawing the remaining trade
		await instance.withdrawTrade(a1It[0], {from: accounts[2]});

	});

	it("acceptTrade with grid swaps ownership of grids", async() => {
		let instance = await GridTrading.deployed();
		// Get the tokenIds that will be exchanged	
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Start a trade
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[0], {from: accounts[0]});
		// Get the trade ID for the trade that was just sent
		let a1It = await getIncomingTrades(instance, accounts[1]);
		// Get owner of tokens before trade
		let t0OwnerBefore = await instance.ownerOf(a0T[0]);
		let t1OwnerBefore = await instance.ownerOf(a1T[0]);
		// Accept the trade
		await instance.acceptTrade(a1It[0], {from: accounts[1]});
		// Get owner of tokens after trade
		let t0OwnerAfter = await instance.ownerOf(a0T[0]);
		let t1OwnerAfter = await instance.ownerOf(a1T[0]);
		// Check that the ownership has changed between tokens
		assert.equal(t0OwnerBefore, t1OwnerAfter, "Grids did not transfer");
		assert.equal(t0OwnerAfter, t1OwnerBefore, "Grids did not transfer");
	});

	it("acceptTrade with grid changes involved addresses ownedTokens[] data", async() =>{
		let instance = await GridTrading.deployed();
		// Get tokenIds of accounts to build trade
		let a0T_prev = await getOwnedTokens(instance, accounts[0]);
		let a1T_prev = await getOwnedTokens(instance, accounts[1]);
		// Construct the trade
		await instance.sendTrade(accounts[1], 0, a0T_prev[0], a1T_prev[0], {from: accounts[0]});
		// Accept the trade
		let a1It = await getIncomingTrades(instance, accounts[1]);
		await instance.acceptTrade(a1It[0], {from: accounts[1]});
		// Get new owned tokens and check if they have been swapped
		let a0T_new = await getOwnedTokens(instance, accounts[0]);
		let a1T_new = await getOwnedTokens(instance, accounts[1]);
		let a0T0_prev_owner = await instance.ownerOf(a0T_prev[0]); 
		let a0T0_new_owner = await instance.ownerOf(a0T_new[0]);
		let a1T0_prev_owner = await instance.ownerOf(a1T_prev[0]);
		let a1T0_new_owner = await instance.ownerOf(a1T_new[0]);
		assert.equal(a0T0_prev_owner, a1T0_new_owner, "Owner is not the expected owner");
		assert.equal(a1T0_prev_owner, a0T0_new_owner, "Owner is not the expected owner");
	});

	it("acceptTrade cancels other incoming and outgoing tradeoffers that depend on the grid that was moved", async() => {
		let instance = await GridTrading.deployed();
		// Get tokenIds of accounts to build trades
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		let a2T = await getOwnedTokens(instance, accounts[2]);
		// Construct trades
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[0], {from: accounts[0]});
		await instance.sendTrade(accounts[1], 0, a2T[0], a1T[0], {from: accounts[2]});
		// Accept one of the tradeOffers
		let a1It = await getIncomingTrades(instance, accounts[1]);
		let a1It0 = await instance.getTradeDetails(a1It[0]);
		await instance.acceptTrade(a1It[0], {from: accounts[1]});
		// Check if the other trade was cancelled due to grid tokenId dependency
		a1It = await getIncomingTrades(instance, accounts[1]);
		assert.equal(a1It.length, 0, "Existing trade that had a grid tokenID dependency was not removed");
	});

	it("declineTrade closes the trade", async() => {
		const instance = await GridTrading.deployed();
		// Get tokenIds for grids on accounts
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Start a trade
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[0], {from: accounts[0]});
		let a1It = await getIncomingTrades(instance, accounts[1]);
		// Decline the trade
		await instance.declineTrade(a1It[0], {from: accounts[1]});
		// Update incomingTrades to check if it has been removed
		a1It = await getIncomingTrades(instance, accounts[1]);
		assert.equal(a1It.length, 0, "Declining the trade offer did not remove the trade");
	});
	
	it("sendTrade with a subgrid swaps the subgrid data", async() => {
		const instance = await GridTrading.deployed();
		// Get tokenIds for grids on accounts
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Start a trade for subgrid identifier 11
		await instance.sendTrade(accounts[1], 11, a0T[0], a1T[0], {from: accounts[0]});
		// Get the tradeId
		let a1It = await getIncomingTrades(instance, accounts[1]);
		// Get the current subgrid data for each grid
		let a0T0_prev = await instance.getSubgridData(a0T[0], 11); 
		let a1T0_prev = await instance.getSubgridData(a1T[0], 11);
		// Accept the trade
		await instance.acceptTrade(a1It[0], {from: accounts[1]});
		// Get the new subgrid data for each grid
		let a0T0_new = await instance.getSubgridData(a0T[0], 11); 
		let a1T0_new = await instance.getSubgridData(a1T[0], 11);
		// Check if the data has been swapped
		assert.equal(a0T0_prev.toString(), a1T0_new.toString(), "Subgrid data was not swapped");
		assert.equal(a1T0_prev.toString(), a0T0_new.toString(), "Subgrid data was not swapped");
	});

	it("counterTradeOffer changes the trade", async() => {
		const instance = await GridTrading.deployed();
		// Get tokenIds for grids on accounts
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Start a trade
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[0], {from: accounts[0]});
		// Get the tradeId
		let a1It = await getIncomingTrades(instance, accounts[1]);
		// Get the trade object before change
		let tradeObject = await instance.getTradeDetails(a1It[0]);
		// Get ether offered for trade before
		let etherBefore = tradeObject.senderOffer;
		// Have the recipient send a counterOffer
		await instance.counterTrade(a1It[0], '100000000000000000', {from: accounts[1]});
		// Get the trade object after change
		tradeObject = await instance.getTradeDetails(a1It[0]);
		// Get ether offered for trade after
		let etherAfter = tradeObject.senderOffer;
		assert.notEqual(etherBefore, etherAfter, "Ether amount offered does not change on countertrade");	
		// Remove trade to cleanup for next test
		await instance.declineTrade(a1It[0], {from: accounts[1]});
	});

	it("acceptTrade will revert on a counter trade called by the recipient", async() => {
		let instance = await GridTrading.deployed();
		// Get tokenIds of accounts to build trades
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Construct the trade
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[1], {from: accounts[0]});
		// Get the incoming trade
		let a1It = await getIncomingTrades(instance, accounts[1]);
		// Send a counter trade
		await instance.counterTrade(a1It[0], 1000, {from: accounts[1]});
		// Sender attempts to accept trade
		const truffleAssert = require('truffle-assertions');
		await truffleAssert.reverts(instance.acceptTrade(a1It[0], {from: accounts[1]}), "error");
		// Withdraw the trade
		instance.withdrawTrade(a1It[0], {from: accounts[0]});
	});

	it("acceptTrade will revert on a non-counter trade called by the sender", async() => {
		let instance = await GridTrading.deployed();
		// Get tokenIds of accounts to build trades
		let a0T = await getOwnedTokens(instance, accounts[0]);
		let a1T = await getOwnedTokens(instance, accounts[1]);
		// Construct the trade
		await instance.sendTrade(accounts[1], 0, a0T[0], a1T[1], {from: accounts[0]});
		// Get the incoming trade
		let a1It = await getIncomingTrades(instance, accounts[1]);
		// Sender attempts to accept trade
		const truffleAssert = require('truffle-assertions');
		await truffleAssert.reverts(instance.acceptTrade(a1It[0], {from: accounts[0]}), "error");
		// Withdraw the trade
		instance.withdrawTrade(a1It[0], {from: accounts[0]});
	});

});

async function getOwnedTokens(instance, account) {
	let tokensUnformatted = await instance.getOwnedTokens(account);
	let tokensFormatted = new Array();
	let i;
	for(i = 0; i < tokensUnformatted.length; i++) {
		tokensFormatted.push(BigInt(tokensUnformatted[i]).toString());
	}
	return tokensFormatted;
}

async function getIncomingTrades(instance, account) {
	let tradesUnformatted = await instance.getIncomingTrades(account);
	let tradesFormatted = new Array();
	let i;
	for(i = 0; i < tradesUnformatted.length; i++) {
		tradesFormatted.push(BigInt(tradesUnformatted[i]).toString());
	}
	return tradesFormatted;
}

async function getOutgoingTrades(instance, account) {
	let tradesUnformatted = await instance.getOutgoingTrades(account);
	let tradesFormatted = new Array();
	let i;
	for(i = 0; i < tradesUnformatted.length; i++) {
		tradesFormatted.push(BigInt(tradesUnformatted[i]).toString());
	}
	return tradesFormatted;
}
