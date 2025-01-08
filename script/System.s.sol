// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {BNS} from "src/registry/interfaces/BNS.sol";
import {BeraNamesRegistry} from "src/registry/Registry.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {ReverseRegistrar} from "src/registrar/ReverseRegistrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {PriceOracle} from "src/registrar/types/PriceOracle.sol";
import {ReservedRegistry} from "src/registrar/types/ReservedRegistry.sol";
import {UniversalResolver} from "src/resolver/UniversalResolver.sol";
import {BeraAuctionHouse} from "src/auction/BeraAuctionHouse.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/auction/interfaces/IWETH.sol";
import {bArtioPriceOracle} from "src/registrar/types/bArtioPriceOracle.sol";
import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";

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
    IPriceOracle public priceOracle;

    UniversalResolver public universalResolver;

    BeraAuctionHouse public auctionHouse;

    // Addresses
    // TODO: Update these with the correct addresses
    address public deployer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public registrarAdmin = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public whitelistSigner = address(0x3B5Ed4CE5189DE93Aa4A91b8096BD34457d9634b);
    address public freeWhitelistSigner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

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
            "https://beranames-v3.vercel.app/metadata/berachain-testnet-b-artio/", // bartio-testnet
            "https://beranames-v3.vercel.app/metadata/berachain-testnet-b-artio/collection" // bartio-testnet collection
                // "https://www.beranames.com/metadata/berachain-mainnet/", // berachain-mainnet
                // "https://www.beranames.com/metadata/berachain-mainnet/collection" // berachain-mainnet collection
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
        resolver =
            new BeraDefaultResolver(registry, address(baseRegistrar), address(reverseRegistrar), address(deployer));

        // Set the resolver for the base node
        registry.setResolver(bytes32(0), address(resolver));

        // Create the bere node and set registrar/resolver
        registry.setSubnodeRecord(
            bytes32(0), keccak256(abi.encodePacked("bera")), address(baseRegistrar), address(resolver), DEFAULT_TTL
        );

        // Deploy layer 3 components: public registrar
        // Create the PriceOracle
        // TODO: use pyth for mainnet
        // address pythAddress = 0x2880aB155794e7179c9eE2e38200202908C17B43;
        // bytes32 beraUsdPythPriceFeedId = 0x40dd8c66a9582c51a1b03a41d6c68ee5c2c04c8b9c054e81d0f95602ffaefe2f;
        // priceOracle = new PriceOracle(pythAddress, beraUsdPythPriceFeedId);

        priceOracle = new bArtioPriceOracle();

        // Create the reserved registry
        reservedRegistry = new ReservedRegistry(address(registrarAdmin));

        // Create the registrar, set the resolver, and set as a controller
        registrar = new RegistrarController(
            baseRegistrar,
            priceOracle,
            reverseRegistrar,
            whitelistSigner,
            freeWhitelistSigner,
            reservedRegistry,
            address(registrarAdmin),
            BERA_NODE,
            ".bera",
            address(registrarAdmin)
        );
        baseRegistrar.addController(address(registrar));
        resolver.setRegistrarController(address(registrar));

        // Deploy the auction house
        auctionHouse = new BeraAuctionHouse(
            baseRegistrar,
            resolver,
            IWETH(0x7507c1dc16935B82698e4C63f2746A2fCf994dF8),
            1 days,
            365 days,
            1 ether,
            10 seconds,
            1,
            address(registrarAdmin)
        );
        auctionHouse.transferOwnership(address(registrarAdmin));
        baseRegistrar.addController(address(auctionHouse));

        // TODO: Add test domains / initial mints here
        reservedRegistry.setReservedName("reserved");

        // Deploy the Universal Resovler
        string[] memory urls = new string[](0);
        universalResolver = new UniversalResolver(address(registry), urls);

        // Transfer ownership to registrar admin
        // root node
        registry.setOwner(bytes32(0), address(registrarAdmin));
        baseRegistrar.transferOwnership(address(registrarAdmin));
        universalResolver.transferOwnership(address(registrarAdmin));

        // admin control
        reverseRegistrar.setController(address(registrarAdmin), true);
        reverseRegistrar.setController(address(registrar), true);
        reverseRegistrar.setDefaultResolver(address(resolver));
        reverseRegistrar.transferOwnership(address(registrarAdmin));
        resolver.transferOwnership(address(registrarAdmin));

        // Stop broadcast
        vm.stopBroadcast();
    }
}
