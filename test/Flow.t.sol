// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SystemTest} from "./System.t.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {BERA_NODE, ADDR_REVERSE_NODE, REVERSE_NODE, DEFAULT_TTL} from "src/utils/Constants.sol";
import {console} from "lib/forge-std/src/console.sol";

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
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        // register and set addr
        registrar.register{value: 1 ether}(registerRequest());
        bytes32 label = keccak256(bytes("cien"));
        bytes32 subnode = _calculateNode(label, BERA_NODE);
        resolver.setAddr(subnode, address(alice));
        // resolve
        assertEq(resolver.addr(subnode), alice);
        vm.stopPrank();
    }

    function test_reverseResolution_success() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        // register and set addr
        registrar.register{value: 1 ether}(registerRequest());
        vm.stopPrank();
        //resolver.setAddr(subnode, address(alice));
        // set resolver to reverseRegistrat pranking with registrarController as is the owner
        vm.prank(address(registrar));
        reverseRegistrar.setDefaultResolver(address(resolver));
        // claim and set name
        vm.startPrank(alice);
        bytes32 reverseNode = reverseRegistrar.setName("cien.bera");
        bytes32 nodeReverse = reverseRegistrar.node(alice);
        assertEq(reverseNode, nodeReverse, "reverse nodes");
        // // check name
        assertEq(resolver.name(reverseNode), "cien.bera", "reverse name");
        vm.stopPrank();
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
