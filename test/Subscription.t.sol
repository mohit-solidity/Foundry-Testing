// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Subscription} from "../src/Subscription.sol";
import "forge-std/console.sol";
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
    function testFuzz_addPlan(uint _planId,uint _price,uint _duration) public{
        uint _planId = bound(_planId,1,10000);
        uint _price = bound(_price,1,1000);
        uint _duration = bound(_duration,1 days,365 days);
        vm.assume(_price>0);
        vm.assume(_duration>0);
        vm.assume(_planId>0);
        vm.expectEmit(true, false, false, true,address(sub));
        emit Subscription.PlanAdded(creator1,_planId);
        vm.prank(creator1);
        sub.addPlan(_planId,_price,_duration);
        (uint price,uint duration,bool isActive) = sub.creatorPlans(creator1,_planId);
        assertEq(_price, price);
        assertEq(_duration,duration);
        assertTrue(isActive);
    }
    function testFuzz_AddPlan_RevertForNotCreator(address randomUser,uint _planId,uint _price,uint _duration) public {
        uint planId = bound(_planId,1,10000);
        uint price = bound(_price,1,1000);
        uint duration = bound(_duration,1 days,365 days);
        vm.assume(randomUser != creator1);
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
        uint price = bound(_price,1,1000);
        uint duration = bound(_duration,1 days,365 days);
        vm.prank(creator1);
        //Creator Set His Plans
        sub.addPlan(planId, price, duration);
        //User Buy Creator Plan
        address user = makeAddr("user");
        vm.deal(user,price);
        vm.prank(user);
        sub.buyOrRenewSubscription{value:price}(creator1, planId);
        console.log(sub.feeCollected());
    }
}