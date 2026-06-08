// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Subscription} from "../src/Subscription.sol";
import "forge-std/console.sol";
import "forge-std/console.sol";

contract SubscriptionTest is Test{
    Subscription public sub;
    address creator1 = makeAddr("creator1");

    function setUp() public {
        sub = new Subscription();
        sub.addCreator(creator1);
        console.log("Hello World");
    }
    function testFuzz_SetCreatorData(string memory name) public {
        vm.prank(creator1);
        sub.setCreatorData(name);
        (string memory _name,,,) = sub.creatorProfile(creator1);
        console.log(_name);
        assertEq(_name, name);
    }
}