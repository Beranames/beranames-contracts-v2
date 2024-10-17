// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {ResolverBase} from "src/resolver/types/ResolverBase.sol";
import "src/resolver/interfaces/INameResolver.sol";
import {LibString} from "lib/solady/src/utils/LibString.sol";

import {console} from "forge-std/console.sol";

abstract contract NameResolver is INameResolver, ResolverBase {
    using LibString for string;

    mapping(uint64 => mapping(bytes32 => string)) versionable_names;

    /**
     * Sets the name associated with an BNS node, for reverse records.
     * May only be called by the owner of that node in the BNS registry.
     * @param node The node to update.
     */
    function setName(bytes32 node, string calldata newName) external virtual authorised(node) {
        versionable_names[recordVersions[node]][node] = newName;
        emit NameChanged(node, newName);
    }

    /**
     * Returns the name associated with an BNS node, for reverse records, replacing .bera with 🐻⛓️
     * Defined in EIP181.
     * @param node The BNS node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view virtual override returns (string memory) {
        return this.nameWithoutEmojis(node).replace(".bera", unicode".🐻⛓️");
    }

    /**
     * Returns the name associated with an BNS node, for reverse records, with original .bera suffix
     * @param node The BNS node to query.
     * @return The associated name.
     */
    function nameWithoutEmojis(bytes32 node) external view virtual returns (string memory) {
        return versionable_names[recordVersions[node]][node];
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(INameResolver).interfaceId || super.supportsInterface(interfaceID);
    }
}
