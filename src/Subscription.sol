// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Import Libraries
import './subscriptionNFT.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Subscription is Ownable,ReentrancyGuard{
    bool locked;
    bool public paused;
    uint public feeCollected;
    uint64 public feeAPY = 200;

    struct Creator{
        string name;
        uint totalBalance;
        uint totalSubscribers;
        bool exists;
    }
    struct CreatorPlans{
        uint price;
        uint duration;
        bool isActive;
    }
    
    SubscriptionNFT public subscriptionNFT;

    // Mapping
    mapping(address=>Creator) public creatorProfile;
    mapping(address=>bool) public isCreator;
    mapping(string=>bool) public isValidUserName;
    mapping(address=>mapping(uint=>CreatorPlans)) public creatorPlans;
    mapping(address => mapping(address => uint)) public activePlan;
    mapping(address=>mapping(address=>uint)) public subscriptionBoughtDuration;
    mapping(address=>mapping(address=>bool)) public hasSubscribedBefore;
    address[] public creators;
    mapping(address=>uint[]) public craetorPlansArray;

    // ERRORS
    error NotTheCreator();
    error TransactionFailed();
    error NotEnoughBalance(uint amountToSend,uint balance);
    error InvalidAddress(address _invalid);

    // Events
    event CreatorAdded(address indexed _creator);
    event CreatorRemoved(address indexed _creator);
    event SubscriptionBought(address indexed _user,address indexed _creator,uint planId,uint amount,uint expiry);
    event CreatorWithdraw(address indexed _creator,uint amount);
    event OwnerWithdrawed(uint amount);
    event ContractPaused(uint time);
    event ContractResumed(uint time);
    event PlanAdded(address indexed creator, uint planId);
    event PlanDeactivated(address indexed creator, uint planId);
    event PlanActivated(address indexed Creator,uint planId);


    constructor() Ownable(msg.sender){
        isCreator[msg.sender] = true;
        subscriptionNFT = new SubscriptionNFT(address(this));
        creatorProfile[msg.sender].exists = true;
        creators.push(msg.sender);
    }

    // Modifiers
    modifier onlyCreator() {
        require(isCreator[msg.sender], "Not A Creator");
        require(creatorProfile[msg.sender].exists, "Creator profile missing");
        _;
    }

    modifier isActiveSubscription(address _creator){
        require(subscriptionBoughtDuration[msg.sender][_creator]>block.timestamp,"Subscription Ended");
        _;
    }
    modifier whenNotPaused(){
        require(!paused,"Contract Is Paused");
        _;
    }
    // Functions
    function pauseContract() public onlyOwner{
        require(!paused,"Already Paused");
        paused =true;
        emit ContractPaused(block.timestamp);
    }
    function resumeContract() public onlyOwner{
        require(paused,"Contract Not Paused");
        paused = false;
        emit ContractResumed(block.timestamp);
    }
    function changeFee(uint64 _APY) public onlyOwner{
        require(_APY >= 100 && _APY<=1000,"Max Fee Is 10%");
        feeAPY = _APY;
    }
    function addCreator(address _creator) public onlyOwner whenNotPaused{
        require(!isCreator[_creator],"Alrady The Creator");
        isCreator[_creator] = true;
        creatorProfile[_creator].exists = true;
        creators.push(_creator);
        emit CreatorAdded(_creator);
    }
    function removeCreator(address _creator) public onlyOwner whenNotPaused{
        if(!isCreator[_creator]){revert NotTheCreator();}
        isCreator[_creator] = false;
        Creator storage c = creatorProfile[_creator];
        isValidUserName[c.name] = false;
        creatorProfile[_creator].exists = false;
        emit CreatorRemoved(_creator);
    }
    function setCreatorData(string memory name) public onlyCreator whenNotPaused{
        Creator storage c = creatorProfile[msg.sender];
        require(!isValidUserName[name],"UserName Already Occupied");
        if (bytes(c.name).length != 0) {
            isValidUserName[c.name] = false;
        }
        c.name = name;
        isValidUserName[name] = true;
    }
    function addPlan(uint planId,uint _price,uint _duration) public onlyCreator{
        require(_price>0 && _price <= 1000,"Invalid price");
        require(_duration>0 &&  _duration<=365 days,"Invalid Duration");
        require(planId>0 && planId<=10000,"Plan Id Is Invalid");
        require(creatorPlans[msg.sender][planId].price == 0, "Plan exists");
        creatorPlans[msg.sender][planId] = CreatorPlans({
            price:_price,
            duration:_duration,
            isActive:true
        });
        craetorPlansArray[msg.sender].push(planId);
        emit PlanAdded(msg.sender, planId);
    }
    function activatePlan(uint planId) external onlyCreator{
        require(creatorPlans[msg.sender][planId].price != 0, "Plan not found");
        creatorPlans[msg.sender][planId].isActive = true;
        emit PlanActivated(msg.sender, planId);
    }
    function deActivatePlan(uint planId) external onlyCreator {
        require(creatorPlans[msg.sender][planId].price != 0, "Plan not found");
        creatorPlans[msg.sender][planId].isActive = false;
        emit PlanDeactivated(msg.sender, planId);
    }
    function buyOrRenewSubscription(address _creator,uint planId) public payable whenNotPaused{
        if(_creator == address(0)) revert InvalidAddress(address(0));
        if(!isCreator[_creator]) revert NotTheCreator();
        Creator storage c = creatorProfile[_creator];
        CreatorPlans memory p = creatorPlans[_creator][planId];
        require(c.exists,"Creator Doesn't exists");
        require(p.isActive, "Plan Not Active or Not Found");
        require(creatorPlans[_creator][planId].price != 0, "Plan not found");
        require(p.price!=0,"Craetor hasn't Set Their Monthly Pay Yet");
        require(msg.value==p.price,"Make sure To Send Same Amount Of User");
        require(subscriptionBoughtDuration[msg.sender][_creator]<block.timestamp,"Subscription Still Active");
        uint currentExpiry = subscriptionBoughtDuration[msg.sender][_creator];
        uint expiry;
        if(currentExpiry>block.timestamp){
            expiry = currentExpiry + (p.duration);
        }else{
            expiry = (block.timestamp+(p.duration));
        }
        if(!hasSubscribedBefore[msg.sender][_creator]){
            c.totalSubscribers ++;
        }
        subscriptionBoughtDuration[msg.sender][_creator] = expiry;
        uint fee = (msg.value*feeAPY)/10000;
        feeCollected += fee;
        uint amount = msg.value - fee;
        c.totalBalance += amount;
        subscriptionNFT.mintOrRenewNFT(msg.sender, _creator, expiry);
        hasSubscribedBefore[msg.sender][_creator] = true;
        activePlan[msg.sender][_creator] = planId;
        emit SubscriptionBought(msg.sender, _creator,planId, msg.value,expiry);
    }
    function giftSubscription(address _user,uint planId,address _creator) public payable whenNotPaused{
        if(_creator == address(0)) revert InvalidAddress(address(0));
        if(!isCreator[_creator]) revert NotTheCreator();
        Creator storage c = creatorProfile[_creator];
        require(c.exists,"Creator Doesn't exists");
        CreatorPlans memory p = creatorPlans[_creator][planId];
        require(subscriptionBoughtDuration[_user][_creator]<block.timestamp,"Subscription Still Active");
        require(p.isActive, "Plan not active");
        require(creatorPlans[_creator][planId].price != 0, "Plan not found");
        require(p.duration!=0,"Craetor hasn't Set Their Monthly Pay Yet");
        require(msg.value==p.price,"Make sure To Send Same Amount Creator Set");
        uint currentExpiry = subscriptionBoughtDuration[_user][_creator];
        uint expiry;
        if(currentExpiry>block.timestamp){
            expiry = currentExpiry + (p.duration);
        }else{
            expiry = (block.timestamp+(p.duration));
        }
        if(!hasSubscribedBefore[_user][_creator]){
            c.totalSubscribers ++;
        }
        subscriptionBoughtDuration[_user][_creator] = expiry;
        uint fee = (msg.value*feeAPY)/10000;
        feeCollected += fee;
        uint amount = msg.value - fee;
        c.totalBalance += amount;
        subscriptionNFT.mintOrRenewNFT(_user, _creator, expiry);
        hasSubscribedBefore[_user][_creator] = true;
        activePlan[_user][_creator] = planId;
        emit SubscriptionBought(_user, _creator,planId, msg.value,expiry);
    }
    function creatorWithdraw(uint amount) public onlyCreator nonReentrant whenNotPaused{
        Creator storage c = creatorProfile[msg.sender];
        if(amount>c.totalBalance) revert NotEnoughBalance(amount,c.totalBalance); 
        c.totalBalance -= amount;
        (bool success,) = payable(msg.sender).call{value:amount}("");
        if(!success) revert TransactionFailed();
        emit CreatorWithdraw(msg.sender, amount);
    }
    function isValidSubscription(address user,address _creator) public view returns(bool){
        return (subscriptionNFT.isValidSubscription(user,_creator));
    }
    function collectFee(uint amount) public onlyOwner whenNotPaused{
        if(amount>feeCollected) revert NotEnoughBalance(amount,feeCollected); 
        feeCollected -= amount;
        (bool success,) = payable(msg.sender).call{value:amount}("");
        if(!success) revert TransactionFailed();
        emit OwnerWithdrawed(amount);
    }
    function getAllCreators() public view returns(address[] memory){
        return creators;
    }
    receive() external payable {
        revert("Use Website For Buying Subscriptions");
     }
     fallback() external payable {
        revert("Invalid call");
    }
}