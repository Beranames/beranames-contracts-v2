// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {BNS} from "src/registry/interfaces/BNS.sol";

/**
 * The BNS registry contract.
 */
contract BeraNamesRegistry is BNS {
    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
    }

    mapping(bytes32 => Record) records;
    mapping(address => mapping(address => bool)) operators;

    /// @notice Thrown when a node is not authorised for a modification.
    /// @param node The node that was not authorised.
    /// @param sender The address that attempted the modification.
    error NotAuthorised(bytes32 node, address sender);

    // Permits modifications only by the owner of the specified node.
    modifier authorised(bytes32 node_) {
        address nodeOwner = records[node_].owner;
        if (nodeOwner != msg.sender && !operators[nodeOwner][msg.sender]) {
            revert NotAuthorised(node_, msg.sender);
        }
        _;
    }

    /**
     * @dev Constructs a new BNS registry.
     */
    constructor() {
        records[0x0].owner = msg.sender;
        emit Transfer(0x0, msg.sender);
    }

    /**
     * @dev Sets the record for a node.
     * @param node_ The node to update.
     * @param owner_ The address of the new owner.
     * @param resolver_ The address of the resolver.
     * @param ttl_ The TTL in seconds.
     */
    function setRecord(
        bytes32 node_,
        address owner_,
        address resolver_,
        uint64 ttl_
    ) external virtual override {
        setOwner(node_, owner_);
        _setResolverAndTTL(node_, resolver_, ttl_);
    }

    /**
     * @dev Sets the record for a subnode.
     * @param node_ The parent node.
     * @param label_ The hash of the label specifying the subnode.
     * @param owner_ The address of the new owner.
     * @param resolver_ The address of the resolver.
     * @param ttl_ The TTL in seconds.
     */
    function setSubnodeRecord(
        bytes32 node_,
        bytes32 label_,
        address owner_,
        address resolver_,
        uint64 ttl_
    ) external virtual override {
        bytes32 subnode_ = setSubnodeOwner(node_, label_, owner_);
        _setResolverAndTTL(subnode_, resolver_, ttl_);
    }

    /**
     * @dev Transfers ownership of a node to a new address. May only be called by the current owner of the node.
     * @param node_ The node to transfer ownership of.
     * @param owner_ The address of the new owner.
     */
    function setOwner(
        bytes32 node_,
        address owner_
    ) public virtual override authorised(node_) {
        _setOwner(node_, owner_);
        emit Transfer(node_, owner_);
    }

    /**
     * @dev Transfers ownership of a subnode keccak256(node, label) to a new address. May only be called by the owner of the parent node.
     * @param node_ The parent node.
     * @param label_ The hash of the label specifying the subnode.
     * @param owner_ The address of the new owner.
     */
    function setSubnodeOwner(
        bytes32 node_,
        bytes32 label_,
        address owner_
    ) public virtual override authorised(node_) returns (bytes32) {
        bytes32 subnode = keccak256(abi.encodePacked(node_, label_));
        _setOwner(subnode, owner_);
        emit NewOwner(node_, label_, owner_);
        return subnode;
    }

    /**
     * @dev Sets the resolver address for the specified node.
     * @param node_ The node to update.
     * @param resolver_ The address of the resolver.
     */
    function setResolver(
        bytes32 node_,
        address resolver_
    ) public virtual override authorised(node_) {
        emit NewResolver(node_, resolver_);
        records[node_].resolver = resolver_;
    }

    /**
     * @dev Sets the TTL for the specified node.
     * @param node_ The node to update.
     * @param ttl_ The TTL in seconds.
     */
    function setTTL(
        bytes32 node_,
        uint64 ttl_
    ) public virtual override authorised(node_) {
        emit NewTTL(node_, ttl_);
        records[node_].ttl = ttl_;
    }

    /**
     * @dev Enable or disable approval for a third party ("operator") to manage
     *  all of `msg.sender`'s BNS records. Emits the ApprovalForAll event.
     * @param operator_ Address to add to the set of authorized operators.
     * @param approved_ True if the operator is approved, false to revoke approval.
     */
    function setApprovalForAll(
        address operator_,
        bool approved_
    ) external virtual override {
        operators[msg.sender][operator_] = approved_;
        emit ApprovalForAll(msg.sender, operator_, approved_);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node_ The specified node.
     * @return address of the owner.
     */
    function owner(
        bytes32 node_
    ) public view virtual override returns (address) {
        address addr_ = records[node_].owner;
        if (addr_ == address(this)) {
            return address(0x0);
        }

        return addr_;
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node_ The specified node.
     * @return address of the resolver.
     */
    function resolver(
        bytes32 node_
    ) public view virtual override returns (address) {
        return records[node_].resolver;
    }

    /**
     * @dev Returns the TTL of a node, and any records associated with it.
     * @param node_ The specified node.
     * @return ttl of the node.
     */
    function ttl(bytes32 node_) public view virtual override returns (uint64) {
        return records[node_].ttl;
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param node_ The specified node.
     * @return Bool if record exists
     */
    function recordExists(
        bytes32 node_
    ) public view virtual override returns (bool) {
        return records[node_].owner != address(0x0);
    }

    /**
     * @dev Query if an address is an authorized operator for another address.
     * @param owner_ The address that owns the records.
     * @param operator_ The address that acts on behalf of the owner.
     * @return True if `operator_` is an approved operator for `owner_`, false otherwise.
     */
    function isApprovedForAll(
        address owner_,
        address operator_
    ) external view virtual override returns (bool) {
        return operators[owner_][operator_];
    }

    function _setOwner(bytes32 node_, address owner_) internal virtual {
        records[node_].owner = owner_;
    }

    function _setResolverAndTTL(
        bytes32 node_,
        address resolver_,
        uint64 ttl_
    ) internal {
        if (resolver_ != records[node_].resolver) {
            records[node_].resolver = resolver_;
            emit NewResolver(node_, resolver_);
        }

        if (ttl_ != records[node_].ttl) {
            records[node_].ttl = ttl_;
            emit NewTTL(node_, ttl_);
        }
    }
}
