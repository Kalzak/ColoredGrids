var ColoredGrids = artifacts.require("ColoredGrids");

module.exports = function(deployer) {
	deployer.deploy(ColoredGrids, "ColoredGrid", "CG");
}
