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

    // Whitelist Signer
    address public whitelistSigner;
    uint256 public whitelistSignerPk;

    // Free Whitelist Signer
    address public freeWhitelistSigner;
    uint256 public freeWhitelistSignerPk;

    // Users & non permissioned addresses
    address public alice;
    address public bob;
    address public chris;
    address public derek;

    // honey and weth
    address public honey;
    address public weth;

    function setUp() public virtual {
        utils = new Utils();

        // Deployers
        deployer = utils.initializeAccount("Deployer");

        // Registrar Admin
        registrarAdmin = utils.initializeAccount("Registrar Admin");

        // Signer
        (whitelistSigner, whitelistSignerPk) = makeAddrAndKey("whitelistSigner");
        (freeWhitelistSigner, freeWhitelistSignerPk) = makeAddrAndKey("freeWhitelistSigner");

        // Users & non permissioned addresses
        alice = utils.initializeAccount("Alice");
        bob = utils.initializeAccount("Bob");
        chris = utils.initializeAccount("Chris");
        derek = utils.initializeAccount("Derek");

        // honey and weth
        honey = address(0x1234567890123456789012345678901234567890); // Fake ERC20 address for honey
        weth = address(0x1234567890123456789012345678901234567891); // Fake ERC20 address for weth
    }

    modifier prank(address account) {
        vm.startPrank(account);
        _;
        vm.stopPrank();
    }

    modifier prankWithBalance(address account, uint256 balance) {
        vm.startPrank(account);
        vm.deal(account, balance);
        _;
        vm.stopPrank();
    }
}
