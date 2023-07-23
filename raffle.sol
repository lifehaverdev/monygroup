// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "../chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "../chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../erc721a/contracts/IERC721A.sol";

contract MiladyMakerPartyRaffle is VRFConsumerBaseV2, ConfirmedOwner {
    
    error RequestNotFound();
    error NeedWinner();
    error NeedLessWinners();

    event RequestSent(uint256 requestId, uint32 numWords);
    event partyFavor(address[] recipients, uint8[] which ,uint8[] count);
    event partyFavorNFT(address recipient, uint8 count, uint256 id);
    event loaded(uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests;
    VRFCoordinatorV2Interface COORDINATOR;

    uint64 s_subscriptionId;

    uint256[] public requestIds;
    uint256 public lastRequestId;

    //MMP Raffle
    uint256[] public randomness = [0,0,0,0,0,0];

    address[] public winners;
    uint16 public miladyWinnerCount;
    uint16 public remilioWinnerCount;
    uint16 public pixeladyWinnerCount;
    uint16 public mmpWinnerCount;

    //mainnet low gas lane
    bytes32 keyHash = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;

    IERC20 immutable _tmilx; // = IERC20(_miladyX);
    IERC20 immutable _tremx; // = IERC20(_remilioX);
    IERC20 immutable _tpixx; // = IERC20(_pixeladyX);
    IERC20 immutable _tmmpx; // = IERC20(_mmpX);
    IERC721A immutable _mmpt; // = IERC721A(_mmpNFT);

    /**
     * HARDCODED FOR MAINNET
     * COORDINATOR: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909
     */
    constructor(uint64 subscriptionId)
        VRFConsumerBaseV2(0x271682DEB8C4E0901D1a1550aD2e64D568E69909)
        ConfirmedOwner(msg.sender)      {
        COORDINATOR = VRFCoordinatorV2Interface(0x271682DEB8C4E0901D1a1550aD2e64D568E69909);
        s_subscriptionId = subscriptionId;

        _tmilx = IERC20(0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48);
        _tremx = IERC20(0xa35Bd2246978Dfbb1980DFf8Ff0f5834335dFdbc);
        _tpixx = IERC20(0xbC91A632E78db7c74508Ea26e91B266aa235F051);
        _tmmpx = IERC20(0xdaD370b2eb3D67EC2ff271827b5A2216a0122e87);
        _mmpt = IERC721A(0x05C63282c87f620aF5a658cBb53548257F3A6186);
    }

    function configureVRF(uint32 newGas, bytes32 newGasLane) public onlyOwner {
        callbackGasLimit = newGas;
        keyHash = newGasLane;
    }

    function fulfillRandomWords( uint256 _requestId, uint256[] memory _randomWords) internal override {
        RequestStatus memory request = s_requests[_requestId];
        if(!request.exists){ revert RequestNotFound();}
        request.fulfilled = true;
        uint8 len = uint8(_randomWords.length);
        for(uint8 i=0; i<len;){
            _randomWords[i] = _randomWords[i]%4833;
            //request a random number between 0 - 4833, the party meter weighted mmp list length - 1
            unchecked {
                i++;
            }
        }
        randomness = _randomWords;
        emit loaded(_randomWords);
    }

    function drawPrize(uint32 numWin) public payable onlyOwner {
        if(numWin==0){revert NeedWinner();}
        if(numWin>4){revert NeedLessWinners();}
        requestRandomWords(numWin*2);
    }

    function sendM(address recip) internal {
        _tmilx.transfer(recip,1.02e18);
        winners.push(recip);
        ++miladyWinnerCount;
    }
    function sendR(address recip) internal {
        _tremx.transfer(recip,1.02e18);
        winners.push(recip);
        ++remilioWinnerCount;
    }
    function sendP(address recip) internal {
        _tpixx.transfer(recip,1.02e18);
        winners.push(recip);
        ++pixeladyWinnerCount;
    }
    function sendMMPcoin(address recip) internal {
        _tmmpx.transfer(recip,1.02e18);
        winners.push(recip);
        ++mmpWinnerCount;
    }
    function sendMMPtoken(address recip, uint8 count, uint256 tokenId) public onlyOwner {
        _mmpt.safeTransferFrom(msg.sender,recip,tokenId);
        winners.push(recip);
        ++mmpWinnerCount;
        emit partyFavorNFT(recip,count,tokenId);
    }

    function checkCoin() public view returns(uint256[5] memory) {
        uint256[5] memory coins;
        coins[1] = _tmilx.balanceOf(address(this))/1e18;
        coins[2] = _tremx.balanceOf(address(this))/1e18;
        coins[3] = _tpixx.balanceOf(address(this))/1e18;
        coins[4] = _tmmpx.balanceOf(address(this))/1e18;
        return coins;
    }

    function withdrawCoins() public onlyOwner {
        require(
            _tmilx.transfer(msg.sender,_tmilx.balanceOf(address(this))),
            "Unable to transfer"
        );
        require(
            _tremx.transfer(msg.sender,_tremx.balanceOf(address(this))),
            "Unable to transfer"
        );
        require(
            _tpixx.transfer(msg.sender,_tpixx.balanceOf(address(this))),
            "Unable to transfer"
        );
        require(
            _tmmpx.transfer(msg.sender,_tmmpx.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function sendIt(address[] calldata wins, uint8[] calldata which, uint8[] calldata count) public onlyOwner {
        for (uint8 i = 0; i < wins.length;) {
            if(which[i] == 1) {
                sendM(wins[i]);
            }
            else if (which[i] == 2) {
                sendR(wins[i]);
            } else if (which[i] == 3) {
                sendP(wins[i]);
            } else if (which[i] == 4){
                sendMMPcoin(wins[i]);
            }
            unchecked {
                ++i;
            }
        }
        emit partyFavor(wins,which,count);
        reset();
    }
    
    function reset() internal {
        randomness = [0,0,0,0,0,0];
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

        // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint32 numWords)
        internal
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit*numWords,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }
}
