//SPDX-License-Identifier: Unlicense

/**
    Evolver Nft Contract

    - Mint NFT
    - Add White List
    - Setting the mint price

 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Evolver is ERC721URIStorage{
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    mapping(address => bool) private owner;
    mapping(address => bool) private whiteList;

    Counters.Counter private _tokenIds;
    string private publicUrl;

    address private vault;

    constructor(address val ,string memory url) ERC721("Evolver", "EVO") {
        owner[msg.sender]=true;
        whiteList[msg.sender]=true;
        publicUrl = url;
        vault = val;
        
        doMint();
    }

    function mint()
        public
        returns (uint256)
    {
        //Confirm it have permission 
        verWhiteList ();
        //Confirm for the amount transaction
        pay();
        //Mint the new nft to address
        doMint();
    }

    function doMint()
    private
    {
        uint newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _tokenIds.increment();
        _setTokenURI(newItemId, string(abi.encodePacked(publicUrl,Strings.toString(newItemId))));
    }
    /**
    Auth
     */
     function verOwner () private
     {
        require(owner[msg.sender]);
     }
     function verWhiteList () private
     {
        require(whiteList[msg.sender]);
     }

    /**
    Payment
     */
     function pay() private
     {

     }

     /**
     Management
      */
      function permit(address[] memory add)public
      {
        require(owner[msg.sender]);
        for(uint i = 0; i < add.length; i++)
        {
            whiteList[add[i]]=true;
        }
      }
}