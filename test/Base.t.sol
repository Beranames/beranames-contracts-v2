// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "./Utils.sol";

contract BaseTest is Test {
    Utils public utils;

    // Deployers
    address public deployer;

    // Registrar Admin
    address public registrarAdmin;

    // Signer
    address public signer;
    uint256 public signerPk;

    // Users & non permissioned addresses
    address public alice;
    address public bob;
    address public chris;
    address public derek;

    function setUp() public virtual {
        utils = new Utils();

        // Deployers
        deployer = utils.initializeAccount("Deployer");

        // Registrar Admin
        registrarAdmin = utils.initializeAccount("Registrar Admin");

        // Signer
        (signer, signerPk) = makeAddrAndKey("signer");

        // Users & non permissioned addresses
        alice = utils.initializeAccount("Alice");
        bob = utils.initializeAccount("Bob");
        chris = utils.initializeAccount("Chris");
        derek = utils.initializeAccount("Derek");
    }

    modifier prank(address account) {
        vm.startPrank(account);
        _;
        vm.stopPrank();
    }
}
