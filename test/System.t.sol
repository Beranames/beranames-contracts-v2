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
import {UniversalResolver} from "src/resolver/UniversalResolver.sol";

import {BERA_NODE, ADDR_REVERSE_NODE, REVERSE_NODE, DEFAULT_TTL} from "src/utils/Constants.sol";

import {IAddrResolver} from "src/resolver/interfaces/IAddrResolver.sol";

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

    ReservedRegistry public reservedRegistry;
    WhitelistValidator public whitelistValidator;
    PriceOracle public priceOracle;

    UniversalResolver public universalResolver;

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
        priceOracle = new PriceOracle();

        // Create the WhitelistValidator
        whitelistValidator = new WhitelistValidator(address(registrarAdmin), address(signer));

        // Create the reserved registry
        reservedRegistry = new ReservedRegistry(address(deployer));

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

        // Deploy the Universal Resovler
        string[] memory urls = new string[](0);
        universalResolver = new UniversalResolver(address(registry), urls);

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

    function test_basic_success_and_resolution() public {
        vm.startPrank(alice);
        vm.deal(alice, 1 ether);

        registrar.register{value: 1 ether}(defaultRequest());

        // Check the resolution
        bytes32 reverseNode = reverseRegistrar.node(alice);
        string memory name = resolver.name(reverseNode);
        assertEq(name, "foo-bar.bera", "name");

        // Check the reverse resolution
        bytes32 namehash = 0xdbe044f099cc5aeee236290aa7508bcb847d304cd112a364d9c4b0b6e8b80dc7; // namehash('foo-bar.bera')
        address owner = registry.owner(namehash);
        assertEq(owner, alice, "owner");

        vm.stopPrank();
    }

    function test_failure_name_not_available() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);

        registrar.register{value: 1 ether}(defaultRequest());

        bytes32 reverseNode = reverseRegistrar.node(alice);
        string memory name = resolver.name(reverseNode);
        assertEq(name, "foo-bar.bera", "name");

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.NameNotAvailable.selector, "foo-bar"));
        registrar.register{value: 1 ether}(defaultRequest());

        bool available = registrar.available("foo-bar");
        assertFalse(available);

        vm.stopPrank();
    }

    function test_failure_not_live() public {
        setLaunchTimeInFuture();

        vm.startPrank(alice);
        vm.deal(alice, 10 ether);

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.PublicSaleNotLive.selector));
        registrar.register{value: 1 ether}(defaultRequest());
        vm.stopPrank();
    }

    function test_whitelisted_basic_success_and_resolution() public {
        setLaunchTimeInFuture();

        vm.startPrank(alice);
        vm.deal(alice, 1 ether);

        bytes memory signature = sign();
        registrar.whitelistRegister{value: 1 ether}(defaultRequest(), signature);

        // Check the resolution
        bytes32 reverseNode = reverseRegistrar.node(alice);
        string memory name = resolver.name(reverseNode);
        assertEq(name, "foo-bar.bera", "name");

        // Check the reverse resolution
        bytes32 namehash = 0xdbe044f099cc5aeee236290aa7508bcb847d304cd112a364d9c4b0b6e8b80dc7; // namehash('foo-bar.bera')
        address owner = registry.owner(namehash);
        assertEq(owner, alice, "owner");

        vm.stopPrank();
    }

    function test_reserved_failure() public {
        vm.startPrank(deployer);
        reservedRegistry.setReservedName("foo-bar");
        vm.stopPrank();

        vm.startPrank(alice);
        vm.deal(alice, 1 ether);

        vm.expectRevert(RegistrarController.NameReserved.selector);
        registrar.register{value: 1 ether}(defaultRequest());

        vm.stopPrank();
    }

    function test_create_and_resolve() public prank(alice) {
        vm.deal(alice, 1 ether);

        string memory label_ = "testor";

        // Set up a basic request & register the name
        RegistrarController.RegisterRequest memory req = defaultRequest();
        req.name = label_;
        registrar.register{value: 1 ether}(req);

        // Calculate the node for the minted name
        bytes32 node_ = _calculateNode(keccak256(bytes(label_)), BERA_NODE);

        // Configure base resolver records for the new name
        resolver.setAddr(node_, alice);
        resolver.setText(node_, "bera", "chain");

        // Hit the universal resolver to verify resolution of the records above
        bytes memory dnsEncName_ = bytes("\x06testor\x04bera\x00");
        universalResolver.resolve(
            dnsEncName_, 
            abi.encodeWithSelector(
                IAddrResolver.addr.selector, 
                node_
            )  
        );
        
        vm.stopPrank();
    }

    function test_create_and_resolve__02() public prank(alice) {        
        vm.deal(alice, 1 ether);
        string memory label_ = "foo";

        // Set up a basic request & register the name
        RegistrarController.RegisterRequest memory req = defaultRequest();
        req.name = label_;
        registrar.register{value: 1 ether}(req);

        // Calculate the node for the minted name
        bytes32 node_ = _calculateNode(keccak256(bytes(label_)), BERA_NODE);
        assertEq(node_, 0x2462a02c69cc8f152ee2a38a1282ee7d0331f67fe8d218f63034af91a81af59a);

        // // Verify the reverse resolution was set correctly
        // assertEq(reverseRegistrar.node(alice), node_);

        // Configure base resolver records for the new name
        resolver.setText(node_, "bera", "chain");

        // Hit the universal resolver to verify resolution of the records above
        bytes memory dnsEncName_ = bytes("\x03foo\x04bera\x00");
        (
            bytes memory resp_,
            address calledResolver_
        ) = universalResolver.resolve(
            dnsEncName_, 
            abi.encodeWithSelector(
                IAddrResolver.addr.selector, 
                node_
            )  
        );
        // assertEq(address(bytes32(resp_)), address(0));
        assertEq(calledResolver_, address(resolver));

        // Set the address & resolve again
        resolver.setAddr(node_, alice);
        (resp_, ) = universalResolver.resolve(
            dnsEncName_, 
            abi.encodeWithSelector(
                IAddrResolver.addr.selector, 
                node_
            )  
        );
        // assertEq(address(resp_), alice);

        // TODO: Mock out flow
        // // dns_encode(f39fd6e51aad88f6f4ce6ab8827279cfffb92266.addr.reverse)
        // bytes memory dnsEncodedReverseName = "\x1450BDD53e5888531868d86A4745b0588cc56837A0\x04addr\x07reverse\x00"; 
        // (string memory returnedName,,,) = universalResolver.reverse(dnsEncodedReverseName);
        // require(
        //     keccak256(abi.encodePacked(returnedName)) == keccak256(abi.encodePacked("foo.bera")), "name does not match"
        // );
        
        vm.stopPrank();
    }
    
//     function test_registrationWithZeroLengthNameFails() public {
//         setLaunchTimeInPast();

//         vm.startPrank(alice);
//         vm.deal(alice, 1 ether);

//         RegistrarController.RegisterRequest memory req = defaultRequest();
//         req.name = "";

//         vm.expectRevert(RegistrarController.InvalidName.selector);
//         registrar.register{value: 1 ether}(req);
//         vm.stopPrank();
//     }

//     function test_registrationWithMaximumLengthName() public {
//         setLaunchTimeInPast();

//         vm.startPrank(alice);
//         vm.deal(alice, 1 ether);

//         string memory maxLengthName = new string(63);
//         for (uint i = 0; i < 63; i++) {
//             bytes(maxLengthName)[i] = bytes1(uint8(97 + (i % 26))); // a-z
//         }

//         RegistrarController.RegisterRequest memory req = defaultRequest();
//         req.name = maxLengthName;

//         registrar.register{value: 1 ether}(req);

//         // Verify ownership
//         bytes32 node = keccak256(abi.encodePacked(BERA_NODE, keccak256(bytes(maxLengthName))));
//         address owner = registry.owner(node);
//         assertEq(owner, alice, "Owner does not match");

//         vm.stopPrank();
//     }

//     function test_registrationFailsWithInvalidCharacters() public {
//         setLaunchTimeInPast();

//         vm.startPrank(alice);
//         vm.deal(alice, 1 ether);

//         RegistrarController.RegisterRequest memory req = defaultRequest();
//         req.name = "invalid$name";

//         vm.expectRevert(RegistrarController.InvalidName.selector);
//         registrar.register{value: 1 ether}(req);
//         vm.stopPrank();
//     }

// function test_registrarOnlyAcceptsExactPayment() public {
//     setLaunchTimeInPast();

//     vm.startPrank(alice);
//     vm.deal(alice, 2 ether); // More than required

//     vm.expectRevert(RegistrarController.IncorrectPaymentAmount.selector);
//     registrar.register{value: 2 ether}(defaultRequest());
//     vm.stopPrank();
// }


// function test_registrarRefundsExcessPayment() public {
//     setLaunchTimeInPast();

//     vm.startPrank(alice);
//     uint256 initialBalance = alice.balance;
//     vm.deal(alice, 2 ether); // More than required

//     registrar.register{value: 2 ether}(defaultRequest());

//     uint256 finalBalance = alice.balance;
//     uint256 expectedBalance = initialBalance - 1 ether; // Registration cost is 1 ether
//     assertEq(finalBalance, expectedBalance, "Excess payment was not refunded");

//     vm.stopPrank();
// }


    // getEnsAddress => resolve(bytes, bytes) => https://viem.sh/docs/ens/actions/getEnsAddress
    // function test_viem_getEnsAddress() public {
    //     address owner = universalResolver.resolve(name, data);
    //     assertEq(owner, alice, "owner");
    // }

    // getEnsName => reverse(bytes) => https://viem.sh/docs/ens/actions/getEnsName
    // function test_viem_getEnsName() public {
    //     bytes32 reverseNode = reverseRegistrar.node(alice);
    //     string memory name = universalResolver.reverse(reverseNode);
    //     assertEq(name, "foo-bar.bera", "name");
    // }

    // getEnsResolver => findResolver(bytes) => https://viem.sh/docs/ens/actions/getEnsResolver
    // function test_viem_getEnsResolver() public {
    //     address resolver = universalResolver.findResolver(name);
    //     assertEq(resolver, address(resolver), "resolver");
    // }

    // getEnsText => getEnsText(bytes, bytes) => https://viem.sh/docs/ens/actions/getEnsText
    // function test_viem_getEnsText() public {
    //     bytes memory data = universalResolver.getEnsText(name, key);
    //     assertEq(data, "foo-bar.bera", "data");
    // }

    // getEnsAvatar => getEnsText(bytes, bytes) with key avatar => https://viem.sh/docs/ens/actions/getEnsAvatar
    // function test_viem_getEnsAvatar() public {
    //     bytes memory data = universalResolver.getEnsText(name, key);
    //     assertEq(data, "foo-bar.bera", "data");
    // }

    function _calculateNode(bytes32 labelHash_, bytes32 parent_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent_, labelHash_));
    }

    function defaultRequest() internal view returns (RegistrarController.RegisterRequest memory) {
        return RegistrarController.RegisterRequest({
            name: "foo-bar",
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
    }

    function setLaunchTimeInFuture() internal {
        vm.startPrank(registrarAdmin);
        registrar.setLaunchTime(block.timestamp + 10 days);
        vm.stopPrank();
    }

    function sign() internal view returns (bytes memory) {
        bytes memory payload = abi.encode(alice, address(0), 365 days, "foo-bar");
        bytes32 hash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", abi.encodePacked(keccak256(payload))));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, hash);

        return abi.encodePacked(r, s, v);
    }
}
