// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

contract CoinFlip is VRFV2WrapperConsumerBase {
    // event returns requestId
    event CoinFlipRequest(uint256 requestId);

    // result of the coinflip
    event CoinFlipResult(uint256 requestId, bool didWin);

    struct CoinFlipStatus {
        uint256 fees; // payment (link token) to chainlink for returning random number
        uint256 randowWord; // random numbers returned by chainlink
        address player;
        bool didWin;
        bool fulfilled; // whether chainlink has fulfilled that request yet
        CoinFlipSelection choice;
    }

    enum CoinFlipSelection {
        HEADS,
        TAILS
    }

    address constant linkTokenAddress =
        0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address constant vrfWrapperAddress =
        0x708701a1DfF4f478de54383E49a627eD4852C816;

    uint256 entrtFees = 0.001 ether; // if win, twice back
    uint32 callBackGasLimit = 1_000_000; // how much gas chainlink is willing to spend for you. they need to call the function in our smart contract which requires gas.
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 3; // how many blocks should it wait to send the result back

    constructor()
        payable
        VRFV2WrapperConsumerBase(linkTokenAddress, vrfWrapperAddress)
    {}

    // request id to the status structure
    mapping(uint256 => CoinFlipStatus) public statuses;

    function flip(CoinFlipSelection choice) external payable returns (uint256) {
        require(msg.value == entrtFees, "Fees incorrect");

        uint256 requestId = requestRandomness(
            callBackGasLimit,
            requestConfirmations,
            numWords
        );

        statuses[requestId] = CoinFlipStatus({
            // vrfv2wrapper is an interface around the vrf wrapper address
            fees: VRF_V2_WRAPPER.calculateRequestPrice(callBackGasLimit),
            randowWord: 0,
            player: msg.sender,
            didWin: false,
            fulfilled: false,
            choice: choice
        });

        emit CoinFlipRequest(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        require(statuses[requestId].fees > 0, "Invalid request id");
        statuses[requestId].fulfilled = true;
        statuses[requestId].randowWord = randomWords[0];

        CoinFlipSelection result = CoinFlipSelection.HEADS;

        if (randomWords[0] % 2 == 0) {
            result = CoinFlipSelection.TAILS;
        }

        if (statuses[requestId].choice == result) {
            statuses[requestId].didWin = true;
            payable(statuses[requestId].player).transfer(entrtFees * 2);
        }

        emit CoinFlipResult(requestId, statuses[requestId].didWin);
    }

    function getStatus(
        uint256 requestId
    ) public view returns (CoinFlipStatus memory) {
        return statuses[requestId];
    }
}
