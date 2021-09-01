pragma solidity ^0.8.0;

import "./ColoredGrids.sol";

contract GridTrading is ColoredGrids {
	// Struct format for subgrid trade offers
	struct Trade {
		// A unique identifier for the trade
		uint256 tradeId;
		// Sender of the offer
		address sender;
		// Recpient of the offer
		address recipient;
		// The ID of the subgrid to be traded
		// If subgridId is 0 then it is a grid trade
		uint8 subgridId;
		// The token ID of the senders grid
		uint256 senderGrid;
		// The token ID of the recipients grid
	        uint256 recipientGrid;
		// The amount of ether (if any) being offered by the sender
		uint256 senderOffer;
	}

	// Mapping from an address to an array of active incoming trade IDs
	mapping(address => uint256[]) public incomingTrades;

	// Mapping from an address to an arraf of active outgoing trades IDs
	mapping(address => uint256[]) public outgoingTrades;

	// Mapping from a trade ID to a trade struct
	mapping(uint256 => Trade) public trades;

	constructor(
		string memory name_,
		string memory symbol_
	) ColoredGrids(name_, symbol_) {}

	/**
	 * @dev Sends a trade offer. If subgridId is set to 0 then it is a grid trade. Otherwise it is a subgrid trade
	 */
	function sendTradeOffer(address recipient, uint8 subgridId, uint256 senderGrid, uint256 recipientGrid) public payable {
		// Generate the tradeId
		uint256 tradeId = uint256(keccak256(abi.encodePacked(msg.sender, recipient)));
		// Create the trade object
		Trade memory newTrade = Trade(tradeId, msg.sender, recipient, subgridId, senderGrid, recipientGrid, msg.value);
		// Check that there is not an existing trade send to the same recipient
		uint256[] storage senderOutgoingTrades = outgoingTrades[msg.sender];
		uint256 i = 0;
		bool existingTrade = false;
		while(i < senderOutgoingTrades.length && existingTrade == false) {
			if(senderOutgoingTrades[i] == tradeId) {
				existingTrade = true;
			}
			i++;
		}
		require(existingTrade == false, "You already have a pending trade to this address");
		// Add the trade object to the senders outgoing trade array
		senderOutgoingTrades.push(tradeId);
		// Add the trade object to the recipients incoming trade array
		incomingTrades[recipient].push(tradeId);
		// Add trade to the trades mapping
		trades[tradeId] = newTrade;
	}

	/**
	 * @dev An address that has sent a trade offer is able to withdraw the trade with this function
	 * @param tradeId the ID of the trade that is to be withdrawn
	 */
	function withdrawTradeOffer(uint256 tradeId) public {
		// Get the trade object
		Trade memory tradeObject = trades[tradeId];
		// Check that msg.sender is the creator of the trade
		require(msg.sender == tradeObject.sender, "You are not the creator of the trade");
		_removeTradeOffer(tradeId);
	}

	function _removeTradeOffer(uint256 tradeId) internal {
		// Get the trade object
		Trade memory tradeObject = trades[tradeId];
		// Remove the trade from the recipients address
		bool deleted = removeTradeFromArray(incomingTrades[tradeObject.recipient], tradeId);
		// Ensure that the tradeId was deleted
		require(deleted == true, "Trade does not exist in recipient array");
		// Remove the trade from the senders address
		deleted = removeTradeFromArray(outgoingTrades[tradeObject.sender], tradeId);
		// Ensure that the tradeId was deleted
		require(deleted == true, "Trade does not exist in sender array");
		// Remove trade from trades mapping
		delete trades[tradeId];
		// Return ether to the user
		(bool sent,) = payable(msg.sender).call{value: tradeObject.senderOffer}("");
	}

	/**
	 * @dev Removes an element that contains tradeId in the array and shuffled the array
	 * @param array The array to have data removed from
	 * @param tradeId The trade ID to be removed
	 */
	function removeTradeFromArray(uint256[] storage array, uint256 tradeId) internal returns (bool) {
		bool found = false;
		uint256 i = 0;
		// Iterate through each item in the array until the tradeId is found
		while(i < array.length && found == false) {
			if(array[i] == tradeId) {
				found = true;
				// If the array is size 1 then just pop
				if(array.length == 1) {
					array.pop();
				// Otherwise move the last element into its place and pop
				} else {
					array[i] = array[array.length - 1];
					array.pop();
				}
			}	
			i++;
		}
		// Return whether the item has been deleted
		return found;
	}

	/**
	 * @dev Accepts a trade and exchanges grids/subgrids/ether
	 */
	function acceptTradeOffer(uint256 tradeId) public {
		// Get the trade object
		Trade memory tradeObject = trades[tradeId];
		// Check that msg.sender is the recipient of the trade
		require(tradeObject.recipient == msg.sender, "msg.sender is not the recipient of the trade");
		// Different logic if it is a grid trade or a subgrid trade
		if(tradeObject.subgridId == 0) {
			// Exchange grids
			_transfer(tradeObject.sender, tradeObject.recipient, tradeObject.senderGrid);
			_transfer(tradeObject.recipient, tradeObject.sender, tradeObject.recipientGrid);
			_removeTokenFromAddress(tradeObject.sender, tradeObject.senderGrid);
			_removeTokenFromAddress(tradeObject.recipient, tradeObject.recipientGrid);
			_addTokenToAddress(tradeObject.sender, tradeObject.recipientGrid);
			_addTokenToAddress(tradeObject.recipient, tradeObject.senderGrid);
		} else {
			uint8 subgridId = tradeObject.subgridId;
			// Make sure that the subgridId is valid
			bool subgridIdIsValid = false;
			uint8[9] memory validSubgridIds = [6,7,8,10,11,12,14,15,16];
			uint i = 0;
			while(i < validSubgridIds.length && subgridIdIsValid == false) {
				if(validSubgridIds[i] == subgridId) {
					subgridIdIsValid = true;
				}
			}
			require(subgridIdIsValid = true, "SubgridId provided is invalid");
			// Load subgridData
			uint8[2] memory senderSubgridData = getSubgridData(tradeObject.senderGrid, subgridId);
			uint8[2] memory recipientSubgridData = getSubgridData(tradeObject.recipientGrid, subgridId);
			// Swap subgrids
			_changeSubgrid(tradeObject.senderGrid, subgridId, recipientSubgridData[0], recipientSubgridData[1]);
			_changeSubgrid(tradeObject.recipientGrid, subgridId, senderSubgridData[0], senderSubgridData[1]);
		}
		_removeTradeOffer(tradeId);
		// Settle ether payments
		(bool sent,) = payable(tradeObject.recipient).call{value: tradeObject.senderOffer}("");
		// Cancel all incoming/outgoing trades that depend on a grid that was involved in this trade 
		removeTradeByTokenId(getIncomingTrades(tradeObject.sender), tradeObject.senderGrid);
		removeTradeByTokenId(getOutgoingTrades(tradeObject.sender), tradeObject.senderGrid);
		removeTradeByTokenId(getIncomingTrades(tradeObject.recipient), tradeObject.recipientGrid);
		removeTradeByTokenId(getOutgoingTrades(tradeObject.recipient), tradeObject.recipientGrid);
	}
	
	/**
	 * @dev Looks through an array of trade IDs and deletes the trade if it contains tokenId as a senderGrid or recipientGrid
	 * @param tradeList An array of trades IDs
	 * @param tradeId The target token ID to be removed
	 */
	function removeTradeByTokenId(uint256[] memory tradeList, uint256 tradeId) internal {
		uint i;
		// For every tradeId in the array tradeList
		for(i = 0; i < tradeList.length; i++) {
			// Load the trade object
			Trade memory tradeObject = getTradeDetails(tradeList[i]);
			// Check if the trade contains tokenId as a senderGrid or recieverGrid
			if(tradeObject.senderGrid == tradeId || tradeObject.recipientGrid == tradeId) {
				// Remove the trade
				_removeTradeOffer(tradeList[i]);
			}
		}
	}

	/**
	 * @dev Returns an array of tradeIds for incoming trades to the address `account`
	 */
	function getIncomingTrades(address account) public view returns (uint256[] memory){
		return incomingTrades[account];
	}

	/**
	 * @dev Returns an array of tradeIds for outgoing trades to the address `account`
	 */
	function getOutgoingTrades(address account) public view returns (uint256[] memory){
		return outgoingTrades[account];
	}

	/**
	 * @dev Returns a trade with tradeId
	 */
	function getTradeDetails(uint256 tradeId) public view returns (Trade memory) {
		return trades[tradeId];
	}

}
