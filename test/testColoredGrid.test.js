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
		const instance = await ColoredGrid.deployed();
		const truffleAssert = require('truffle-assertions');	
		await truffleAssert.reverts(instance.setMintCost(5000000000000000, {from: accounts[1]}), "Ownable: caller is not the owner");
	});

	it("generateGrid creates gridData that is always of length 16", async() => {
		const instance = await ColoredGrid.deployed();
		let ownedGrids = await instance.getOwnedTokens(accounts[0]);
		let tokenId = await BigInt(ownedGrids[0]);
		let gridData = await instance.getGridData(tokenId.toString());
		assert.equal(gridData.toString().length, 16, "gridData is not 16 digits");
	});

	it("generateGrid creates gridData that does not contain zeroes", async() => {
		const instance = await ColoredGrid.deployed();
		let ownedGrids = await instance.getOwnedTokens(accounts[0]);
		let tokenId = await BigInt(ownedGrids[0]);
		let gridData = await instance.getGridData(tokenId.toString());
		assert.equal(gridData.toString().includes("0"), false, "gridData is not 16 digits");
	});

	it("getSubgridData returns valid data (between 11 and 99)", async() => {
		const instance = await ColoredGrid.deployed();
		let ownedGrids = await instance.getOwnedTokens(accounts[0]);
		let tokenId = await BigInt(ownedGrids[0]);
		let subgridData = await instance.getSubgridData(tokenId.toString(), 11);
		assert.equal(subgridData[0].toNumber() > 11 && subgridData[0].toNumber() < 99, true, "invalid return value");
	});
});
