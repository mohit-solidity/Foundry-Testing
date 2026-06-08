// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SubscriptionNFT is ERC721{
    address owner;
    uint tokenID;
    struct NFT{
        address creator;
        address user;
        uint expiry;
    }
    mapping(uint256=>NFT) public subscriptionDetails;
    mapping(address=>mapping(address=>uint)) private userTokenData;
    constructor(address _owner) ERC721("CreatorNFT","CNFT"){
        owner = _owner;
    }
    modifier onlyOwner(){
        require(msg.sender==owner,"Only Owner Can Mint NFT's");
        _;
    }
    function mintOrRenewNFT(address user,address creator,uint expiry) external onlyOwner{
        uint token = userTokenData[user][creator];
        if(token!=0){
            subscriptionDetails[token].expiry = expiry;
            return;
        }
        tokenID++;
        userTokenData[user][creator] = tokenID;
        _mint(user, tokenID);
        token = tokenID;
        subscriptionDetails[token] = NFT({creator:creator,user:user,expiry:expiry});
    }
    function isValidSubscription(address user,address creator) external view returns(bool){
        uint token = userTokenData[user][creator];
        if(token==0){
            return false;
        }
        return (subscriptionDetails[token].expiry>block.timestamp);
    }
    function getExpiry(address user,address creator) external view returns(uint){
        uint token = userTokenData[user][creator];
        require(token!=0,"No NFT");
        return (subscriptionDetails[token].expiry);
    }
}