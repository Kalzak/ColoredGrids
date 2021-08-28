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
		// Check that there is not an existing sent from msg.sender to recipient
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

	//TODO Check for re-entrancy attacks
	function withdrawTradeOffer(uint256 tradeId) public {
		// Get the trade object
		Trade memory tradeObject = trades[tradeId];
		// Check that msg.sender is the creator of the trade
		require(msg.sender == tradeObject.sender, "You are not the creator of the trade");
		// Remove the trade from the recipients address
		uint256[] storage recipientTrades = incomingTrades[tradeObject.recipient];
		uint256 i;
		bool found = false;
		while(i < recipientTrades.length && found == false) {
			if(recipientTrades[i] == tradeObject.tradeId) {
				delete recipientTrades[i];
				found = true;
			}
			i++;
		}		
		require(found == true, "Trade does not exist");
		// Remove the trade from the senders address
		uint256[] storage senderTrades = outgoingTrades[tradeObject.sender];
		found = false;
		while(i < senderTrades.length && found == false) {
			if(senderTrades[i] == tradeObject.tradeId) {
				delete recipientTrades[i];
				found = true;
			}
			i++;
		}		
		require(found == true, "Trade does not exist");
		// TODO: Remove trade from trades mapping
		// Return ether to the user
		payable(msg.sender).call{value: tradeObject.senderOffer}("");
	}


}
