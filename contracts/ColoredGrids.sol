pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ColoredGrids is ERC721 {
	// The cost in ether to generate a new grid
	uint256 public mintCost = 0.01 ether;
	// Mapping from token ID to grid data
	mapping(uint256 => uint64) public gridData;
	// Mapping from owner to array of owned tokenIds
	mapping(address => uint256[]) public ownedTokens;

	/**
	 * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
	 */
	constructor(
		string memory name_, 
		string memory symbol_
	) ERC721(name_, symbol_) {
		// Nothing needs to be done in the cunstructor
	}
 	
	/**
	 * @dev Overriding the ERC721 `_mint` function to also generate values for gridData
	 */
	function _mint(address to, uint256 tokenId) internal override {
		require(to != address(0), "ERC721: mint to the zero address");
		require(!_exists(tokenId), "ERC721: token already minted");

		_beforeTokenTransfer(address(0), to, tokenId);

		_balances[to] += 1;
		_owners[tokenId] = to;
		
		// Generate the random number for `gridData`
		gridData[tokenId] = uint64(uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, tokenId))));
		// Update `ownedTokens` to reflect the newly minted token
		ownedTokens[to].push(tokenId);

		emit Transfer(address(0), to, tokenId);
	}

	/**
	 * @dev Internal function to change a subgrid with new data
	 * @param tokenId the ID of the grid to be changed
	 * @param subGridId the ID of the subgrid within the grid to be changed
	 * @param subGridTop the top values of the subgrid concatenated to one number
	 * @param subGridBottom the bottom value of the subgrid concatenated to one number
	 * Refer to project summary PDF for explanation of the math used in this function
	 */
	function _changeSubGrid(uint256 tokenId, uint64 subGridId, uint64 subGridTop, uint64 subGridBottom) internal {
		// Load the existing grid data
		uint64 gridDataTemp = gridData[tokenId];
		// Update the top of the subGrid
		gridDataTemp = uint64(((gridDataTemp/(10**subGridId))*(10**subGridId))+(subGridTop*(10**(subGridId-2)))+(gridDataTemp%(10**(subGridId-2))));
		// Update the bottom of the subgrid
		gridDataTemp = uint64((gridDataTemp/(10**(subGridId-4)))+(subGridBottom*(10**(subGridId-6)))+(gridDataTemp%(10**(subGridId-6))));
		// Save the new gridData
		gridData[tokenId] = gridDataTemp;
	}	

	/**
	 * @dev Returns grid data for the given token
	 * @param tokenId the ID of the grid
	 * @return uint64 of the grid data
	 */
	function getGridData(uint256 tokenId) public view returns (uint64) {
		return gridData[tokenId];
	}

	function getOwnedTokens(address user) public view returns (uint256[] memory) {
		return ownedTokens[user];
	}

	/**
	 * @dev Mints a new token to `msg.sender`'s address if msg.value >= `mintCost` 
	 */
	function generateGrid() public payable {
		require(msg.value >= mintCost, "msg.value is less than the cost to generate a new grid");
		uint256 randTokenId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
		_safeMint(msg.sender, randTokenId);
	}

	// TODO: Function to set `mintCost`.  Mintcost should be public so people can know about it
}
