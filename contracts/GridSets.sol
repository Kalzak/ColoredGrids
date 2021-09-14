pragma solidity *0.8.0;

import "./GridTrading.sol";

contract GridSets is GridTrading {
	// Struct format to represent a set
	struct Set {
		// The four gridIds within the set
		uint256 g1;
		uint256 g2;
		uint256 g3;
		uint256 g4;
	}

	// Nonce to assist with random setId generation
	uint256 nonce;

	// Mapping from a set ID to a set
	mapping(uint256 => Set) public sets;

	// Mapping from an address to an array of sets
	mapping(address => uint256[]) public ownedSets;

	// Mapping from a gridId to a setId
	mapping(uint256 => uint256) public gridToSet;

	constructor(
		string memory name_,
		string memory symbol_
	) GridTrading(name_, symbol_) {
		// Initialize the nonce
		nonce = 0;
	}

	/**
	 * @dev Creates a set containing four grids
	 * @param g1 a gridId
	 * @param g2 a gridId
	 * @param g3 a gridId
	 * @param g4 a gridId
	 * @return the ID of the newly generated set
	 */
	function createSet(uint256 g1, uint256 g2, uint256 g3, uint256 g4) public returns(uint256){
		// Check if the given grids belong to the user
		require(ownerOf(g1) == msg.sender, "Not owner");
		require(ownerOf(g2) == msg.sender, "Not owner");
		require(ownerOf(g3) == msg.sender, "Not owner");
		require(ownerOf(g4) == msg.sender, "Not owner");
		// Generate a random number
		uint256 setId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce)));
		// Change the nonce
		nonce++;	
		// Create the set
		Set memory set = Set(g1, g2, g3, g4);
		// Put the set in the callers sets array
		ownedSets[msg.sender].push(setId);	
		// Set the mapping from the setId to the set object
		sets[setId] = set;
		// Update the mapping from grid to set for each grid
		gridToSet[g1] = setId;
		gridToSet[g2] = setId;
		gridToSet[g3] = setId;
		gridToSet[g4] = setId;
		// Return the ID of the newly generated set
		return setId;
	}

	/**
	 * @dev Deletes a set
	 * @param setId The ID of the set to be deleted
	 */
	function deleteSet(uint256 setId) public {
		// Require that msg.sender is the owner of the set
		(,bool found) = _findMatchingIndex(ownedSets[msg.sender], setId);
		require(found == true);
		// Load the set
		Set memory set = sets[setId];
		// Remove the mapping from grid to setId
		gridToSet[set.g1] = 0;
		gridToSet[set.g2] = 0;
		gridToSet[set.g3] = 0;
		gridToSet[set.g4] = 0;
		// Remove the setId from the array
		_removeValueFromArray(ownedSets[msg.sender], setId);
	}
}
