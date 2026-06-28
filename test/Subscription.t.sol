// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Subscription} from "../src/Subscription.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SubscriptionTest is Test{
    Subscription public sub;
    address owner = makeAddr("owner");
    address creator1 = makeAddr("creator1");
    address creator2 = makeAddr("creator2");

    function setUp() public {
        vm.startPrank(owner);
        sub = new Subscription();
        sub.addCreator(creator1);
        sub.addCreator(creator2);
        vm.stopPrank();
    }
    function testFuzz_ChangeFee(uint64 _fee) public{
        vm.assume(_fee>=100);
        vm.assume(_fee <=1000);
        vm.prank(owner);
        sub.changeFee(_fee);
        assertEq(_fee,sub.feeAPY());
    }
    function test_Pause() public {
        vm.prank(owner);
        sub.pauseContract();
        assertTrue(sub.paused());

        vm.expectRevert("Already Paused");
        vm.prank(owner);
        sub.pauseContract();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector,address(this)));
        sub.pauseContract();
    }
    function test_resume() public {
        vm.startPrank(owner);
        sub.pauseContract();
        sub.resumeContract();
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        sub.resumeContract();
        assertFalse(sub.paused());
    }
    function testFuzz_SetCreatorData(string memory name) public {
        vm.assume(bytes(name).length>0);
        vm.prank(creator1);
        sub.setCreatorData(name);
        (string memory _name,,,) = sub.creatorProfile(creator1);
        assertEq(_name, name);
        //Another Creator Can't Take Same Name
        vm.expectRevert("UserName Already Occupied");
        vm.prank(creator2);
        sub.setCreatorData(name);
    }
    //Set Creator Data That is Already Used By Another Creator, But Later Change'd By Previous Creator
    function testFuzz_UsedName(string memory name1,string memory name2) public {
        vm.assume(bytes(name1).length>0);
        vm.assume(bytes(name2).length>0);
        if (keccak256(bytes(name1)) == keccak256(bytes(name2))) {
            name2 = string(abi.encodePacked(name2, "unique_suffix"));
        }
        vm.prank(creator1);
        sub.setCreatorData(name1);
        vm.expectRevert("UserName Already Occupied");
        vm.prank(creator2);
        sub.setCreatorData(name1);
        //Creator 1 Change His UserName
        vm.prank(creator1);
        sub.setCreatorData(name2);
        //Creator 2 Takes 1st Creator's Previous UserName
        vm.prank(creator2);
        sub.setCreatorData(name1);
        //Creator 2 Can't Take 1st Creator's Change'd UserName
        vm.expectRevert("UserName Already Occupied");
        vm.prank(creator2);
        sub.setCreatorData(name2);
    }
    function testFuzz_addPlan(uint planId,uint price,uint duration) public{
        uint _planId = bound(planId,1,10000);
        uint _price = bound(price,1,1000);
        uint _duration = bound(duration,1 days,365 days);
        vm.expectEmit(true, false, false, true,address(sub));
        emit Subscription.PlanAdded(creator1,_planId);
        vm.prank(creator1);
        sub.addPlan(_planId,_price,_duration);
        (uint cprice,uint cduration,bool isActive) = sub.creatorPlans(creator1,_planId);
        assertEq(_price, cprice);
        assertEq(_duration,cduration);
        assertTrue(isActive);
    }
    function testFuzz_AddPlan_RevertForNotCreator(address randomUser,uint _planId,uint _price,uint _duration) public {
        uint planId = bound(_planId,1,10000);
        uint price = bound(_price,1,1000);
        uint duration = bound(_duration,1 days,365 days);
        vm.assume(randomUser != owner);
        vm.assume(randomUser != creator1);
        vm.assume(randomUser != creator2);
        vm.assume(randomUser != address(0));
        vm.expectRevert("Not A Creator");
        vm.prank(randomUser);
        sub.addPlan(planId, price, duration);
    }
    //Creator Can Activate Again It's Deactivated Plan
    function testFuzz_ActiveAgain(uint _planId,uint _price,uint _duration) public {
        uint planId = bound(_planId,1,10000);
        uint price = bound(_price,1,1000);
        uint duration = bound(_duration,1 days,365 days);
        vm.startPrank(creator1);
        sub.addPlan(planId, price, duration);
        //Creator 1 Deactivate The Plan
        vm.expectEmit(true, false, false, true,address(sub));
        emit Subscription.PlanDeactivated(creator1,planId);
        sub.deActivatePlan(planId);
        vm.stopPrank();
        //check If It's DeActivated
        (,,bool isActive) = sub.creatorPlans(creator1,planId);
        assertFalse(isActive);
        //Creator Activate Again
        vm.expectEmit(true, false, false, true,address(sub));
        emit Subscription.PlanActivated(creator1,planId);
        vm.prank(creator1);
        sub.activatePlan(planId);
        (,,isActive) = sub.creatorPlans(creator1,planId);
        assertTrue(isActive);
    }
    function testFuzz_BuySubscription(uint _price,uint _planId,uint _duration) public {
        uint planId = bound(_planId,1,10000);
        uint price = bound(_price,1 ether,1000 ether);
        uint duration = bound(_duration,1 days,365 days);
        vm.prank(creator1);
        //Creator Set His Plans
        sub.addPlan(planId, price, duration);
        //User Buy Creator Plan
        address user = makeAddr("user");
        vm.deal(user,price);
        vm.expectEmit(true, true, false, true,address(sub));
        emit Subscription.SubscriptionBought(user,creator1,planId,price,(block.timestamp + duration));
        vm.prank(user);
        sub.buyOrRenewSubscription{value:price}(creator1, planId);
        uint fee = sub.feeCollected();
        uint remBalance = price - fee;
        (,uint totalBalance,uint totalSubscribers,) = sub.creatorProfile(creator1);
        console.log(totalBalance);
        console.log(remBalance);
        vm.assertEq(totalBalance, remBalance);
        vm.assertEq(totalSubscribers, 1);
        //User Can Buy Again When Expired
        vm.warp(duration+1 days);
        vm.expectEmit(true, true, false, true,address(sub));
        emit Subscription.SubscriptionBought(user,creator1,planId,price,(block.timestamp + duration));
        vm.deal(user,price);
        vm.prank(user);
        sub.buyOrRenewSubscription{value:price}(creator1, planId);
        (,totalBalance,totalSubscribers,) = sub.creatorProfile(creator1);
        remBalance = totalBalance - fee;
        fee = sub.feeCollected();
        console.log(totalBalance);
        console.log(remBalance);
        console.log("Remaining Fee");
        console.log(fee);
    }
    function testFuzz_GiftSubscription(uint _price,uint _planId,uint _duration) public {
        uint planId = bound(_planId,1,10000);
        uint price = bound(_price,1 ether,1000 ether);
        uint duration = bound(_duration,1 days,365 days);
        vm.prank(creator1);
        //Creator Set His Plans
        sub.addPlan(planId, price, duration);
        //User Buy Creator Plan
        address user = makeAddr("user");
        vm.deal(user,price);
        vm.expectEmit(true, true, false, true,address(sub));
        emit Subscription.SubscriptionBought(user,creator1,planId,price,(block.timestamp + duration));
        vm.prank(user);
        sub.giftSubscription{value:price}(user, planId,creator1);
        uint fee = sub.feeCollected();
        uint remBalance = price - fee;
        (,uint totalBalance,uint totalSubscribers,) = sub.creatorProfile(creator1);
        console.log(totalBalance);
        console.log(remBalance);
        vm.assertEq(totalBalance, remBalance);
        vm.assertEq(totalSubscribers, 1);
        //User Can Buy Again When Expired
        vm.warp(duration+1 days);
        vm.expectEmit(true, true, false, true,address(sub));
        emit Subscription.SubscriptionBought(user,creator1,planId,price,(block.timestamp + duration));
        vm.deal(user,price);
        vm.prank(user);
        sub.giftSubscription{value:price}(user, planId,creator1);
        (,totalBalance,totalSubscribers,) = sub.creatorProfile(creator1);
        remBalance = totalBalance - fee;
        fee = sub.feeCollected();
        console.log(totalBalance);
        console.log(remBalance);
        console.log("Remaining Fee");
        console.log(fee);
    }
    function testFuzz_CreatorWithdraw(uint _price,uint _planId,uint _duration,uint _amount) public {
        uint planId = bound(_planId,1,10000);
        uint price = bound(_price,1 ether,1000 ether);
        uint duration = bound(_duration,1 days,365 days);
        vm.prank(creator1);
        //Creator Set His Plans
        sub.addPlan(planId, price, duration);
        //User Buy Creator Plan
        address user = makeAddr("user");
        vm.deal(user,price);
        vm.prank(user);
        sub.buyOrRenewSubscription{value:price}(creator1, planId);
        console.log("Fee Before Withdrawing");
        (,uint cFee,,) = sub.creatorProfile(creator1);
        console.log(cFee);
        uint amount = bound(_amount,1,cFee);
        vm.expectEmit(true, false, false, true);
        emit Subscription.CreatorWithdraw(creator1,amount);
        vm.prank(creator1);
        //Withdrawing Specific Amount
        sub.creatorWithdraw(amount);
        (,uint rFee,,) = sub.creatorProfile(creator1);
        console.log("Fee Remaining After Withdrawing");
        console.log(rFee);
        //Withdrawing Full Amount
        if(rFee>0){
            vm.expectEmit(true, false, false, true);
            emit Subscription.CreatorWithdraw(creator1,rFee);
            vm.prank(creator1);
            sub.creatorWithdraw(rFee);
        }else{
            console.log("Remaining Fee Is Zero");
        }
        (,cFee,,) = sub.creatorProfile(creator1);
        console.log("Fee After Withdrawing All");
        console.log(cFee);
    }
    function testFuzz_OwnerCollectFee(uint _price,uint _planId,uint _duration,uint _amount) public {
        uint planId = bound(_planId,1,10000);
        uint price = bound(_price,1 ether,1000 ether);
        uint duration = bound(_duration,1 days,365 days);
        vm.prank(creator1);
        //Creator Set His Plans
        sub.addPlan(planId, price, duration);
        //User Buy Creator Plan
        address user = makeAddr("user");
        vm.deal(user,price);
        vm.prank(user);
        sub.buyOrRenewSubscription{value:price}(creator1, planId);
        address user1 = makeAddr("user1");
        vm.deal(user1,price);
        vm.prank(user1);
        sub.buyOrRenewSubscription{value:price}(creator1, planId);
        uint fee = sub.feeCollected();
        console.log(price);
        console.log(fee);
        uint amount = bound(_amount,1,fee);
        //Owner Withdraw Part Of Fee
        vm.expectEmit(true, false, false, true);
        emit Subscription.OwnerWithdrawed(owner,amount);
        vm.prank(owner);
        sub.collectFee(amount);
        //Remaining Fee When Deducted From Total Fee
        uint rFee = sub.feeCollected();
        console.log(rFee);
        if(rFee>0){
            console.log("Entering The rFee > 0");
            vm.expectEmit(true, false, false, true);
            emit Subscription.OwnerWithdrawed(owner,rFee);
            vm.prank(owner);
            sub.collectFee(rFee);
        }
        else if(rFee==0){
            vm.expectRevert("Invalid Fee");
            vm.prank(owner);
            sub.collectFee(rFee);
        }
        //After Withdrawing Fee Will Be Zero
        uint tFee = sub.feeCollected();
        console.log("Fee After Withdrawing All Owner Fee");
        console.log(tFee);
    }


}