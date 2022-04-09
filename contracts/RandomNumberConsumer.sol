// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorMock.sol";
import "hardhat/console.sol";

contract RandomNumberConsumer is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    address vrfCoordinator;

    uint256 public randomResult;

    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Ethereum Mainnet
     * Chainlink VRF Coordinator address: 
     * LINK token address:                0x514910771AF9Ca656af840dff83E8264EcF986CA
     * Key Hash: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef
     */
    constructor(address _VRFCoordinatorMock, address _LINK) VRFConsumerBase(
        _VRFCoordinatorMock,
        _LINK
    ) {
        keyHash = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;
        fee = 0.25 * 10 ** 18;
        vrfCoordinator = _VRFCoordinatorMock;
    }

    /** 
     * Requests randomness 
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        requestId = requestRandomness(keyHash, fee);
        VRFCoordinatorMock(vrfCoordinator).callBackWithRandomness(requestId, 35000000000000000000, address(this));
        return requestId;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }
}
