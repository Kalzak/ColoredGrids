pragma solidity ^0.8.0;

import "./ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ColoredGrids is ERC721, Ownable {
	// The cost in ether to generate a new grid
	uint256 public mintCost;
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
		// The default mint cost is 0.01 ether
		mintCost = 10000000000000000;
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
		gridData[tokenId] = _generateGridData(tokenId);
		// Update `ownedTokens` to reflect the newly minted token
		ownedTokens[to].push(tokenId);

		emit Transfer(address(0), to, tokenId);
	}

	/**
	 * @dev Generates a random dataset to be used as grid data 
	 * @param tokenId used during the random number generation to prevent two grids being on the same block having the same value
	 * @return uint64 value of length 16 with no zeroes
	 */
	function _generateGridData(uint256 tokenId) internal view returns (uint64) {
		uint64 newGridData = 0;
		uint i;
		// `gridData` cannot contain zeroes, so we randomly generate values between 1 and 9 and add to `newGridData`
		for(i = 0; i < 16; i++) {
			// `i` is used as nonce to get a new value every time
			newGridData += uint64((1 + (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, tokenId, i))) % 9)) * (10 ** i));
		}
		return newGridData;
	}

	/**
	 * @dev Internal function to change a subgrid with new data
	 * @param tokenId the ID of the grid to be changed
	 * @param subGridId the ID of the subgrid within the grid to be changed
	 * @param subGridTop the top values of the subgrid concatenated to one number
	 * @param subGridBottom the bottom value of the subgrid concatenated to one number
	 * Refer to project summary PDF for explanation of the math used in this function
	 */
	function _changeSubgrid(uint256 tokenId, uint64 subGridId, uint64 subGridTop, uint64 subGridBottom) internal {
		// Change the top two values in the subgrid
		_changeGridData(tokenId, subGridId, subGridTop);
		// Change the bottom two values in the subgrid
		_changeGridData(tokenId, subGridId - 4, subGridBottom);
	}

	/**
	 * @dev Changes out two digits at `identifier` with `newValue`
	 * @param tokenId The id of the token that is being changed
	 * @param identifier The identifier for the slots that are being changed on the grid
	 * @param newValue the new value that is going to replace the existing value at `identifier`
	 * Refer to project summary PDF for explanation of subgrid identifiers
	 */
	function _changeGridData(uint256 tokenId, uint64 identifier, uint newValue) internal {
		// Load the existing grid data
		uint64 gridDataTemp = gridData[tokenId];
		// Calculate parts of the new grid data
		uint64 rightSide = uint64((gridDataTemp / (10**identifier)) * (10 ** identifier));
		uint64 middle = uint64(newValue * (10 ** (identifier - 2)));
		uint64 leftSide = uint64(gridDataTemp % (10 ** (identifier - 2)));
		// Combine the parts together and update `gridData`
		gridData[tokenId] = rightSide + middle + leftSide;
	}	

	/**
	 * @dev Returns grid data for the given token
	 * @param tokenId the ID of the grid
	 * @return uint64 of the grid data
	 */
	function getGridData(uint256 tokenId) public view returns (uint64) {
		return gridData[tokenId];
	}


	/**
	 * @dev Returns subgrid data for a given tokenId
	 */
	function getSubgridData(uint256 tokenId, uint8 subgridId) public view returns(uint8[2] memory) {
		uint8[2] memory subgridData;
		uint64 gridDataTemp = getGridData(tokenId);
		// Calculate the values based on the subgridId
		subgridData[0] = uint8(((gridDataTemp / (10 ** (subgridId - 1)) % 10) * 10) + ((gridDataTemp / (10 ** (subgridId - 2))) % 10));
		subgridData[1] = uint8(((gridDataTemp / (10 ** (subgridId - 5)) % 10) * 10) + ((gridDataTemp / (10 ** (subgridId - 6))) % 10));
		return subgridData;
	}

	/**
	 * @dev Returns tokenIds that belong to `user`
	 * @param user The address being queried
	 * @return uint256[] containing all tokenIds belonging to `user`
	 */
	function getOwnedTokens(address user) public view returns (uint256[] memory) {
		return ownedTokens[user];
	}

	/**
	 * @dev Mints a new token to `msg.sender`'s address if msg.value >= `mintCost` 
	 */
	function generateGrid() public payable {
		require(msg.value >= mintCost, "msg.value is less than the cost to generate a new grid");
		uint256 randTokenId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, ownedTokens[msg.sender].length )));
		_safeMint(msg.sender, randTokenId);
	}

	/**
	 * @dev Owner can set a new mint cost for generating grids
	 */
	function setMintCost(uint256 newMintCost) public onlyOwner() {
		mintCost = newMintCost;
	}	
}
