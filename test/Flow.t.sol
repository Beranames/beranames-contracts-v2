// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest} from "./Base.t.sol";

import {BNS} from "src/registry/interfaces/BNS.sol";
import {BeraNamesRegistry} from "src/registry/Registry.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {ReverseRegistrar} from "src/registrar/ReverseRegistrar.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {PriceOracle} from "src/registrar/types/PriceOracle.sol";
import {UniversalResolver} from "src/resolver/UniversalResolver.sol";
import {ReservedRegistry} from "src/registrar/types/ReservedRegistry.sol";
import {WhitelistValidator} from "src/registrar/types/WhitelistValidator.sol";
import {IAddrResolver} from "src/resolver/interfaces/IAddrResolver.sol";

import {BERA_NODE, ADDR_REVERSE_NODE, REVERSE_NODE, DEFAULT_TTL} from "src/utils/Constants.sol";
import {NameEncoder} from "src/resolver/libraries/NameEncoder.sol";

import {console} from "lib/forge-std/src/console.sol";

contract FlowTest is BaseTest {
    // Layer 1: Registry
    BNS public registry;

    // Layer 2: Base Registrar, Reverse Registrar, Resolver
    BaseRegistrar public baseRegistrar;
    ReverseRegistrar public reverseRegistrar;
    BeraDefaultResolver public resolver;

    // Layer 3: Registrar Controller and Oracle
    RegistrarController public registrarController;
    PriceOracle public priceOracle;
    WhitelistValidator public whitelistValidator;
    ReservedRegistry public reservedRegistry;

    // Universal Resolver
    UniversalResolver public universalResolver;

    function setUp() public override {
        // Setup base test
        super.setUp();
        vm.startPrank(deployer);
        // DEPLOYING CONTRACTS ----------------------------------------------------------------------------------------------

        // registry
        registry = new BeraNamesRegistry();

        // baseRegistrar
        baseRegistrar = new BaseRegistrar(
            registry,
            address(deployer),
            BERA_NODE,
            "https://token-uri.com",
            "https://collection-uri.com"
        );

        // reverseRegistrar needs to be set up in order to claim the reverse node
        reverseRegistrar = new ReverseRegistrar(registry);

        // Create the reverse node
        registry.setSubnodeRecord(
            bytes32(0), keccak256(abi.encodePacked("reverse")), address(deployer), address(0), DEFAULT_TTL
        );
        registry.setSubnodeRecord(
            REVERSE_NODE, keccak256(abi.encodePacked("addr")), address(reverseRegistrar), address(0), DEFAULT_TTL
        );

        // resolver needs to be created after the reverse node is set up because
        // inside the constructor the owner claims the reverse node
        resolver = new BeraDefaultResolver(
            registry,
            address(baseRegistrar),
            address(reverseRegistrar),
            address(deployer)
        );

        // Create the BERA node
        registry.setSubnodeRecord(
            bytes32(0), keccak256(abi.encodePacked("bera")), address(baseRegistrar), address(resolver), DEFAULT_TTL
        );

        // priceOracle
        priceOracle = new PriceOracle();

        // whitelistValidator
        whitelistValidator = new WhitelistValidator(address(registrarAdmin), address(signer));
        
        // reservedRegistry
        reservedRegistry = new ReservedRegistry(address(deployer));

        // registrarController
        registrarController = new RegistrarController(
            baseRegistrar,
            priceOracle,
            reverseRegistrar,
            whitelistValidator,
            reservedRegistry,
            address(deployer),
            BERA_NODE,
            ".bera",
            address(deployer)
        );

        // universalResolver
        universalResolver = new UniversalResolver(address(registry), new string[](0));

        // SETTING UP CONTRACTS ---------------------------------------------------------------------------------------------

        // Set the resolvers
        registry.setResolver(bytes32(0), address(resolver));
        registry.setResolver(REVERSE_NODE, address(resolver));
        reverseRegistrar.setDefaultResolver(address(resolver));

        // owner and controller setup
        resolver.setRegistrarController(address(registrarController));
        baseRegistrar.addController(address(registrarController));
        registry.setOwner(REVERSE_NODE, address(baseRegistrar));

        // ADMIN SETUP -----------------------------------------------------------------------------------------------------

        // if we need an admin, we can set it here and transfer ownership to it

        // Stop pranking
        vm.stopPrank();

        // need to warp to avoid timestamp issues
        vm.warp(100_0000_0000);
    }

    function test_setUp_success() public view {
        assertEq(registry.owner(BERA_NODE), address(baseRegistrar), "BERA_NODE owner");
        assertEq(registry.owner(ADDR_REVERSE_NODE), address(reverseRegistrar), "REVERSE_NODE owner");
        assertEq(baseRegistrar.owner(), address(deployer), "baseRegistrar owner");
        assertEq(reverseRegistrar.owner(), address(deployer), "reverseRegistrar owner");
        assertEq(resolver.owner(), address(deployer), "resolver owner");
        assertEq(registry.resolver(BERA_NODE), address(resolver), "resolver BERA_NODE");
        assertEq(registry.resolver(bytes32(0)), address(resolver), "resolver 0x00 node");
    }

    function test_register_success() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        // register
        registrarController.register{value: 1 ether}(registerRequestWithNoReverseRecord());
        vm.stopPrank();
        // check name is registered
        assertEq(baseRegistrar.ownerOf(uint256(keccak256("cien"))), alice);
    }

    function test_forwardResolution_success() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        // register and set addr
        registrarController.register{value: 1 ether}(registerRequestWithNoReverseRecord());
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
        registrarController.register{value: 1 ether}(registerRequestWithNoReverseRecord());
        // claim and set name
        bytes32 reverseNode = reverseRegistrar.setName("cien.bera");
        bytes32 nodeReverse = reverseRegistrar.node(alice);
        assertEq(reverseNode, nodeReverse, "reverse nodes");
        // check name
        assertEq(resolver.name(reverseNode), "cien.bera", "reversed resolved");
        vm.stopPrank();
    }

    function test_UR_forwardResolution_returns_0x00_if_setAddr_not_called() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        // register and set addr
        registrarController.register{value: 1 ether}(registerRequestWithNoReverseRecord());
        bytes32 node = _calculateNode(keccak256(bytes("cien")), BERA_NODE);
        // dns encode name
        (bytes memory dnsEncName, ) = NameEncoder.dnsEncodeName("cien.bera");
        console.log("dnsEncName");
        console.logBytes(dnsEncName);
        // resolve
        (bytes memory res_, address calledResolver_) =
            universalResolver.resolve(dnsEncName, abi.encodeWithSelector(IAddrResolver.addr.selector, node));
        address addr = abi.decode(res_, (address));
        assertEq(addr, address(0), "addr not set for forward resolution");
        assertEq(calledResolver_, address(resolver), "called BeraDefaultResolver");
        vm.stopPrank();
    }

    // function test_UR_reverseResolution_returns_0x00_if_setName_not_called() public {
    //     vm.startPrank(alice);
    //     vm.deal(alice, 10 ether);
    //     // register
    //     registrarController.register{value: 1 ether}(registerRequestWithNoReverseRecord());
    //     // reverse node DNS encoded
    //     string memory normalizedAddr = normalizeAddress(alice);
    //     string memory reverseNode = string.concat(normalizedAddr, ".addr.reverse");
    //     (bytes memory dnsEncName, ) = NameEncoder.dnsEncodeName(reverseNode);
    //     (string memory resolvedName, address resolvedAddress, address reverseResolverAddress, address addrResolverAddress) =
    //         universalResolver.reverse(dnsEncName);
    //     assertEq(resolvedName, "", "reverse resolution failed");
    //     //assertEq(resolvedAddress, address(0), "resolvedAddress is 0");
    //     //assertEq(reverseResolverAddress, address(0), "reverseResolverAddress is 0");
    //     // assertEq(addrResolverAddress, address(0), "addrResolverAddress is 0");
    //     vm.stopPrank();
    // }

    function test_UR_reverseResolution_returns_addr_if_setName_called() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        // register
        registrarController.register{value: 1 ether}(registerRequestWithNoReverseRecord());
        // claim and set name
        reverseRegistrar.setName("cien.bera");
        // reverse node DNS encoded
        string memory normalizedAddr = normalizeAddress(alice);
        string memory reverseNode = string.concat(normalizedAddr, ".addr.reverse");
        (bytes memory dnsEncName, ) = NameEncoder.dnsEncodeName(reverseNode);
        (string memory resolvedName, address resolvedAddress, address reverseResolverAddress, address addrResolverAddress) =
            universalResolver.reverse(dnsEncName);
        assertEq(resolvedName, "cien.bera", "reverse resolution success");
        assertEq(resolvedAddress, address(0), "resolvedAddress is zero address because addr resolver is not set");
        vm.stopPrank();
    }

    // function test_UR_forwardResolution_success_with_subdomain_using_parent_resolver() public prank(alice) {
    //     registerAndSetAddr();

    // }

    // UTILITIES ----------------------------------------------------------------------------------------------------------

    modifier prank(address account) {
        vm.startPrank(account);
        _;
        vm.stopPrank();
    }

    /// @notice Calculate the node for a given label and parent
    /// @param labelHash_ The label hash
    /// @param parent_ The parent node
    /// @return calculated node
    function _calculateNode(bytes32 labelHash_, bytes32 parent_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent_, labelHash_));
    }

    /// @notice Normalize an address to a lowercase hexadecimal string
    /// @param _addr The address to normalize
    /// @return The normalized address
    function normalizeAddress(address _addr) internal pure returns (string memory) {
        // Get the hexadecimal representation of the address
        bytes memory addressBytes = abi.encodePacked(_addr);

        // Prepare a string to hold the lowercase hexadecimal characters
        bytes memory hexString = new bytes(40); // 20 bytes address * 2 characters per byte
        bytes memory hexSymbols = "0123456789abcdef"; // Hexadecimal symbols

        for (uint256 i = 0; i < 20; i++) {
            hexString[i * 2] = hexSymbols[uint8(addressBytes[i] >> 4)]; // Higher nibble (first half) shift right
            hexString[i * 2 + 1] = hexSymbols[uint8(addressBytes[i] & 0x0f)]; // Lower nibble (second half) bitwise AND
        }
        // -----------------------------------------------------------------------------------------------------------------
        // We use 0x0f to isolate the lower nibble. 0x0f is 00001111 in binary.
        // So performing a bitwise AND with 0x0f will isolate the lower nibble.
        // Bitwise AND is a binary operation that compares each bit of two numbers and returns 1 if both bits are 1, otherwise 0.
        // -----------------------------------------------------------------------------------------------------------------
        return string(hexString);
    }

    function registerAndSetAddr() internal {
        vm.deal(alice, 10 ether);
        registrarController.register{value: 1 ether}(registerRequestWithNoReverseRecord());
        bytes32 label = keccak256(bytes(name));
        bytes32 subnode = _calculateNode(label, BERA_NODE);
        resolver.setAddr(subnode, address(alice));
    }

    function registerRequestWithNoReverseRecord() internal view returns (RegistrarController.RegisterRequest memory) {
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
