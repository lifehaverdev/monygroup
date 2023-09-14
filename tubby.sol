//SPDX-License-Identifier: MIT

import "../erc721a/contracts/ERC721A.sol";
import "../erc721a/contracts/interfaces/ERC721AQueryable.sol";
import "../erc721a/contracts/interfaces/ERC721ABurnable.sol";
import "../solady/src/auth/Ownable.sol";
import "../solady/src/utils/MerkleProofLib.sol";

pragma solidity ^0.8.17;

contract TubbyStation is ERC721A, ERC721AQueryable, ERC721ABurnable, Ownable {

    error TooMany(string err);
    error NotEnough(string err);
    error NoDice(string err);

    string public uri = '';
    bytes32 private root = '';
    bool public saleOn = false;
    
    mapping(address => bool) public freeMinted;

    constructor() ERC721A("TubbyStation", "TS") {
        _initializeOwner(msg.sender);
        _mint(msg.sender,12);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function configure(bytes32 newRoot, string calldata newUri) public onlyOwner {
        root = newRoot;
        uri = newUri;
    }

    function _baseURI() internal view virtual override(ERC721A) returns (string memory) {
        return uri;
    }
    
    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function flipSaleState() public onlyOwner {
        saleOn = !saleOn;
    }

    function checkList(bytes32[] calldata proof) internal view returns (bool){
        return MerkleProofLib.verifyCalldata(proof, root, keccak256(abi.encodePacked(bytes20(msg.sender))));
    }

    //root:
    //0x8846dd93fd368514683ee858b5e8216240896a3c0ebf50f3225e7a8552578c37

    //new root with cig
    //0xcb2a546e011166feb2ac77f98a545183bf9137fcd0dda1c9aad522a23ed442d5
    //cid
    //ipfs://bafybeibin567fwd3rfgp23t5mci7nftlhnkqoowr7oxwomua2jrtfb2rpm/

    function mint(uint256 amount) public payable{
        if(!saleOn){revert NoDice("Sale Not On");}
        if(msg.value < 10000000000000000*amount){revert NotEnough("Need Fee");}
        if(balanceOf(msg.sender) + amount > 8){revert TooMany("8/wallet max");}
        if(totalSupply()+amount > 365){revert TooMany("Exceeds Supply");}
        _mint(msg.sender,amount);
    }

    function freeMint(bytes32[] calldata proof) public {
        if(!saleOn){revert NoDice("Sale Not On");}
        if(!checkList(proof)){revert NoDice("Not on List");}
        if(totalSupply()+2 > 365){revert TooMany("Exceeds Supply");}
        if(freeMinted[msg.sender]){revert NoDice("Already Minted");}
        _mint(msg.sender,2);
        freeMinted[msg.sender] = true;        
    }
}