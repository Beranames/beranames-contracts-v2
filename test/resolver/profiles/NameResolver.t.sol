// test/TestNameResolver.t.sol
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {NameResolver} from "src/resolver/profiles/NameResolver.sol";

// Dummy implementation of NameResolver for testing
contract TestNameResolver is NameResolver {
    constructor() NameResolver() {}

    function isAuthorized(bytes32) internal pure virtual returns (bool) {
        return true;
    }

    function isAuthorised(bytes32) internal view virtual override returns (bool) {
        return true;
    }
}

contract TestNameResolverTest is Test {
    TestNameResolver resolver;

    function setUp() public {
        resolver = new TestNameResolver();
    }

    function testGetEmptyName() public view {
        bytes32 node = keccak256("example");

        string memory retrievedName = resolver.name(node);
        assertEq(retrievedName, "");
    }

    function testSetName() public {
        bytes32 node = keccak256("example");
        resolver.setName(node, "example.bera");

        string memory retrievedName = resolver.name(node);
        assertEq(retrievedName, unicode"example.🐻⛓️");
    }

    function testGetName() public {
        bytes32 node = keccak256("example");
        resolver.setName(node, "example.bera");

        string memory retrievedName = resolver.name(node);
        assertEq(retrievedName, unicode"example.🐻⛓️");

        string memory retrievedNameWithoutEmojis = resolver.nameWithoutEmojis(node);
        assertEq(retrievedNameWithoutEmojis, "example.bera");
    }
}
