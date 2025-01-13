// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {BNS} from "src/registry/interfaces/BNS.sol";

import {GRACE_PERIOD, RECLAIM_ID} from "src/utils/Constants.sol";

/// @title Base Registrar
contract BaseRegistrar is ERC721, Ownable {
    using Strings for uint256;

    /// Errors -----------------------------------------------------------

    /// @notice Thrown when the name has expired.
    ///
    /// @param tokenId The id of the token that expired.
    error Expired(uint256 tokenId);

    /// @notice Thrown when called by an unauthorized owner.
    ///
    /// @param tokenId The id that was being called against.
    /// @param sender The unauthorized sender.
    error NotApprovedOwner(uint256 tokenId, address sender);

    /// @notice Thrown when the name is not available for registration.
    ///
    /// @param tokenId The id of the name that is not available.
    error NotAvailable(uint256 tokenId);

    /// @notice Thrown when the queried tokenId does not exist.
    ///
    /// @param tokenId The id of the name that does not exist.
    error NonexistentToken(uint256 tokenId);

    /// @notice Thrown when the name is not registered or in its Grace Period.
    ///
    /// @param tokenId The id of the token that is not registered or in Grace Period.
    error NotRegisteredOrInGrace(uint256 tokenId);

    /// @notice Thrown when msg.sender is not an approved Controller.
    error OnlyController();

    /// @notice Thrown when this contract does not own the `baseNode`.
    error RegistrarNotLive();

    /// Events -----------------------------------------------------------

    /// @notice Emitted when a Controller is added to the approved `controllers` mapping.
    ///
    /// @param controller The address of the approved controller.
    event ControllerAdded(address indexed controller);

    /// @notice Emitted when a Controller is removed from the approved `controllers` mapping.
    ///
    /// @param controller The address of the removed controller.
    event ControllerRemoved(address indexed controller);

    /// @notice Emitted when a name is registered.
    ///
    /// @param id The id of the registered name.
    /// @param owner The owner of the registered name.
    /// @param expires The expiry of the new ownership record.
    event NameRegistered(uint256 indexed id, address indexed owner, uint256 expires);

    /// @notice Emitted when a name is renewed.
    ///
    /// @param id The id of the renewed name.
    /// @param expires The new expiry for the name.
    event NameRenewed(uint256 indexed id, uint256 expires);

    /// @notice Emitted when a name is registered with BNS Records.
    ///
    /// @param id The id of the newly registered name.
    /// @param owner The owner of the registered name.
    /// @param expires The expiry of the new ownership record.
    /// @param resolver The address of the resolver for the name.
    /// @param ttl The time-to-live for the name.
    event NameRegisteredWithRecord(
        uint256 indexed id, address indexed owner, uint256 expires, address resolver, uint64 ttl
    );

    /// @notice Emitted when metadata for a token range is updated.
    ///
    /// @dev Useful for third-party platforms such as NFT marketplaces who can update
    ///     the images and related attributes of the NFTs in a timely fashion.
    ///     To refresh a whole collection, emit `_toTokenId` with `type(uint256).max`
    ///     ERC-4906: https://eip.tools/eip/4906
    ///
    /// @param _fromTokenId The starting range of `tokenId` for which metadata has been updated.
    /// @param _toTokenId The ending range of `tokenId` for which metadata has been updated.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @notice Emitted when the metadata for the contract collection is updated.
    ///
    /// @dev ERC-7572: https://eips.ethereum.org/EIPS/eip-7572
    event ContractURIUpdated();

    /// Storage ----------------------------------------------------------

    /// @notice The Registry contract.
    BNS public immutable registry;

    /// @notice A map of expiry times to node.
    mapping(bytes32 node => uint256 expiry) public nameExpires;

    /// @notice The namehash of the TLD this registrar owns (eg, .bera).
    bytes32 public immutable baseNode;

    /// @notice The base URI for token metadata.
    string private _tokenURI;

    /// @notice The URI for collection metadata.
    string private _collectionURI;

    /// @notice A map of addresses that are authorised to register and renew names.
    mapping(address controller => bool isApproved) public controllers;

    /// Modifiers --------------------------------------------------------

    /// @notice Decorator for determining if the contract is actively managing registrations for its `baseNode`.
    modifier live() {
        if (registry.owner(baseNode) != address(this)) {
            revert RegistrarNotLive();
        }
        _;
    }

    /// @notice Decorator for restricting methods to only approved Controller callers.
    modifier onlyController() {
        if (!controllers[msg.sender]) revert OnlyController();
        _;
    }

    /// @notice Decorator for determining if a name is available.
    ///
    /// @param id The id being checked for availability.
    modifier onlyAvailable(uint256 id) {
        if (!isAvailable(id)) revert NotAvailable(id);
        _;
    }

    /// @notice Decorator for determining if a name has expired.
    ///
    /// @param id The id being checked for expiry.
    modifier onlyNonExpired(uint256 id) {
        if (nameExpires[bytes32(id)] <= block.timestamp) revert Expired(id);
        _;
    }

    /// Constructor ------------------------------------------------------

    /// @notice BaseRegistrar constructor used to initialize the configuration of the implementation.
    ///
    /// @param registry_ The Registry contract.
    /// @param owner_ The permissioned address initialized as the `owner` in the `Ownable` context.
    /// @param baseNode_ The node that this contract manages registrations for.
    /// @param tokenURI_ The base token URI for NFT metadata.
    /// @param collectionURI_ The URI for the collection's metadata.
    constructor(BNS registry_, address owner_, bytes32 baseNode_, string memory tokenURI_, string memory collectionURI_)
        ERC721("Beranames", unicode"🐻🪪")
        Ownable(owner_)
    {
        _transferOwnership(owner_);
        registry = registry_;
        baseNode = baseNode_;
        _tokenURI = tokenURI_;
        _collectionURI = collectionURI_;
    }

    /// Admin Functions --------------------------------------------------

    /// @notice Authorises a controller, who can register and renew domains.
    /// @dev Emits `ControllerAdded(controller)` after adding the `controller` to the `controllers` mapping.
    /// @param controller The address of the new controller.
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    /// @notice Revoke controller permission for an address.
    /// @dev Emits `ControllerRemoved(controller)` after removing the `controller` from the `controllers` mapping.
    /// @param controller The address of the controller to remove.
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    /// @notice Set the resolver for the node this registrar manages.
    /// @param resolver The address of the new resolver contract.
    function setResolver(address resolver) external onlyOwner {
        registry.setResolver(baseNode, resolver);
    }

    /// @notice Register a name and add details to the record in the Registry.
    /// @param id The token id determined by keccak256(label).
    /// @param owner The address that should own the registration.
    /// @param duration Duration in seconds for the registration.
    /// @param resolver Address of the resolver for the name.
    /// @param ttl Time-to-live for the name.
    function registerWithRecord(uint256 id, address owner, uint256 duration, address resolver, uint64 ttl)
        external
        live
        onlyController
        onlyAvailable(id)
        returns (uint256)
    {
        uint256 expiry = _localRegister(id, owner, duration);
        registry.setSubnodeRecord(baseNode, bytes32(id), owner, resolver, ttl);
        emit NameRegisteredWithRecord(id, owner, expiry, resolver, ttl);
        return expiry;
    }

    /// @notice Gets the owner of the specified token ID.
    /// @dev Names become unowned when their registration expires.
    /// @param tokenId The id of the name to query the owner of.
    /// @return address The address currently marked as the owner of the given token ID.
    function ownerOf(uint256 tokenId) public view override onlyNonExpired(tokenId) returns (address) {
        return super.ownerOf(tokenId);
    }

    /// @notice Returns true if the specified name is available for registration.
    /// @param id The id of the name to check availability of.
    /// @return `true` if the name is available, else `false`.
    function isAvailable(uint256 id) public view returns (bool) {
        // Not available if it's registered here or in its grace period.
        return nameExpires[bytes32(id)] + GRACE_PERIOD < block.timestamp;
    }

    /// @notice Allows holders of names to renew their ownerhsip and extend their expiry.
    /// @param id The id of the name to renew.
    /// @param duration The time that will be added to this name's expiry.
    /// @return The new expiry date.
    function renew(uint256 id, uint256 duration) external live onlyController returns (uint256) {
        uint256 expires = nameExpires[bytes32(id)];
        if (expires + GRACE_PERIOD < block.timestamp) {
            revert NotRegisteredOrInGrace(id);
        }

        expires += duration;
        nameExpires[bytes32(id)] = expires;
        emit NameRenewed(id, expires);
        return expires;
    }

    /// @notice ERC165 compliant signal for interface support.
    /// @param interfaceID the ERC165 iface id being checked for compliance
    /// @return bool Whether this contract supports the provided interfaceID
    function supportsInterface(bytes4 interfaceID) public pure override(ERC721) returns (bool) {
        return interfaceID == type(IERC165).interfaceId || interfaceID == type(IERC721).interfaceId
            || interfaceID == RECLAIM_ID;
    }

    /// ERC721 Implementation --------------------------------------------

    /// @notice Returns the Uniform Resource Identifier (URI) for token `id`.
    /// @dev Reverts if the `tokenId` has not be registered.
    /// @param tokenId The token for which to return the metadata uri.
    /// @return The URI for the specified `tokenId`.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert NonexistentToken(tokenId);

        return bytes(_tokenURI).length > 0 ? string.concat(_tokenURI, tokenId.toString()) : "";
    }

    /// @notice Returns the Uniform Resource Identifier (URI) for the contract.
    /// @dev ERC-7572: https://eips.ethereum.org/EIPS/eip-7572
    function contractURI() public view returns (string memory) {
        return _collectionURI;
    }

    /// @dev Allows the owner to set the the base Uniform Resource Identifier (URI)`.
    ///     Emits the `BatchMetadataUpdate` event for the full range of valid `tokenIds`.
    function setTokenURI(string memory baseURI_) public onlyOwner {
        _tokenURI = baseURI_;
        /// @dev minimum valid tokenId is `1` because uint256(nodehash) will never be called against `nodehash == 0x0`.
        emit BatchMetadataUpdate(1, type(uint256).max);
    }

    /// @dev Allows the owner to set the the contract Uniform Resource Identifier (URI)`.
    ///     Emits the `ContractURIUpdated` event.
    function setContractURI(string memory collectionURI_) public onlyOwner {
        _collectionURI = collectionURI_;
        emit ContractURIUpdated();
    }

    /// @notice transferFrom is overridden to handle the registry update.
    function transferFrom(address from, address to, uint256 tokenId) public override {
        super.transferFrom(from, to, tokenId);
        registry.setSubnodeOwner(baseNode, bytes32(tokenId), to);
    }

    /// Internal Methods -------------------------------------------------

    /// @notice Register a name and possibly update the Registry.
    /// @param id The token id determined by keccak256(label).
    /// @param owner The address that should own the registration.
    /// @param duration Duration in seconds for the registration.
    /// @param updateRegistry Whether to update the Regstiry with the ownership change
    ///
    /// @return The expiry date of the registered name.
    function _register(uint256 id, address owner, uint256 duration, bool updateRegistry)
        internal
        live
        onlyController
        onlyAvailable(id)
        returns (uint256)
    {
        uint256 expiry = _localRegister(id, owner, duration);
        if (updateRegistry) {
            registry.setSubnodeOwner(baseNode, bytes32(id), owner);
        }
        emit NameRegistered(id, owner, expiry);
        return expiry;
    }

    /// @notice Internal handler for local state changes during registrations.
    /// @dev Sets the token's expiry time and then `burn`s and `mint`s a new token.
    /// @param id The token id determined by keccak256(label).
    /// @param owner The address that should own the registration.
    /// @param duration Duration in seconds for the registration.
    ///
    /// @return expiry The expiry date of the registered name.
    function _localRegister(uint256 id, address owner, uint256 duration) internal returns (uint256 expiry) {
        expiry = block.timestamp + duration;
        nameExpires[bytes32(id)] = expiry;
        if (_ownerOf(id) != address(0)) {
            // Name was previously owned, and expired
            _burn(id);
        }
        _mint(owner, id);
    }

    /// @notice Returns whether the given spender can transfer a given token ID.
    /// @param spender address of the spender to query
    /// @param tokenId uint256 ID of the token to be transferred
    /// @return `true` if msg.sender is approved for the given token ID, is an operator of the owner,
    ///         or is the owner of the token, else `false`.
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        onlyNonExpired(tokenId)
        returns (bool)
    {
        address owner_ = _ownerOf(tokenId);
        return owner_ == spender || _isAuthorized(owner_, spender, tokenId);
    }
}
