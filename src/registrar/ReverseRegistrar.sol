pragma solidity >=0.8.4;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {BNS} from "src/registry/interfaces/BNS.sol";
import {IReverseRegistrar} from "src/registrar/interfaces/IReverseRegistrar.sol";
import {Controllable} from "src/registrar/types/Controllable.sol";
import {AbstractNameResolver} from "src/resolver/interfaces/INameResolver.sol";

import {ADDR_REVERSE_NODE} from "src/utils/Constants.sol";

contract ReverseRegistrar is Controllable, IReverseRegistrar {
    BNS public immutable registry;
    AbstractNameResolver public defaultResolver;

    event ReverseClaimed(address indexed addr, bytes32 indexed node);
    event DefaultResolverChanged(AbstractNameResolver indexed resolver);

    /**
     * @dev Constructor
     * @param registry_ The address of the BNS registry.
     */
    constructor(BNS registry_) Controllable(msg.sender) {
        registry = registry_;
        // Note: caller needs to assign ownership of the reverse record to the registrar
    }

    modifier authorised(address addr) {
        require(
            addr == msg.sender || controllers[msg.sender] || registry.isApprovedForAll(addr, msg.sender)
                || ownsContract(addr),
            "ReverseRegistrar: Caller is not a controller or authorised by address or the address itself"
        );
        _;
    }

    function setDefaultResolver(address resolver) public onlyOwner {
        require(address(resolver) != address(0), "ReverseRegistrar: Resolver address must not be 0");
        defaultResolver = AbstractNameResolver(resolver);
        emit DefaultResolverChanged(AbstractNameResolver(resolver));
    }

    /**
     * @dev Transfers ownership of the reverse BNS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in BNS.
     * @return The BNS node hash of the reverse record.
     */
    function claim(address owner) public returns (bytes32) {
        return claimForAddr(msg.sender, owner, address(defaultResolver));
    }

    /**
     * @dev Transfers ownership of the reverse BNS record associated with the
     *      calling account.
     * @param addr The reverse record to set
     * @param owner The address to set as the owner of the reverse record in BNS.
     * @param resolver The resolver of the reverse node
     * @return The BNS node hash of the reverse record.
     */
    function claimForAddr(address addr, address owner, address resolver) public authorised(addr) returns (bytes32) {
        bytes32 labelHash = sha3HexAddress(addr);
        bytes32 reverseNode = keccak256(abi.encodePacked(ADDR_REVERSE_NODE, labelHash));
        registry.setSubnodeRecord(ADDR_REVERSE_NODE, labelHash, owner, resolver, 0);
        emit ReverseClaimed(addr, reverseNode);
        return reverseNode;
    }

    /**
     * @dev Transfers ownership of the reverse BNS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in BNS.
     * @param resolver The address of the resolver to set; 0 to leave unchanged.
     * @return The BNS node hash of the reverse record.
     */
    function claimWithResolver(address owner, address resolver) public returns (bytes32) {
        return claimForAddr(msg.sender, owner, resolver);
    }

    /**
     * @dev Sets the `name()` record for the reverse BNS record associated with
     * the calling account. First updates the resolver to the default reverse
     * resolver if necessary.
     * @param name The name to set for this address.
     * @return The BNS node hash of the reverse record.
     */
    function setName(string memory name) public returns (bytes32) {
        return setNameForAddr(msg.sender, msg.sender, address(defaultResolver), name);
    }

    /**
     * @dev Sets the `name()` record for the reverse BNS record associated with
     * the account provided. Updates the resolver to a designated resolver
     * Only callable by controllers and authorised users
     * @param addr The reverse record to set
     * @param owner The owner of the reverse node
     * @param resolver The resolver of the reverse node
     * @param name The name to set for this address.
     * @return The BNS node hash of the reverse record.
     */
    function setNameForAddr(address addr, address owner, address resolver, string memory name)
        public
        override
        returns (bytes32)
    {
        bytes32 node_ = claimForAddr(addr, owner, resolver);
        AbstractNameResolver(resolver).setName(node_, name);
        return node_;
    }

    /**
     * @dev Returns the node hash for a given account's reverse records.
     * @param addr The address to hash
     * @return The BNS node hash.
     */
    function node(address addr) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr)));
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        bytes16 lookup = "0123456789abcdef";
        assembly {
            for { let i := 40 } gt(i, 0) {} {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }

    function ownsContract(address addr) internal view returns (bool) {
        try Ownable(addr).owner() returns (address owner) {
            return owner == msg.sender;
        } catch {
            return false;
        }
    }
}
