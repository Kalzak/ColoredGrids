const GridTrading = artifacts.require("GridTrading");

contract("GridTrading", (accounts) => {
	it("sendTradeOffer creates an entry in incomingTrades for the recipient", async() => {
		const instance = await GridTrading.deployed();
		// Create grids on two accounts so a trade can be conducted
		await instance.generateGrid({from: accounts[0], value: 20000000000000000});
		await instance.generateGrid({from: accounts[1], value: 20000000000000000});
		// Get tokenIds for grids on accounts
		let a0tokenIds = await instance.getOwnedTokens(accounts[0]);
		let a1tokenIds = await instance.getOwnedTokens(accounts[1]);
		let a0token0IdBN = BigInt(a0tokenIds[0]);
		let a1token0IdBN = BigInt(a1tokenIds[0]);
		// Start a trade
		await instance.sendTradeOffer(accounts[1], 0, a0token0IdBN.toString(), a1token0IdBN.toString(), {from: accounts[0]});
		let incoming = await instance.getIncomingTrades(accounts[1]);
		assert.equal(incoming.length, 1, "New trade did not update the incomingTrade array");
	});

	it("sendTradeOffer creates an entry in outgoingTrades for the sender", async() => {
		const instance = await GridTrading.deployed();
		let outgoing = await instance.getOutgoingTrades(accounts[0]);
		assert.equal(outgoing.length, 1, "New trade did not update the outgoingTrade array");
	});

	it("sendTradeOffer creates an entry in the trades mapping", async() => {
		const instance = await GridTrading.deployed();
		let tradeId = await instance.getIncomingTrades(accounts[1]);
		let tradeIdBN = BigInt(tradeId);
		let tradeObject = await instance.getTradeDetails(tradeIdBN.toString());
		// Confirm that the trade is correct by seeing if the sender is the same
		assert.equal(tradeObject.sender, accounts[0], "Sender in trade object does not match");
	});

	it("withdrawTradeOffer removes the entry in outgoingTrades and incomingTrades when there is 1 trade", async() => {
		let instance = await GridTrading.deployed();
		// Get the tradeId of the current trade to be removed
		let outgoingTrades = await instance.getOutgoingTrades(accounts[0]);
		assert.equal(outgoingTrades.length, 1, "Expected initial value of outgoingTrades is incorrect");
		let incomingTrades = await instance.getIncomingTrades(accounts[1]);
		assert.equal(incomingTrades.length, 1, "Expected initial value of incoming is incorrect");
		let incomingTrade = BigInt(incomingTrades[0]);
		// Withdraw the trade
		await instance.withdrawTradeOffer(incomingTrade.toString(), {from: accounts[0]});
		// Check the length of lists has changes
		outgoingTrades = await instance.getOutgoingTrades(accounts[0]);
		assert.equal(outgoingTrades.length, 0, "Expected value is not 0");
		incomingTrades = await instance.getIncomingTrades(accounts[1]);
		assert.equal(incomingTrades.length, 0, "Expected value is not 0");
	});

	it("withdrawTradeOffer removes the entry in outgoingTrades and incomingTrades when there is >1 trades", async() => {
		let instance = await GridTrading.deployed();
		// Create two trades	
		await instance.generateGrid({from: accounts[1], value: 20000000000000000});
		await instance.generateGrid({from: accounts[2], value: 20000000000000000});
		let a0tokenIds = await instance.getOwnedTokens(accounts[0]);
		let a1tokenIds = await instance.getOwnedTokens(accounts[1]);
		let a2tokenIds = await instance.getOwnedTokens(accounts[2]);
		let a0token0IdBN = BigInt(a0tokenIds[0]);
		let a1token0IdBN = BigInt(a1tokenIds[0]);
		let a1token1IdBN = BigInt(a1tokenIds[1]);
		let a2token0IdBN = BigInt(a2tokenIds[0]);
		await instance.sendTradeOffer(accounts[1], 0, a0token0IdBN.toString(), a1token0IdBN.toString(), {from: accounts[0]});
		await instance.sendTradeOffer(accounts[1], 0, a2token0IdBN.toString(), a1token1IdBN.toString(), {from: accounts[2]});
		// Get the tradeId of the current trade to be removed
		let incomingTrades = await instance.getIncomingTrades(accounts[1]);
		assert.equal(incomingTrades.length, 2, "Expected initial value of incoming is incorrect");
		let incomingTrade = BigInt(incomingTrades[0]);
		// Withdraw the trade
		await instance.withdrawTradeOffer(incomingTrade.toString(), {from: accounts[0]});
		// Check the length of lists has changes
		incomingTrades = await instance.getIncomingTrades(accounts[1]);
		assert.equal(incomingTrades.length, 1, "Expected value is not 0");
		// Withdraw trade at the end
		incomingTrade = BigInt(incomingTrades[0]);
		await instance.withdrawTradeOffer(incomingTrade.toString(), {from: accounts[2]});
	});

	it("acceptTradeOffer on a grid swaps the grids between users", async() => {
		let instance = await GridTrading.deployed();
		// Get the two tradeIds that will be exchanged
		let a0tokenIds = await instance.getOwnedTokens(accounts[0]);
		let a1tokenIds = await instance.getOwnedTokens(accounts[1]);
		let a0token0IdBN = BigInt(a0tokenIds[0]);
		let a1token0IdBN = BigInt(a1tokenIds[1]);

		// Start a trade
		await instance.sendTradeOffer(accounts[1], 0, a0token0IdBN.toString(), a1token0IdBN.toString(), {from: accounts[0]});
		// Get the tradeId for the trade that was just made
		let incomingTrades = await instance.getIncomingTrades(accounts[1]);
		let incomingTrade = BigInt(incomingTrades[0]);
		let tradeData = await instance.getTradeDetails(incomingTrade);
		let a0t0Owner = await instance.ownerOf(a0token0IdBN.toString());
		let a1t0Owner = await instance.ownerOf(a1token0IdBN.toString());
		// Accept the trade
		await instance.acceptTradeOffer(incomingTrade.toString(), {from: accounts[1]});
		// Get owned tokens
		let newa0t0Owner = await instance.ownerOf(a0token0IdBN.toString());
		let newa1t0Owner = await instance.ownerOf(a1token0IdBN.toString());
		assert.equal(a0t0Owner, newa1t0Owner, "Grids did not transfer");
		assert.equal(a1t0Owner, newa0t0Owner, "Grids did not transfer");
		
	});

	it("acceptTradeOffer cancels other incoming and outgoing tradeoffers that depend on the grid that was moved", async() => {
		assert.equal(true, false, "Not implemented (TODO)");
	});

});
