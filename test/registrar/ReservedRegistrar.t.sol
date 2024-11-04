// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SystemTest} from "../System.t.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";

/// @notice this contract tests the RegistrarController, but only reserved tests
/// separated for clarity and organisation
contract ReservedRegistrarTest is SystemTest {
    function test_name_reserved_mint__success() public {
        address minter = makeAddr("minter");
        RegistrarController.RegisterRequest memory req = defaultRequest();

        // add to reserved names
        vm.prank(deployer);
        reservedRegistry.setReservedName(DEFAULT_NAME);

        // set reserved names minter on registrar
        vm.prank(registrarAdmin);
        registrar.setReservedNamesMinter(minter);

        // mint fails if alice does it
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        vm.expectRevert(RegistrarController.NameReserved.selector);
        registrar.register{value: 500 ether}(req);

        // reservedRegister fails if alice does it
        vm.expectRevert(RegistrarController.NotAuthorisedToMintReservedNames.selector);
        registrar.reservedRegister(req);
        vm.stopPrank();

        // mint succeeds if minter does it with no money
        vm.prank(minter);
        registrar.reservedRegister(req);

        // mint fails if name is not reserved
        req.name = "not-reserved";
        vm.prank(minter);
        vm.expectRevert(RegistrarController.NameNotReserved.selector);
        registrar.reservedRegister(req);
    }
}
