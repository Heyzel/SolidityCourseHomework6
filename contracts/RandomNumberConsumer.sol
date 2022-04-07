// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomNumberConsumer is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;

    uint256 public randomResult;

    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Ethereum Mainnet
     * Chainlink VRF Coordinator address: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
     * LINK token address:                0x514910771AF9Ca656af840dff83E8264EcF986CA
     * Key Hash: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef
     */
    constructor() VRFConsumerBase(
        0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
        0x514910771AF9Ca656af840dff83E8264EcF986CA
    ) {
        keyHash = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;
        fee = 0.25 * 10 ** 18;
    }

    /** 
     * Requests randomness 
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }
}
