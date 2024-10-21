// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SystemTest} from "./System.t.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {BERA_NODE, ADDR_REVERSE_NODE, REVERSE_NODE, DEFAULT_TTL} from "src/utils/Constants.sol";

contract FlowTest is SystemTest {
    function test_baslow_registration() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        // register
        registrar.register{value: 1 ether}(registerRequest());
        vm.stopPrank();
        // check name is registered
        assertEq(baseRegistrar.ownerOf(uint256(keccak256("cien"))), alice);
    }

    function test_basicFlow_ForwardResolution() public {
        // register and set addr
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        registrar.register{value: 1 ether}(registerRequest());
        bytes32 label = keccak256(bytes("cien"));
        bytes32 subnode = _calculateNode(label, BERA_NODE);
        resolver.setAddr(subnode, address(alice));
        vm.stopPrank();
        // resolve
        assertEq(resolver.addr(subnode), alice);
    }

    function registerRequest() private returns (RegistrarController.RegisterRequest memory) {
        return RegistrarController.RegisterRequest({
            name: "cien",
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: false,
            referrer: address(0)
        });
    }
}
