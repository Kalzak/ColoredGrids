var ColoredGrids = artifacts.require("ColoredGrids");
var GridTrading = artifacts.require("GridTrading");

module.exports = function(deployer) {
	deployer.deploy(ColoredGrids, "ColoredGrids", "CG")
	deployer.deploy(GridTrading, "ColoredGrids", "CG");
}
