const ColoredGrid = artifacts.require("ColoredGrids");

contract("ColoredGrid", (accounts) => {
	it("getOwnedTokens returns empty when address owns no tokens", async() => {
		const instance = await ColoredGrid.deployed();
		let ownedTokens = await instance.getOwnedTokens(accounts[0]);
		assert.equal(ownedTokens.length, 0, "Returned array is not empty when user has no tokens");
	});

	it("generateGrid updates the balance of msg.sender", async() => {
		const instance = await ColoredGrid.deployed();
		await instance.generateGrid({from: accounts[0], value: 20000000000000000});
		let balance = await instance.balanceOf(accounts[0]);
		assert.equal(balance.toNumber(), 1, "Balance did not update after grid had been minted"); 
	});

	it("getOwnedTokens returns tokenIds when address owns tokens", async() => {
		const instance = await ColoredGrid.deployed();
		let ownedTokens = await instance.getOwnedTokens(accounts[0]);
		assert.equal(ownedTokens.length, 1, "Returned array is empty when user has tokens");
	});

	it("setMintCost changes mintCost", async() => {
		const instance = await ColoredGrid.deployed();
		let oldMintCost = await instance.mintCost();
		// Set new mintCost to 0.005 ether
		await instance.setMintCost(5000000000000000 , {from: accounts[0]});
		let newMintCost = await instance.mintCost();
		assert.notEqual(newMintCost, oldMintCost, "mintCost has not changed");
		assert.equal(newMintCost.toNumber(), 5000000000000000, "Updated mintCost is not expected value");
	});

	it("setMintCost can only be called by owner", async() => {
		const truffleAssert = require('truffle-assertions');	
		const instance = await ColoredGrid.deployed();
		await truffleAssert.reverts(instance.setMintCost(5000000000000000, {from: accounts[1]}), "Ownable: caller is not the owner");
	});
});
