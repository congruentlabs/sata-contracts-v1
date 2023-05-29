// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/ISignataRight.sol";

contract SignataNFTDrop {
  ISignataRight public signataRight;
  mapping(address => bool) public hasClaimed;

  struct DropData {
    uint256 startTimestamp;
    uint256 maxClaimableSupply;
    uint256 supplyClaimed;
    uint256 lastClaimTimestamp;
    uint256 schemaId;
  }

  DropData public dropData;
  
  constructor(ISignataRight _signataRight, uint256 _schemaId) {
    signataRight = _signataRight;
    dropData = DropData({
      startTimestamp: block.timestamp,
      schemaId: _schemaId,
      maxClaimableSupply: 100,
      supplyClaimed: 0,
      lastClaimTimestamp: 0,
    });
  }

  function claim(address reciever) public payable {
    require(signataRight.holdsTokenOfSchema(msg.sender, schemaId), "claim::Not a SATA 100 NFT Holder");
    require(!hasClaimed[msg.sender], "claim::Already claimed");

    dropData.supplyClaimed++;
    dropData.lastClaimTimestamp = block.timestamp;

    // send NFT to person
  }
}