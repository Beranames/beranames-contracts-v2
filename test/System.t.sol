// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// Core imports

import {BNS} from "src/registry/interfaces/BNS.sol";
import {BeraNamesRegistry} from "src/registry/Registry.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {ReverseRegistrar} from "src/registrar/ReverseRegistrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {ReservedRegistry} from "src/registrar/types/ReservedRegistry.sol";
import {WhitelistValidator} from "src/registrar/types/WhitelistValidator.sol";
import {PriceOracle} from "src/registrar/types/PriceOracle.sol";

import {BERA_NODE, ADDR_REVERSE_NODE, REVERSE_NODE, DEFAULT_TTL} from "src/utils/Constants.sol";

/// Test imports

import {BaseTest} from "./Base.t.sol";

contract SystemTest is BaseTest {
    // Layer 1: BNS Registry
    BNS public registry;

    // Layer 2: Base Registrar, Reverse Registrar, and Resolver
    BaseRegistrar public baseRegistrar;
    ReverseRegistrar public reverseRegistrar;
    BeraDefaultResolver public resolver;

    // Layer 3: Public Registrar
    RegistrarController public registrar;

    function setUp() public override {
        // Setup base test
        super.setUp();

        // Prank deployer
        vm.startPrank(deployer);

        // Deploy layer 1 components: registry
        registry = new BeraNamesRegistry();

        // Deploy layer 2 components: base registrar, reverse registrar, and resolver
        baseRegistrar = new BaseRegistrar(
            registry,
            address(deployer),
            BERA_NODE,
            "https://beranames.xyz/metadata/",
            "https://beranames.xyz/collection.json"
        );

        // Create the reverse registrar
        reverseRegistrar = new ReverseRegistrar(registry);

        // Transfer ownership of the reverse node to the registrar
        registry.setSubnodeRecord(
            bytes32(0), keccak256(abi.encodePacked("reverse")), address(deployer), address(0), DEFAULT_TTL
        );
        registry.setSubnodeRecord(
            REVERSE_NODE, keccak256(abi.encodePacked("addr")), address(reverseRegistrar), address(0), DEFAULT_TTL
        );
        registry.setOwner(REVERSE_NODE, address(registrarAdmin));

        // Create the resolver
        resolver = new BeraDefaultResolver(
            registry, address(baseRegistrar), address(reverseRegistrar), address(registrarAdmin)
        );

        // Set the resolver for the base node
        registry.setResolver(bytes32(0), address(resolver));

        // Create the bere node and set registrar/resolver
        registry.setSubnodeRecord(
            bytes32(0), keccak256(abi.encodePacked("bera")), address(baseRegistrar), address(resolver), DEFAULT_TTL
        );

        // Deploy layer 3 components: public registrar
        // Create the PriceOracle
        PriceOracle priceOracle = new PriceOracle();

        // Create the WhitelistValidator
        WhitelistValidator whitelistValidator = new WhitelistValidator(address(registrarAdmin), address(signer));

        // Create the reserved registry
        ReservedRegistry reservedRegistry = new ReservedRegistry(address(deployer));

        // Create the registrar, set the resolver, and set as a controller
        registrar = new RegistrarController(
            baseRegistrar,
            priceOracle,
            reverseRegistrar,
            whitelistValidator,
            reservedRegistry,
            address(registrarAdmin),
            BERA_NODE,
            ".bera",
            address(registrarAdmin)
        );
        baseRegistrar.addController(address(registrar));

        // Transfer ownership to registrar admin
        // root node
        registry.setOwner(bytes32(0), address(registrarAdmin));
        baseRegistrar.transferOwnership(address(registrarAdmin));

        // admin control
        reverseRegistrar.setController(address(registrarAdmin), true);
        reverseRegistrar.setController(address(registrar), true);
        reverseRegistrar.transferOwnership(address(registrar));

        // Stop pranking
        vm.stopPrank();

        vm.warp(100_0000_0000);
    }

    function test_initialized() public view {
        assertEq(registry.owner(BERA_NODE), address(baseRegistrar), "BERA_NODE owner");
        assertEq(registry.owner(ADDR_REVERSE_NODE), address(reverseRegistrar), "ADDR_REVERSE_NODE owner");
        assertEq(registry.resolver(BERA_NODE), address(resolver), "BERA_NODE resolver");
        assertEq(registry.resolver(ADDR_REVERSE_NODE), address(0), "ADDR_REVERSE_NODE resolver");
        assertEq(baseRegistrar.owner(), address(registrarAdmin), "baseRegistrar owner");
        assertEq(reverseRegistrar.owner(), address(registrar), "reverseRegistrar owner");
        assertEq(address(resolver.owner()), address(registrarAdmin), "resolver owner");
    }

    function test_register__basic_success_01() public {
        // // Prank alice
        vm.startPrank(alice);
        vm.deal(alice, 1 ether);

        // Register a name
        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: "foo-bar",
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
        registrar.register{value: 1 ether}(request);

        // Check the reverse record
        bytes32 reverseNode = reverseRegistrar.node(alice);
        string memory name = resolver.name(reverseNode);
        assertEq(name, "foo-bar.bera", "name");

        // Stop pranking
        vm.stopPrank();
    }

    function test_register__basic_success_02() public {
        // // Prank alice
        // vm.startPrank(alice);

        // // Register a name
        // registrar.register(alice, "alice.beranames", 1, Payment.ETH);

        // // Stop pranking
        // vm.stopPrank();
    }

    // function test_XXX() public {
    //     assertEq(1, 1);
    // }

    // function testFuzz_XXX(uint256 x) public {
    //     assertEq(x, x);
    // }

    function _calculateNode(bytes32 labelHash_, bytes32 parent_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent_, labelHash_));
    }
}
