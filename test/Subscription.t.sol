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

    function setUp() public {
        vm.startPrank(owner);
        sub = new Subscription();
        sub.addCreator(creator1);
        vm.stopPrank();
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
        (string memory _name,,,bool exists) = sub.creatorProfile(creator1);
        console.log(_name);
        console.log("This Is For Name");
        console.log(exists);
        assertEq(_name, name);
    }
    function testFuzz_addPlan(uint _planId,uint _price,uint _duration) public{
        vm.assume(_price>0);
        vm.assume(_duration>0);
        vm.assume(_planId>0);
        vm.prank(creator1);
        sub.addPlan(_planId,_price,_duration);
        (uint price,uint duration,bool isActive) = sub.creatorPlans(creator1,_planId);
        assertEq(_price, price);
        assertEq(_duration,duration);
        assertTrue(isActive);
    }
    function testFuzz_AddPlan_RevertForNotCreator(address randomUser,uint _planId,uint _price,uint _duration) public {
        vm.assume(randomUser != creator1);
        vm.assume(randomUser != address(0));
        vm.expectRevert("Not A Creator");
        vm.prank(randomUser);
        sub.addPlan(_planId, _price, _duration);
    }
}