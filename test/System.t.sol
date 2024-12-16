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
import {BeraAuctionHouse} from "src/auction/BeraAuctionHouse.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/auction/interfaces/IWETH.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {MockPyth} from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
import {AddrResolver} from "src/resolver/profiles/AddrResolver.sol";

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

    BeraAuctionHouse public auctionHouse;

    string public constant DEFAULT_NAME = "foo-bar";
    string public constant DEFAULT_NAME_WITH_BERA = "foo-bar.bera";
    uint8 public constant DEFAULT_ROUND_ID = 1;
    uint8 public constant DEFAULT_ROUND_TOTAL_MINT = 1;

    MockPyth pyth;
    bytes32 BERA_USD_PYTH_PRICE_FEED_ID = bytes32(uint256(0x1));

    function setUp() public virtual override {
        // Setup base test
        super.setUp();

        // Prank deployer
        vm.startPrank(deployer);
        vm.deal(deployer, 1000 ether);

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
        pyth = new MockPyth(60, 1);
        priceOracle = new PriceOracle(address(pyth), BERA_USD_PYTH_PRICE_FEED_ID);

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
        resolver.setRegistrarController(address(registrar));

        // Deploy the Universal Resovler
        string[] memory urls = new string[](0);
        universalResolver = new UniversalResolver(address(registry), urls);

        // Deploy the auction house
        auctionHouse = new BeraAuctionHouse(
            baseRegistrar, resolver, IWETH(weth), 1 days, 365 days, 1 ether, 10 seconds, 1, address(registrarAdmin)
        );
        auctionHouse.transferOwnership(address(registrarAdmin));
        baseRegistrar.addController(address(auctionHouse));

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

        // Stop pranking
        vm.stopPrank();

        vm.warp(10_000_000_000);

        vm.prank(deployer);
        setBeraPrice(1);
    }

    // BERA
    // https://docs.pyth.network/price-feeds/create-your-first-pyth-app/evm/part-1
    function createBeraUpdate(int64 beraPrice) private view returns (bytes[] memory) {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createPriceFeedUpdateData(
            BERA_USD_PYTH_PRICE_FEED_ID,
            beraPrice * 100_000, // price
            10 * 100_000, // confidence
            -5, // exponent
            beraPrice * 100_000, // emaPrice
            10 * 100_000, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        return updateData;
    }

    function setBeraPrice(int64 beraPrice) private {
        bytes[] memory updateData = createBeraUpdate(beraPrice);
        uint256 value = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: value}(updateData);
    }

    function test_initialized() public view {
        // registry ownership and resolvers
        assertEq(registry.owner(BERA_NODE), address(baseRegistrar), "BERA_NODE owner");
        assertEq(registry.owner(ADDR_REVERSE_NODE), address(reverseRegistrar), "ADDR_REVERSE_NODE owner");
        assertEq(registry.resolver(BERA_NODE), address(resolver), "BERA_NODE resolver");
        assertEq(registry.resolver(ADDR_REVERSE_NODE), address(0), "ADDR_REVERSE_NODE resolver");

        // check ownership
        assertEq(baseRegistrar.owner(), address(registrarAdmin), "baseRegistrar owner");
        assertEq(universalResolver.owner(), address(registrarAdmin), "universalResolver owner");
        assertEq(reverseRegistrar.owner(), address(registrarAdmin), "reverseRegistrar owner");
        assertEq(resolver.owner(), address(registrarAdmin), "resolver owner");
        assertEq(auctionHouse.owner(), address(registrarAdmin), "auctionHouse owner");

        // check reverse registrar
        assertEq(address(reverseRegistrar.registry()), address(registry), "reverseRegistrar registry");
        assertEq(address(reverseRegistrar.defaultResolver()), address(resolver), "reverseRegistrar defaultResolver");
    }

    function test_basic_success_and_resolution() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);

        RegistrarController.RegisterRequest memory req = defaultRequest();
        registrar.register{value: 500 ether}(req);

        // Check the resolution
        bytes32 reverseNode = reverseRegistrar.node(alice);
        string memory name = resolver.name(reverseNode);
        assertEq(name, DEFAULT_NAME_WITH_BERA, "name");

        // Check the reverse resolution
        bytes32 namehash = 0xdbe044f099cc5aeee236290aa7508bcb847d304cd112a364d9c4b0b6e8b80dc7; // namehash('foo-bar.bera')
        address owner = registry.owner(namehash);
        assertEq(owner, alice, "owner");

        vm.stopPrank();
    }

    function test_failure_name_not_available() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);

        registrar.register{value: 500 ether}(defaultRequest());

        bytes32 reverseNode = reverseRegistrar.node(alice);
        string memory name = resolver.name(reverseNode);
        assertEq(name, DEFAULT_NAME_WITH_BERA, "name");

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.NameNotAvailable.selector, DEFAULT_NAME));
        registrar.register{value: 500 ether}(defaultRequest());

        bool available = registrar.available(DEFAULT_NAME);
        assertFalse(available);

        vm.stopPrank();
    }

    function test_failure_not_live() public {
        setLaunchTimeInFuture();

        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.PublicSaleNotLive.selector));
        registrar.register{value: 500 ether}(defaultRequest());
        vm.stopPrank();
    }

    function test_whitelisted_basic_success_and_resolution() public {
        setLaunchTimeInFuture();

        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);

        bytes memory signature = sign();
        registrar.whitelistRegister{value: 500 ether}(defaultWhitelistRequest(), signature);

        // Check the resolution
        bytes32 reverseNode = reverseRegistrar.node(alice);
        string memory name = resolver.name(reverseNode);
        assertEq(name, DEFAULT_NAME_WITH_BERA, "name");

        // Check the reverse resolution
        bytes32 namehash = 0xdbe044f099cc5aeee236290aa7508bcb847d304cd112a364d9c4b0b6e8b80dc7; // namehash('foo-bar.bera')
        address owner = registry.owner(namehash);
        assertEq(owner, alice, "owner");

        vm.stopPrank();
    }

    function test_reserved_failure() public {
        vm.startPrank(deployer);
        reservedRegistry.setReservedName(DEFAULT_NAME);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);

        vm.expectRevert(RegistrarController.NameReserved.selector);
        registrar.register{value: 500 ether}(defaultRequest());

        vm.stopPrank();
    }

    function test_create_and_resolve() public prank(alice) {
        vm.deal(alice, 1000 ether);

        string memory label_ = "testor";

        // Set up a basic request & register the name
        RegistrarController.RegisterRequest memory req = defaultRequest();
        req.name = label_;
        registrar.register{value: 500 ether}(req);

        // Calculate the node for the minted name
        bytes32 node_ = _calculateNode(keccak256(bytes(label_)), BERA_NODE);

        // Configure base resolver records for the new name
        resolver.setAddr(node_, alice);
        resolver.setText(node_, "bera", "chain");

        // Hit the universal resolver to verify resolution of the records above
        bytes memory dnsEncName_ = bytes("\x06testor\x04bera\x00");
        universalResolver.resolve(dnsEncName_, abi.encodeWithSelector(IAddrResolver.addr.selector, node_));

        vm.stopPrank();
    }

    function test_create_and_resolve_with_universal_resolver() public prank(alice) {
        vm.deal(alice, 1000 ether);
        string memory label_ = "foo";

        // Set up a basic request & register the name
        RegistrarController.RegisterRequest memory req = defaultRequest();
        req.name = label_;
        registrar.register{value: 500 ether}(req);

        // Calculate the node for the minted name
        bytes32 node_ = _calculateNode(keccak256(bytes(label_)), BERA_NODE);
        assertEq(node_, 0x2462a02c69cc8f152ee2a38a1282ee7d0331f67fe8d218f63034af91a81af59a);

        // Hit the universal resolver to verify resolution of the records above
        bytes memory dnsEncName_ = bytes("\x03foo\x04bera\x00");
        (, address calledResolver_) =
            universalResolver.resolve(dnsEncName_, abi.encodeWithSelector(IAddrResolver.addr.selector, node_));
        // assertEq(resp_, abi.encode(alice), "resp_ should be alice"); //TODO: fix this
        assertEq(calledResolver_, address(resolver), "calledResolver_ should be resolver");

        // hardcoded dnsEncode((alice's address without 0x prefix).addr.reverse)
        bytes memory dnsEncodedReverseName =
            hex"28353062646435336535383838353331383638643836613437343562303538386363353638333761300461646472077265766572736500";
        (string memory returnedName, address resolvedAddress, address reverseResolvedAddress, address resolverAddress) =
            universalResolver.reverse(dnsEncodedReverseName);
        require(
            keccak256(abi.encodePacked(returnedName)) == keccak256(abi.encodePacked("foo.bera")), "name does not match"
        );
        // resolvedAddress should be 0x0 because the reverse resolver is not set
        require(resolvedAddress == address(0x0), "address does not match");

        // Set the address & resolve again
        resolver.setAddr(node_, alice);

        dnsEncodedReverseName =
            hex"28353062646435336535383838353331383638643836613437343562303538386363353638333761300461646472077265766572736500";
        (returnedName, resolvedAddress, reverseResolvedAddress, resolverAddress) =
            universalResolver.reverse(dnsEncodedReverseName);
        require(
            keccak256(abi.encodePacked(returnedName)) == keccak256(abi.encodePacked("foo.bera")), "name does not match"
        );
        require(resolvedAddress == alice, "address does not match");
    }

    function test_create_and_resolve_with_universal_resolver_and_data() public prank(alice) {
        vm.deal(alice, 1000 ether);
        string memory label_ = "foo";

        // Set up a basic request & register the name
        RegistrarController.RegisterRequest memory req = defaultRequest();
        req.name = label_;
        bytes32 node_ = _calculateNode(keccak256(bytes(label_)), BERA_NODE);
        bytes memory payload = abi.encodeWithSignature("setAddr(bytes32,address)", node_, alice);
        bytes[] memory data = new bytes[](1);
        data[0] = payload;
        req.data = data;
        registrar.register{value: 500 ether}(req);

        bytes memory dnsEncName_ = bytes("\x03foo\x04bera\x00");
        (, address calledResolver_) =
            universalResolver.resolve(dnsEncName_, abi.encodeWithSelector(IAddrResolver.addr.selector, node_));
        // assertEq(resp_, abi.encode(alice), "resp_ should be alice"); //TODO: fix this
        assertEq(calledResolver_, address(resolver), "calledResolver_ should be resolver");

        // hardcoded dnsEncode(alice.addr.reverse)
        bytes memory dnsEncodedReverseName =
            hex"28353062646435336535383838353331383638643836613437343562303538386363353638333761300461646472077265766572736500";
        (string memory returnedName, address resolvedAddress,,) = universalResolver.reverse(dnsEncodedReverseName);
        require(
            keccak256(abi.encodePacked(returnedName)) == keccak256(abi.encodePacked("foo.bera")), "name does not match"
        );
        // alice, because the reverse resolver is set
        require(resolvedAddress == address(alice), "address does not match");
        dnsEncodedReverseName =
            hex"28353062646435336535383838353331383638643836613437343562303538386363353638333761300461646472077265766572736500";
        (returnedName, resolvedAddress,,) = universalResolver.reverse(dnsEncodedReverseName);
        require(
            keccak256(abi.encodePacked(returnedName)) == keccak256(abi.encodePacked("foo.bera")), "name does not match"
        );
        require(resolvedAddress == alice, "address does not match");
    }

    function test_registrationWithZeroLengthNameFails() public {
        setLaunchTimeNow();

        vm.startPrank(alice);
        vm.deal(alice, 1 ether);

        RegistrarController.RegisterRequest memory req = defaultRequest();
        req.name = "";

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.NameNotAvailable.selector, ""));
        registrar.register{value: 1 ether}(req);
        vm.stopPrank();
    }

    // function test_registrarRefundsExcessPayment() public {
    //     setLaunchTimeNow();

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
    function test_viem_getEnsAddress() public prank(alice) {
        vm.deal(alice, 1000 ether);

        RegistrarController.RegisterRequest memory req = defaultRequest();
        registrar.register{value: 500 ether}(req);

        bytes32 node_ = _calculateNode(keccak256(bytes(req.name)), BERA_NODE);
        resolver.setAddr(node_, alice);

        // \x03 because foo is 3 chars
        bytes memory dnsEncName_ = bytes("\x03foo\x04bera\x00");
        (bytes memory resp_, address resolvedAddress) =
            universalResolver.resolve(dnsEncName_, abi.encodeWithSelector(IAddrResolver.addr.selector, node_));
        assertEq(abi.decode(resp_, (address)), alice, "Resolved address does not match alice");
        assertEq(resolvedAddress, resolvedAddress, "resolver not matching");

        vm.stopPrank();
    }

    // getEnsAddress => resolve(bytes, bytes) => https://viem.sh/docs/ens/actions/getEnsAddress
    function test_viem_getEnsAddress_withData() public {
        alice = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);

        RegistrarController.RegisterRequest memory req = defaultRequestWithData(alice);
        bytes32 node_ = _calculateNode(keccak256(bytes(req.name)), BERA_NODE);

        registrar.register{value: 500 ether}(req);

        // \x03 because foo is 3 chars
        bytes memory dnsEncName_ = bytes("\x03foo\x04bera\x00");
        (bytes memory resp_, address resolvedAddress) =
            universalResolver.resolve(dnsEncName_, abi.encodeWithSelector(IAddrResolver.addr.selector, node_));
        assertEq(abi.decode(resp_, (address)), alice, "Resolved address does not match alice");
        assertEq(resolvedAddress, resolvedAddress, "resolver not matching");

        vm.stopPrank();
    }

    // getEnsName => reverse(bytes) => https://viem.sh/docs/ens/actions/getEnsName
    function test_viem_getEnsName() public {
        address deterministicAddress = 0x0000000000000000000000000000000000000001;
        vm.startPrank(deterministicAddress);
        vm.deal(deterministicAddress, 1000 ether);

        registrar.register{value: 500 ether}(defaultRequestWithData(deterministicAddress));

        bytes memory dnsEncodedReverseName =
            bytes("\x280000000000000000000000000000000000000001\x04addr\x07reverse\x00");

        (string memory returnedName, address resolvedAddress, address reverseResolvedAddress, address resolverAddress) =
            universalResolver.reverse(dnsEncodedReverseName);
        assertEq(returnedName, "foo-bar.bera", "returned name does not match foo.bera");
        assertEq(resolvedAddress, deterministicAddress, "resolved address does not match alice");
        assertEq(reverseResolvedAddress, address(resolver), "reverse resolved address does not match 0");
        assertEq(resolverAddress, address(resolver), "resolver address does not match resolver");

        vm.stopPrank();
    }

    // getEnsResolver => findResolver(bytes) => https://viem.sh/docs/ens/actions/getEnsResolver
    function test_viem_getEnsResolver() public prank(alice) {
        vm.deal(alice, 1000 ether);

        RegistrarController.RegisterRequest memory req = defaultRequest();
        registrar.register{value: 500 ether}(req);

        bytes memory dnsEncName_ = bytes("\x06testor\x04bera\x00");
        (BeraDefaultResolver foundResolver,,) = universalResolver.findResolver(dnsEncName_);

        assertEq(address(foundResolver), address(resolver), "resolver");
    }

    function _calculateNode(bytes32 labelHash_, bytes32 parent_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent_, labelHash_));
    }

    function defaultRequest() internal view returns (RegistrarController.RegisterRequest memory) {
        return RegistrarController.RegisterRequest({
            name: DEFAULT_NAME,
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
    }

    function defaultRequestWithData(address owner_)
        internal
        view
        returns (RegistrarController.RegisterRequest memory)
    {
        string memory name = "foo-bar";
        bytes32 node_ = _calculateNode(keccak256(bytes(name)), BERA_NODE);
        bytes memory payload = abi.encodeWithSignature("setAddr(bytes32,address)", node_, owner_);
        bytes[] memory data = new bytes[](1);
        data[0] = payload;

        RegistrarController.RegisterRequest memory req = RegistrarController.RegisterRequest({
            name: name,
            owner: owner_,
            duration: 365 days,
            resolver: address(resolver),
            data: data,
            reverseRecord: true,
            referrer: address(0)
        });

        return req;
    }

    function defaultWhitelistRequest() internal view returns (RegistrarController.WhitelistRegisterRequest memory) {
        return RegistrarController.WhitelistRegisterRequest({
            registerRequest: defaultRequest(),
            round_id: DEFAULT_ROUND_ID,
            round_total_mint: DEFAULT_ROUND_TOTAL_MINT
        });
    }

    function setLaunchTimeInFuture() internal {
        vm.startPrank(registrarAdmin);
        registrar.setLaunchTime(block.timestamp + 10 days);
        vm.stopPrank();
    }

    function setLaunchTimeNow() internal {
        vm.startPrank(registrarAdmin);
        registrar.setLaunchTime(block.timestamp);
        vm.stopPrank();
    }

    function sign() internal view returns (bytes memory) {
        bytes memory payload =
            abi.encode(alice, address(0), 365 days, DEFAULT_NAME, DEFAULT_ROUND_ID, DEFAULT_ROUND_TOTAL_MINT);
        bytes32 hash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", abi.encodePacked(keccak256(payload))));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, hash);

        return abi.encodePacked(r, s, v);
    }
}
