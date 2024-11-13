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
import {MockPyth} from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";
// interfaces
import {IAddrResolver} from "src/resolver/interfaces/IAddrResolver.sol";
import {ITextResolver} from "src/resolver/interfaces/ITextResolver.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import {BERA_NODE, ADDR_REVERSE_NODE, REVERSE_NODE, DEFAULT_TTL} from "src/utils/Constants.sol";
import {NameEncoder} from "src/resolver/libraries/NameEncoder.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

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

    MockPyth pyth;
    bytes32 BERA_USD_PYTH_PRICE_FEED_ID = bytes32(uint256(0x1));

    function setUp() public override {
        // Setup base test
        super.setUp();
        vm.startPrank(deployer);
        // DEPLOYING CONTRACTS ----------------------------------------------------------------------------------------------

        // registry
        registry = new BeraNamesRegistry();

        // baseRegistrar
        baseRegistrar = new BaseRegistrar(
            registry, address(deployer), BERA_NODE, "https://token-uri.com", "https://collection-uri.com"
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
        resolver =
            new BeraDefaultResolver(registry, address(baseRegistrar), address(reverseRegistrar), address(deployer));

        // Create the BERA node
        registry.setSubnodeRecord(
            bytes32(0), keccak256(abi.encodePacked("bera")), address(baseRegistrar), address(resolver), DEFAULT_TTL
        );

        // Create the PriceOracle
        pyth = new MockPyth(60, 1);
        priceOracle = new PriceOracle(address(pyth), BERA_USD_PYTH_PRICE_FEED_ID);

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

        vm.prank(deployer);
        setBeraPrice(1);
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

    // BASIC FLOW TESTS --------------------------------------------------------------------------------------------------

    function test_register_success() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        // register
        registrarController.register{value: 500 ether}(registerRequestWithNoReverseRecord(alice));
        vm.stopPrank();
        // check name is registered
        assertEq(baseRegistrar.ownerOf(uint256(keccak256("cien"))), alice);
    }

    function test_register_name_is_erc721_compliant() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        registrarController.register{value: 500 ether}(registerRequestWithNoReverseRecord(alice));
        uint256 tokenId = uint256(keccak256(bytes("cien")));
        assertEq(baseRegistrar.ownerOf(tokenId), alice);
        vm.stopPrank();
    }

    function test_forwardResolution_success() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        // register and set addr
        registrarController.register{value: 500 ether}(registerRequestWithNoReverseRecord(alice));
        bytes32 label = keccak256(bytes("cien"));
        bytes32 subnode = _calculateNode(label, BERA_NODE);
        resolver.setAddr(subnode, address(alice));
        // resolve
        assertEq(resolver.addr(subnode), alice);
        vm.stopPrank();
    }

    function test_reverseResolution_success() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        // register and set addr
        registrarController.register{value: 500 ether}(registerRequestWithNoReverseRecord(alice));
        // claim and set name
        bytes32 reverseNode = reverseRegistrar.setName("cien.bera");
        bytes32 nodeReverse = reverseRegistrar.node(alice);
        assertEq(reverseNode, nodeReverse, "reverse nodes");
        // check name
        assertEq(resolver.name(reverseNode), "cien.bera", "reversed resolved");
        vm.stopPrank();
    }

    // UNIVERSAL RESOLVER TESTS ------------------------------------------------------------------------------------------

    function test_UR_forwardResolution_returns_0x00_if_setAddr_not_called() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        // register and set addr
        registrarController.register{value: 500 ether}(registerRequestWithNoReverseRecord(alice));
        bytes32 node = _calculateNode(keccak256(bytes("cien")), BERA_NODE);
        // dns encode name
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName("cien.bera");
        // resolve
        (bytes memory res_, address calledResolver_) =
            universalResolver.resolve(dnsEncName, abi.encodeWithSelector(IAddrResolver.addr.selector, node));
        address addr = abi.decode(res_, (address));
        assertEq(addr, address(0), "addr not set for forward resolution");
        assertEq(calledResolver_, address(resolver), "called BeraDefaultResolver");
        vm.stopPrank();
    }

    function test_UR_forwardResolution_returns_addr_if_setAddr_called() public prank(alice) {
        bytes32 node = registerAndSetAddr(alice);
        // dns encode name
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName("cien.bera");
        // resolve
        (bytes memory res_, address calledResolver_) =
            universalResolver.resolve(dnsEncName, abi.encodeWithSelector(IAddrResolver.addr.selector, node));
        address addr = abi.decode(res_, (address));
        assertEq(addr, address(alice), "addr is alice");
        assertEq(calledResolver_, address(resolver), "called BeraDefaultResolver");
    }

    function test_UR_reverseResolution_returns_name_if_setName_called() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        // register
        registrarController.register{value: 500 ether}(registerRequestWithNoReverseRecord(alice));
        // claim and set name
        reverseRegistrar.setName("cien.bera");
        // reverse node DNS encoded
        string memory normalizedAddr = normalizeAddress(alice);
        string memory reverseNode = string.concat(normalizedAddr, ".addr.reverse");
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName(reverseNode);
        (string memory resolvedName, address resolvedAddress,,) = universalResolver.reverse(dnsEncName);
        assertEq(resolvedName, "cien.bera", "reverse resolution success");
        assertEq(resolvedAddress, address(0), "resolvedAddress is zero address because addr is not set");
        vm.stopPrank();
    }

    function test_UR_forwardResolution_success_with_subdomain_using_parent_resolver() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        // create subdomain
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(bob), address(0), DEFAULT_TTL);
        // set addr for subdomain by bob
        vm.startPrank(bob);
        bytes32 subnode = keccak256(abi.encodePacked(nameNode, keccak256(bytes("sub"))));
        resolver.setAddr(subnode, address(bob));
        vm.stopPrank();
        // dns encode name
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName("sub.cien.bera");
        // resolve
        (bytes memory res_, address calledResolver_) =
            universalResolver.resolve(dnsEncName, abi.encodeWithSelector(IAddrResolver.addr.selector, subnode));
        address addr = abi.decode(res_, (address));
        assertEq(addr, address(bob), "addr is bob");
        assertEq(calledResolver_, address(resolver), "called BeraDefaultResolver");
    }

    function test_UR_reverseResolution_success_with_subdomain_using_parent_resolver() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        // create subdomain
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(bob), address(0), DEFAULT_TTL);
        // set name for subdomain by bob
        vm.startPrank(bob);
        reverseRegistrar.setName("sub.cien.bera");
        vm.stopPrank();
        // reverse node DNS encoded
        string memory normalizedAddr = normalizeAddress(bob);
        string memory reverseNode = string.concat(normalizedAddr, ".addr.reverse");
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName(reverseNode);
        (string memory resolvedName, address resolvedAddress,, address addrResolverAddress) =
            universalResolver.reverse(dnsEncName);
        assertEq(resolvedName, "sub.cien.bera", "reverse resolution success");
        assertEq(
            resolvedAddress, address(0), "resolvedAddress is the zero address because addr is not set for subdomain"
        );
        assertEq(addrResolverAddress, address(resolver), "addrResolverAddress is BeraDefaultResolver");
        vm.stopPrank();
    }

    // SUBDOMAINS TESTS ---------------------------------------------------------------------------------------------------

    function test_subdomain_is_not_erc721_compliant() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(bob), address(0), DEFAULT_TTL);
        uint256 tokenId = uint256(keccak256(bytes("sub")));
        // base registrar is the ERC721 contract that is the owner of the .bera node
        vm.expectRevert();
        baseRegistrar.ownerOf(tokenId);
    }

    function test_node_owner_can_delete_subnode_and_then_recreate_it() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        // NOTE: setting the subnode owner to bob
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(bob), address(0), DEFAULT_TTL);
        // NOTE: alice should be able to delete the subnode
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(0), address(0), 0);
        bytes32 subnode = keccak256(abi.encodePacked(nameNode, keccak256(bytes("sub"))));
        // NOTE: setting the subnode owner to zero address acts as a "delete"
        assertEq(registry.owner(subnode), address(0), "subnode owner is zero address");
        // NOTE: alice should be able to recreate the subnode
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(chris), address(0), DEFAULT_TTL);
        assertEq(registry.owner(subnode), address(chris), "subnode owner is now chris");
    }

    function test_node_owner_can_set_addr_for_subnode_if_node_owner_is_subnode_owner() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(alice), address(0), DEFAULT_TTL);
        bytes32 subnode = keccak256(abi.encodePacked(nameNode, keccak256(bytes("sub"))));
        resolver.setAddr(subnode, address(chris));
        assertEq(resolver.addr(subnode), address(chris), "addr is chris");
    }

    function test_node_owner_cannot_set_addr_for_subnode_if_node_owner_is_not_subnode_owner() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        registry.setSubnodeRecord(nameNode, keccak256(bytes("sub")), address(bob), address(0), DEFAULT_TTL);
        bytes32 subnode = keccak256(abi.encodePacked(nameNode, keccak256(bytes("sub"))));
        vm.expectRevert("Unauthorized");
        resolver.setAddr(subnode, address(chris));
    }

    // TEXT RECORDS TESTS ------------------------------------------------------------------------------------------------

    function test_owner_can_set_text_record_success() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        resolver.setText(nameNode, "com.discord", "_cien_");
        assertEq(resolver.text(nameNode, "com.discord"), "_cien_", "text record set");
    }

    function test_owner_can_delete_text_record_success() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        resolver.setText(nameNode, "com.discord", "_cien_");
        resolver.setText(nameNode, "com.discord", "");
        assertEq(resolver.text(nameNode, "com.discord"), "", "text record deleted");
    }

    function test_owner_can_clear_all_text_records_success() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        // set two text records
        resolver.setText(nameNode, "com.discord", "_cien_");
        resolver.setText(nameNode, "com.twitter", "_cien_");
        assertEq(resolver.text(nameNode, "com.discord"), "_cien_", "text record set");
        assertEq(resolver.text(nameNode, "com.twitter"), "_cien_", "text record set");
        // clear all text records
        resolver.clearRecords(nameNode);
        assertEq(resolver.text(nameNode, "com.discord"), "", "text record discord deleted");
        assertEq(resolver.text(nameNode, "com.twitter"), "", "text record twitter deleted");
        assertEq(resolver.addr(nameNode), address(0), "addr deleted");
        // check record version
        assertEq(resolver.recordVersions(nameNode), 1, "record version is 1");
    }

    function test_not_owner_cannot_set_text_record() public {
        vm.startPrank(alice);
        bytes32 nameNode = registerAndSetAddr(alice);
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert("Unauthorized");
        resolver.setText(nameNode, "com.discord", "_cien_");
        vm.stopPrank();
    }

    function test_UR_forwardResolution_returns_text_record_if_set() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        resolver.setText(nameNode, "com.discord", "_cien_");
        // dns encode name
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName("cien.bera");
        // resolve with UR
        (bytes memory res_, address calledResolver_) = universalResolver.resolve(
            dnsEncName, abi.encodeWithSelector(ITextResolver.text.selector, nameNode, "com.discord")
        );
        string memory text = abi.decode(res_, (string));
        assertEq(text, "_cien_", "text record set and resolved");
        assertEq(calledResolver_, address(resolver), "called BeraDefaultResolver");
    }

    function test_UR_starting_from_reverseResolution_returns_text_record_if_set() public prank(alice) {
        bytes32 nameNode = registerAndSetAddr(alice);
        resolver.setText(nameNode, "com.discord", "_cien_");
        // set name
        reverseRegistrar.setName("cien.bera");
        // reverse node DNS encoded
        string memory normalizedAddr = normalizeAddress(alice);
        string memory reverseNode = string.concat(normalizedAddr, ".addr.reverse");
        (bytes memory reverseDnsEncName,) = NameEncoder.dnsEncodeName(reverseNode);
        (string memory resolvedName,,, address beraDefaultResolverAddress) =
            universalResolver.reverse(reverseDnsEncName);
        assertEq(resolvedName, "cien.bera", "reverse resolution success");
        assertEq(beraDefaultResolverAddress, address(resolver), "called BeraDefaultResolver");
        // dns encode name
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName(resolvedName);
        // resolve from reverse resolution
        (bytes memory res_,) = universalResolver.resolve(
            dnsEncName, abi.encodeWithSelector(ITextResolver.text.selector, nameNode, "com.discord")
        );
        string memory text = abi.decode(res_, (string));
        assertEq(text, "_cien_", "text record set and resolved");
    }

    // ERC721 TESTS ------------------------------------------------------------------------------------------------------

    function test_ERC721_transferFrom_updates_registry() public prank(alice) {
        bytes32 node = registerAndSetAddr(alice);
        baseRegistrar.transferFrom(alice, bob, uint256(keccak256(bytes("cien"))));
        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes("cien")))), address(bob), "token owner is bob");
        assertEq(registry.owner(node), address(bob), "registry owner is bob");
    }

    function test_ERC721_transferFrom_allows_new_owner_to_set_record_without_explicit_reclaim() public {
        vm.startPrank(alice);
        bytes32 node = registerAndSetAddr(alice);
        baseRegistrar.transferFrom(alice, bob, uint256(keccak256(bytes("cien"))));
        vm.stopPrank();
        vm.startPrank(bob);
        resolver.setAddr(node, address(bob));
        resolver.setText(node, "com.discord", "_cien_");
        assertEq(resolver.addr(node), address(bob), "addr is bob");
        assertEq(resolver.text(node, "com.discord"), "_cien_", "text record set");
        vm.stopPrank();
    }

    // UTILITIES ----------------------------------------------------------------------------------------------------------

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

    function registerAndSetAddr(address _owner) internal returns (bytes32) {
        vm.deal(_owner, 1000 ether);
        registrarController.register{value: 500 ether}(registerRequestWithNoReverseRecord(_owner));
        bytes32 label = keccak256(bytes("cien"));
        bytes32 subnode = _calculateNode(label, BERA_NODE);
        resolver.setAddr(subnode, _owner);
        return subnode;
    }

    function registerRequestWithNoReverseRecord(address _owner)
        internal
        view
        returns (RegistrarController.RegisterRequest memory)
    {
        return RegistrarController.RegisterRequest({
            name: "cien",
            owner: _owner,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: false,
            referrer: address(0)
        });
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
}
