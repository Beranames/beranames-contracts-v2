// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Admin Controller
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Bera Name Service
import {BNS} from "src/registry/interfaces/BNS.sol";

// Interfaces
import {IExtendedResolver} from "src/resolver/interfaces/IExtendedResolver.sol";
import {IReverseRegistrar} from "src/registrar/interfaces/IReverseRegistrar.sol";

// Resolver Profiles
import {ABIResolver} from "src/resolver/profiles/ABIResolver.sol";
import {AddrResolver} from "src/resolver/profiles/AddrResolver.sol";
import {ContentHashResolver} from "src/resolver/profiles/ContentHashResolver.sol";
// import {DNSResolver} from "src/resolver/profiles/DNSResolver.sol";
import {ExtendedResolver} from "src/resolver/profiles/ExtendedResolver.sol";
import {InterfaceResolver} from "src/resolver/profiles/InterfaceResolver.sol";
import {Multicallable} from "src/resolver/types/Multicallable.sol";
import {NameResolver} from "src/resolver/profiles/NameResolver.sol";
import {PubkeyResolver} from "src/resolver/profiles/PubkeyResolver.sol";
import {TextResolver} from "src/resolver/profiles/TextResolver.sol";

/// @title BeraResolver
contract BeraDefaultResolver is
    // Accessability Controller
    Multicallable,
    // Resolvers
    ABIResolver,
    AddrResolver,
    ContentHashResolver,
    // DNSResolver,
    InterfaceResolver,
    NameResolver,
    PubkeyResolver,
    TextResolver,
    ExtendedResolver,
    // Admin Controller
    Ownable
{
    /// Errors -----------------------------------------------------------

    /// @notice Thown when msg.sender tries to set itself as an operator/delegate.
    error CantSetSelf();

    /// @notice Thown when the registrar controller is not set.
    error InvalidRegistrarController();

    /// @notice Thown when the reverse registrar is not set.
    error InvalidReverseRegistrar();

    /// Storage ----------------------------------------------------------

    /// @notice The BNS registry.
    BNS public immutable bns;

    /// @notice The trusted registrar controller contract.
    address public registrarController;

    /// @notice The reverse registrar contract.
    address public reverseRegistrar;

    /// @notice A mapping of account operators: can control owner's nodes.
    mapping(address owner => mapping(address operator => bool isApproved)) private _operatorApprovals;

    /// @notice A mapping node operators: can control a specific node.
    mapping(address owner => mapping(bytes32 node => mapping(address delegate => bool isApproved))) private
        _tokenApprovals;

    /// Events -----------------------------------------------------------

    /// @notice Emitted when an operator is added or removed.
    ///
    /// @param owner The address of the owner of names.
    /// @param operator The address of the approved operator for the `owner`.
    /// @param approved Whether the `operator` is approved or not.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Emitted when a delegate is approved or an approval is revoked.
    ///
    /// @param owner The address of the owner of the name.
    /// @param node The namehash of the name.
    /// @param delegate The address of the operator for the specified `node`.
    /// @param approved Whether the `delegate` is approved for the specified `node`.
    event Approved(address owner, bytes32 indexed node, address indexed delegate, bool indexed approved);

    /// @notice Emitted when the owner of this contract updates the Registrar Controller addrress.
    ///
    /// @param newRegistrarController The address of the new RegistrarController contract.
    event RegistrarControllerUpdated(address indexed newRegistrarController);

    /// @notice Emitted when the owner of this contract updates the Reverse Registrar address.
    ///
    /// @param newReverseRegistrar The address of the new ReverseRegistrar contract.
    event ReverseRegistrarUpdated(address indexed newReverseRegistrar);

    /// Constructor ------------------------------------------------------

    /// @notice L2 Resolver constructor used to establish the necessary contract configuration.
    ///
    /// @param bns_ The Registry contract.
    /// @param registrarController_ The address of the RegistrarController contract.
    /// @param reverseRegistrar_ The address of the ReverseRegistrar contract.
    /// @param owner_  The permissioned address initialized as the `owner` in the `Ownable` context.
    constructor(BNS bns_, address registrarController_, address reverseRegistrar_, address owner_) Ownable(owner_) {
        // Set state
        bns = bns_;

        if (registrarController_ == address(0)) revert InvalidRegistrarController();
        if (reverseRegistrar_ == address(0)) revert InvalidReverseRegistrar();

        registrarController = registrarController_;
        reverseRegistrar = reverseRegistrar_;

        // Initialize reverse registrar
        IReverseRegistrar(reverseRegistrar_).claim(owner_);
    }

    /// Authorisation Functions -----------------------------------------

    /// @dev See {IERC1155-setApprovalForAll}.
    function setApprovalForAll(address operator, bool approved) external {
        if (msg.sender == operator) revert CantSetSelf();

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @dev See {IERC1155-isApprovedForAll}.
    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /// @notice Modify the permissions for a specified `delegate` for the specified `node`.
    ///
    /// @dev This method only sets the approval status for msg.sender's nodes. This is performed without checking
    ///     the ownership of the specified `node`.
    ///
    /// @param node The namehash `node` whose permissions are being updated.
    /// @param delegate The address of the `delegate`
    /// @param approved Whether the `delegate` has approval to modify records for `msg.sender`'s `node`.
    function approve(bytes32 node, address delegate, bool approved) external {
        if (msg.sender == delegate) revert CantSetSelf();

        _tokenApprovals[msg.sender][node][delegate] = approved;
        emit Approved(msg.sender, node, delegate, approved);
    }

    /// @notice Check to see if the `delegate` has been approved by the `owner` for the `node`.
    ///
    /// @param owner The address of the name owner.
    /// @param node The namehash `node` whose permissions are being checked.
    /// @param delegate The address of the `delegate` whose permissions are being checked.
    ///
    /// @return `true` if `delegate` is approved to modify `msg.sender`'s `node`, else `false`.
    function isApprovedFor(address owner, bytes32 node, address delegate) public view returns (bool) {
        return _tokenApprovals[owner][node][delegate];
    }

    /// @notice Check to see whether `msg.sender` is authorized to modify records for the specified `node`.
    ///
    /// @dev Override for `ResolverBase:isAuthorised()`. Used in the context of each inherited resolver "profile".
    ///     Validates that `msg.sender` is one of:
    ///     1. The stored registrarController (for setting records upon registration)
    ///     2  The stored reverseRegistrar (for setting reverse records)
    ///     3. The owner of the node in the Registry
    ///     4. An approved operator for owner
    ///     5. An approved delegate for owner of the specified `node`
    ///
    /// @param node The namehashed `node` being authorized.
    ///
    /// @return `true` if `msg.sender` is authorized to modify records for the specified `node`, else `false`.
    function isAuthorised(bytes32 node) internal view override returns (bool) {
        if (msg.sender == registrarController || msg.sender == reverseRegistrar) {
            return true;
        }
        address owner = bns.owner(node);
        return owner == msg.sender || isApprovedForAll(owner, msg.sender) || isApprovedFor(owner, node, msg.sender);
    }

    /// ERC165 Interface Support -----------------------------------------

    /// @notice ERC165 compliant signal for interface support.
    /// @param interfaceID the ERC165 iface id being checked for compliance
    /// @return bool Whether this contract supports the provided interfaceID
    function supportsInterface(bytes4 interfaceID)
        public
        view
        override(
            Multicallable,
            ABIResolver,
            AddrResolver,
            ContentHashResolver,
            // DNSResolver,
            InterfaceResolver,
            NameResolver,
            PubkeyResolver,
            TextResolver
        )
        returns (bool)
    {
        return (interfaceID == type(IExtendedResolver).interfaceId || super.supportsInterface(interfaceID));
    }

    /// Admin Functions --------------------------------------------------

    /// @notice Allows the `owner` to set the registrar controller contract address.
    ///
    /// @dev Emits `RegistrarControllerUpdated` after setting the `registrarController` address.
    ///
    /// @param registrarController_ The address of the new RegistrarController contract.
    function setRegistrarController(address registrarController_) external onlyOwner {
        if (registrarController_ == address(0)) revert InvalidRegistrarController();

        registrarController = registrarController_;
        emit RegistrarControllerUpdated(registrarController_);
    }

    /// @notice Allows the `owner` to set the reverse registrar contract address.
    ///
    /// @dev Emits `ReverseRegistrarUpdated` after setting the `reverseRegistrar` address.
    ///
    /// @param reverseRegistrar_ The address of the new ReverseRegistrar contract.
    function setReverseRegistrar(address reverseRegistrar_) external onlyOwner {
        if (reverseRegistrar_ == address(0)) revert InvalidReverseRegistrar();

        reverseRegistrar = reverseRegistrar_;
        emit ReverseRegistrarUpdated(reverseRegistrar_);
    }
}
