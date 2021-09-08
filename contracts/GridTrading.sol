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
		// The ID of the subgrid to be traded, if 0 then it's a grid trade
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

	// Event for a tradeOffer being sent
	event tradeOfferSent(address sender, address recipient, uint8 subgridId, uint256 senderGrid, uint256 recipientGrid);

	// Event for tradeOffer being accepted
	event tradeOfferAccepted(address sender, address recipient);

	// Event for tradeOffer being declined
	event tradeOfferDeclined(address sender, address recipient);

	// Event for tradeOffer being withdrawn
	event tradeOfferWithdraw(address sender, address recipient);

	/**
	 * @dev Sends a trade offer. If subgridId is set to 0 then it is a grid trade. Otherwise it is a subgrid trade
	 */
	function sendTradeOffer(address recipient, uint8 subgridId, uint256 senderGrid, uint256 recipientGrid) public payable {
		// Generate the tradeId
		uint256 tradeId = uint256(keccak256(abi.encodePacked(msg.sender, recipient)));
		// Load the senders outgoing trades
		uint256[] storage senderOutgoingTrades = outgoingTrades[msg.sender];
		// Check that there is not an existing trade send to the same recipient
		(,bool found) = _findMatchingIndex(senderOutgoingTrades, tradeId);
		require(found == false, "You already have a pending trade to this address");
		// Create the trade object
		Trade memory newTrade = Trade(tradeId, msg.sender, recipient, subgridId, senderGrid, recipientGrid, msg.value);
		// Add the trade object to the senders outgoing trade array
		senderOutgoingTrades.push(tradeId);
		// Add the trade object to the recipients incoming trade array
		incomingTrades[recipient].push(tradeId);
		// Add trade to the trades mapping
		trades[tradeId] = newTrade;
		// Emit event
		emit tradeOfferSent(msg.sender, recipient, subgridId, senderGrid, recipientGrid);
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
		// Emit event
		emit tradeOfferWithdraw(tradeObject.sender, tradeObject.recipient);
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
				i++;
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
		payable(tradeObject.recipient).call{value: tradeObject.senderOffer}("");
		// Cancel all incoming/outgoing trades that depend on a grid that was involved in this trade 
		_removeTradeByTokenId(getIncomingTrades(tradeObject.sender), tradeObject.senderGrid);
		_removeTradeByTokenId(getOutgoingTrades(tradeObject.sender), tradeObject.senderGrid);
		_removeTradeByTokenId(getIncomingTrades(tradeObject.recipient), tradeObject.recipientGrid);
		_removeTradeByTokenId(getOutgoingTrades(tradeObject.recipient), tradeObject.recipientGrid);
		// Emit event
		emit tradeOfferAccepted(tradeObject.sender, tradeObject.recipient);
	}
	
	/**
	 * @dev Counters a trade offer that was sent to msg.sender by changing the eth amount
	 * @param tradeId The trade ID of the incoming trade to be modified
	 * @param newOfferValue The new amount of ether that the initial trade sender has to offer
	 */
	function sendCounterTrade(uint256 tradeId, uint256 newOfferValue) public {
		// A user can only send a counter trade if they are the recipient of a trade
		(,bool found) = _findMatchingIndex(incomingTrades[msg.sender], tradeId);
		require(found == true, "Given tradeId is not in your list of incomingTrades");	
		// Require that the new offer amount is higher than the existing offer amount
		Trade storage tradeObject = trades[tradeId];
		require(newOfferValue > tradeObject.senderOffer, "You cannot change the offer to be less than the original amount");
		// Set the new offer value
		tradeObject.senderOffer = newOfferValue;
		// Emit event
		emit tradeOfferSent(msg.sender, tradeObject.recipient, tradeObject.subgridId, tradeObject.senderGrid, tradeObject.recipientGrid);
	}

	/**
	 * @dev Declines a trade offer
	 */
	function declineTradeOffer(uint256 tradeId) public {
		// Get the trade object
		Trade memory tradeObject = trades[tradeId];
		// Check that msg.sender is the creator of the trade
		require(msg.sender == tradeObject.recipient, "You are not the recipient of the trade");
		_removeTradeOffer(tradeId);
		// Emit event
		emit tradeOfferDeclined(tradeObject.sender, tradeObject.recipient);
	}

	function _removeTradeOffer(uint256 tradeId) internal {
		// Get the trade object
		Trade memory tradeObject = trades[tradeId];
		// Remove the trade from the recipients address
		bool deleted = _removeTradeFromArray(incomingTrades[tradeObject.recipient], tradeId);
		// Ensure that the tradeId was deleted
		require(deleted == true, "Trade does not exist in recipient array");
		// Remove the trade from the senders address
		deleted = _removeTradeFromArray(outgoingTrades[tradeObject.sender], tradeId);
		// Ensure that the tradeId was deleted
		require(deleted == true, "Trade does not exist in sender array");
		// Remove trade from trades mapping
		delete trades[tradeId];
		// Return ether to the user
		payable(msg.sender).call{value: tradeObject.senderOffer}("");
	}

	/**
	 * @dev Removes all trades in the array tradeList that involve the grid token `gridId`
	 * @param tradeList An array of trade IDs
	 * @param gridId The target grid ID that needs to be removed
	 */
	function _removeTradeByTokenId(uint256[] memory tradeList, uint256 gridId) internal {
		uint i;
		// For every tradeId in the array tradeList
		for(i = 0; i < tradeList.length; i++) {
			// Load the trade object
			Trade memory tradeObject = getTradeDetails(tradeList[i]);
			// Check if the trade contains tokenId as a senderGrid or recieverGrid
			if(tradeObject.senderGrid == gridId || tradeObject.recipientGrid == gridId) {
				// Remove the trade
				_removeTradeOffer(tradeList[i]);
			}
		}
	}

	/**
	 * @dev Removes an element that contains tradeId in the array and shuffled the array
	 * @param array The array to have data removed from
	 * @param tradeId The trade ID to be removed
	 */
	function _removeTradeFromArray(uint256[] storage array, uint256 tradeId) internal returns (bool) {
		// Find the trade in the array
		(uint256 index, bool found) = _findMatchingIndex(array, tradeId);
		// If the array only has one item then pop
		if(array.length == 1) {
			array.pop();
		} else {
			array[index] = array[array.length - 1];
			array.pop();
		}
		return found; 
	}

	/**
	 * @dev Finds the index in a uint256 array where the contents match `target`. 
	 * @param array The array to be searched
	 * @param target The content that is being searched for
	 * @return -1 if no match, otherwise the matching index
	 */
	function _findMatchingIndex(uint256[] storage array, uint256 target) internal view returns (uint256, bool){
		// int256 to allow for -1 in the case of no match
		uint256 i = 0;
		bool found = false;
		if(array.length > 0) {
			// For every value in the array
			while(i < array.length && found == false) {
				// If the array contents match `target`
				if(array[i] == target) {
					// Set found to true to exit the loop
					found = true;
				}
				i++;
			}
			// Decrement i to account for the extra increment at the end of the loop
			i--;
		}	
		return (i, found);
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
