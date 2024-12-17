// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SystemTest} from "../System.t.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {console} from "forge-std/Test.sol";

contract RenewTest is SystemTest {
    string public name = "alice";

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(alice);
        deal(address(alice), 1000 ether);

        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: name,
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
        registrar.register{value: 500 ether}(request);

        vm.stopPrank();
    }

    function test_renew__success() public {
        vm.startPrank(bob); // anyone can renew a name, not just the owner
        deal(address(bob), 1000 ether);

        uint256 price = registrar.registerPrice(name, 365 days * 5); // this makes sure the price includes discount
        registrar.renew{value: price * 2}(name, 365 days * 5); // sending double the price and checking that the extra is returned

        vm.stopPrank();

        assertLt(price, registrar.registerPrice(name, 365 days) * 5, "Price does not include discount");
        assertEq(address(bob).balance, 1000 ether - price, "Bob's balance is incorrect");
    }
}
