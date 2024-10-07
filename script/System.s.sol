// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {BNS} from "src/registry/interfaces/BNS.sol";
import {BeraNamesRegistry} from "src/registry/Registry.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {ReverseRegistrar} from "src/registrar/ReverseRegistrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {WhitelistValidator} from "src/registrar/types/WhitelistValidator.sol";
import {PriceOracle} from "src/registrar/types/PriceOracle.sol";
import {ReservedRegistry} from "src/registrar/types/ReservedRegistry.sol";
import {IWhitelistValidator} from "src/registrar/interfaces/IWhitelistValidator.sol";

import {BERA_NODE, ADDR_REVERSE_NODE, REVERSE_NODE, DEFAULT_TTL} from "src/utils/Constants.sol";

contract ContractScript is Script {
    // Layer 1: BNS Registry
    BNS public registry;

    // Layer 2: Base Registrar, Reverse Registrar, and Resolver
    BaseRegistrar public baseRegistrar;
    ReverseRegistrar public reverseRegistrar;
    BeraDefaultResolver public resolver;

    // Layer 3: Public Registrar
    RegistrarController public registrar;

    ReservedRegistry public reservedRegistry;
    WhitelistValidator public whitelistValidator;
    PriceOracle public priceOracle;

    // Addresses
    // TODO: Update these with the correct addresses
    address public deployer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public registrarAdmin = address(0x123);
    address public signer = address(0x1234);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy layer 1 components: registry
        registry = new BeraNamesRegistry();

        // Deploy layer 2 components: base registrar, reverse registrar, and resolver
        baseRegistrar = new BaseRegistrar(
            registry,
            address(deployer),
            BERA_NODE,
            "https://beranames.xyz/metadata/", // TODO: Update this with the correct metadata URL
            "https://beranames.xyz/collection.json" // TODO: Update this with the correct collection URL
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
        priceOracle = new PriceOracle();

        // Create the WhitelistValidator
        whitelistValidator = new WhitelistValidator(address(registrarAdmin), address(signer));

        // Create the reserved registry
        reservedRegistry = new ReservedRegistry(address(registrarAdmin));

        // Create the registrar, set the resolver, and set as a controller
        registrar = new RegistrarController(
            baseRegistrar,
            priceOracle,
            reverseRegistrar,
            IWhitelistValidator(address(whitelistValidator)),
            reservedRegistry,
            address(registrarAdmin),
            BERA_NODE,
            "beranames",
            address(registrarAdmin)
        );
        baseRegistrar.addController(address(registrar));

        // TODO: Add test domains / initial mints here

        // Transfer ownership to registrar admin
        // root node
        registry.setOwner(bytes32(0), address(registrarAdmin));
        baseRegistrar.transferOwnership(address(registrarAdmin));

        // admin control
        reverseRegistrar.setController(address(registrarAdmin), true);
        reverseRegistrar.transferOwnership(address(registrarAdmin));

        // Stop broadcast
        vm.stopBroadcast();
    }
}
