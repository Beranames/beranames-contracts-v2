// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";

import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";
import {IReverseRegistrar} from "src/registrar/interfaces/IReverseRegistrar.sol";
import {IReservedRegistry} from "src/registrar/interfaces/IReservedRegistry.sol";

import {BERA_NODE, GRACE_PERIOD} from "src/utils/Constants.sol";
import {StringUtils} from "src/utils/StringUtils.sol";

/// @title Registrar Controller
contract RegistrarController is Ownable, ReentrancyGuard {
    using StringUtils for string;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// Errors -----------------------------------------------------------

    /// @notice Thrown when a name is not available.
    /// @param name The name that is not available.
    error NameNotAvailable(string name);

    /// @notice Thrown when a name's duration is not longer than `MIN_REGISTRATION_DURATION`.
    /// @param duration The duration that was too short.
    error DurationTooShort(uint256 duration);

    /// @notice Thrown when the public sale is not live.
    error PublicSaleNotLive();

    /// @notice Thrown when Multicallable resolver data was specified but not resolver address was provided.
    error ResolverRequiredWhenDataSupplied();

    /// @notice Thrown when the payment received is less than the price.
    error InsufficientValue();

    /// @notice Thrown when the payment receiver is being set to address(0).
    error InvalidPaymentReceiver();

    /// @notice Thrown when a signature has already been used.
    error SignatureAlreadyUsed();

    /// @notice Thrown when a refund transfer is unsuccessful.
    error TransferFailed();

    /// @notice Thrown when a name is reserved.
    error NameReserved();

    /// @notice Thrown when a reverse record is being set for another address.
    error CantSetReverseRecordForOthers();

    /// @notice Thrown when a mint limit for a round is reached.
    error MintLimitForRoundReached();

    /// @notice Thrown when someone tries to mint a reserved name but is not authorised
    error NotAuthorisedToMintReservedNames();

    /// @notice Thrown when the name is not reserved but you try to mint via reserved minting flow
    error NameNotReserved();

    /// @notice Thrown when a free mint signature has already been used.
    error FreeMintSignatureAlreadyUsed();

    /// @notice Thrown when the launch time is in the past.
    error LaunchTimeInPast();

    /// @notice Thrown when a reverse record is not allowed for reserved names.
    error ReverseRecordNotAllowedForReservedNames();

    /// @notice Thrown when the signature is invalid.
    error InvalidSignature();

    /// @notice Thrown when the free mint limit is reached.
    error FreeMintLimitReached();

    /// @notice Thrown when the whitelist signer is invalid.
    error InvalidWhitelistSigner();

    /// @notice Thrown when the free whitelist signer is invalid.
    error InvalidFreeWhitelistSigner();

    /// Events -----------------------------------------------------------

    /// @notice Emitted when an ETH payment was processed successfully.
    ///
    /// @param payee Address that sent the ETH.
    /// @param price Value that was paid.
    event ETHPaymentProcessed(address indexed payee, uint256 price);

    /// @notice Emitted when a name was registered.
    ///
    /// @param name The name that was registered.
    /// @param label The hashed label of the name.
    /// @param owner The owner of the name that was registered.
    /// @param expires The date that the registration expires.
    event NameRegistered(string name, bytes32 indexed label, address indexed owner, uint256 expires);

    /// @notice Emitted when a name is registered with a referral.
    ///
    /// @dev two different events to keep compatibility with ENS
    /// @param name The name that was registered
    /// @param label The hashed label of the name
    /// @param owner The owner of the name that was registered
    /// @param referral The address of the referral
    /// @param expires The date that the registration expires
    event NameRegisteredWithReferral(
        string name, bytes32 indexed label, address indexed owner, address indexed referral, uint256 expires
    );

    /// @notice Emitted when a name is renewed.
    ///
    /// @param name The name that was renewed.
    /// @param label The hashed label of the name.
    /// @param expires The date that the renewed name expires.
    event NameRenewed(string name, bytes32 indexed label, uint256 expires);

    /// @notice Emitted when the payment receiver is updated.
    ///
    /// @param newPaymentReceiver The address of the new payment receiver.
    event PaymentReceiverUpdated(address newPaymentReceiver);

    /// @notice Emitted when the price oracle is updated.
    ///
    /// @param newPrices The address of the new price oracle.
    event PriceOracleUpdated(address newPrices);

    /// @notice Emitted when the reverse registrar is updated.
    ///
    /// @param newReverseRegistrar The address of the new reverse registrar.
    event ReverseRegistrarUpdated(address newReverseRegistrar);

    /// @notice Emitted when the launch time is updated.
    ///
    /// @param newLaunchTime The new launch time.
    event LaunchTimeUpdated(uint256 newLaunchTime);

    /// @notice Emitted when reserved names minter is changed
    ///
    /// @param newReservedNameMinterAddress the new address;
    event ReservedNamesMinterChanged(address newReservedNameMinterAddress);

    /// @notice Emitted when whitelist authorizer is changed
    ///
    /// @param newWhitelistAuthorizerAddress the new address;
    event WhitelistAuthorizerChanged(address newWhitelistAuthorizerAddress);

    /// @notice Emitted when free whitelist authorizer is changed
    ///
    /// @param newFreeWhitelistAuthorizerAddress the new address;
    event FreeWhitelistAuthorizerChanged(address newFreeWhitelistAuthorizerAddress);

    /// Datastructures ---------------------------------------------------

    /// @notice The details of a registration request.
    /// @param name The name being registered.
    /// @param owner The address of the owner for the name.
    /// @param duration The duration of the registration in seconds.
    /// @param resolver The address of the resolver to set for this name.
    /// @param data Multicallable data bytes for setting records in the associated resolver upon reigstration.
    /// @param reverseRecord Bool to decide whether to set this name as the "primary" name for the `owner`.
    /// @param referrer The address of the referrer - a zero address indicates no referrer.
    struct RegisterRequest {
        string name;
        address owner;
        uint256 duration;
        address resolver;
        bytes[] data;
        bool reverseRecord;
        address referrer;
    }

    /// @notice The details of a whitelist registration request.
    /// @param registerRequest The `RegisterRequest` struct containing the details for the registration.
    /// @param round_id The ID of the round that the registration is being made in.
    /// @param round_total_mint The total number of mints allowed in the round.
    struct WhitelistRegisterRequest {
        RegisterRequest registerRequest;
        uint256 round_id;
        uint256 round_total_mint;
    }

    /// Storage ----------------------------------------------------------

    /// @notice The implementation of the `BaseRegistrar`.
    BaseRegistrar immutable base;

    /// @notice The implementation of the pricing oracle.
    IPriceOracle public prices;

    /// @notice The implementation of the Reverse Registrar contract.
    IReverseRegistrar public reverseRegistrar;

    /// @notice The implementation of the Reserved Registry contract.
    IReservedRegistry public reservedRegistry;

    /// @notice The node for which this name enables registration. It must match the `rootNode` of `base`.
    bytes32 public immutable rootNode;

    /// @notice The name for which this registration adds subdomains for, i.e. ".bera".
    string public rootName;

    /// @notice The address that will receive ETH funds upon `withdraw()` being called.
    address public paymentReceiver;

    /// @notice The mapping of used signatures.
    mapping(bytes32 => bool) public usedSignatures;

    /// @notice The mapping of used free mints signatures.
    mapping(bytes32 => bool) public usedFreeMintsSignatures;

    /// @notice The mapping of mints count by round by address.
    /// example: 0x123 => { 1st Round => 3 mints, 2nd Round => 1 mint }
    mapping(address => mapping(uint256 => uint256)) public mintsCountByRoundByAddress;

    /// @notice The timestamp of "go-live". Used for setting at-launch pricing premium.
    uint256 public launchTime;

    /// Constants --------------------------------------------------------

    /// @notice The minimum registration duration, specified in seconds.
    uint256 public constant MIN_REGISTRATION_DURATION = 365 days;

    /// @notice The minimum name length.
    uint256 public constant MIN_NAME_LENGTH = 1;

    /// @notice The address of the reserved names minter.
    address private reservedNamesMinter;

    /// @notice The address of the whitelist authorizer.
    address private whitelistAuthorizer;

    /// @notice The address of the free whitelist authorizer.
    address private freeWhitelistAuthorizer;

    /// @notice The mapping of free mints count by address.
    mapping(address => uint8) public freeMintsByAddress;

    /// Modifiers --------------------------------------------------------

    /// @notice Decorator for validating registration requests.
    ///
    /// @dev Validates that:
    ///     1. There is a `resolver` specified` when `data` is set
    ///     2. That the name is `available()`
    ///     3. That the registration `duration` is sufficiently long
    ///
    /// @param request The RegisterRequest that is being validated.
    modifier validRegistration(RegisterRequest calldata request) {
        if (request.data.length > 0 && request.resolver == address(0)) {
            revert ResolverRequiredWhenDataSupplied();
        }
        if (!available(request.name)) {
            revert NameNotAvailable(request.name);
        }
        if (request.duration < MIN_REGISTRATION_DURATION) {
            revert DurationTooShort(request.duration);
        }
        _;
    }

    /// @notice Decorator for validating that the public sale is live.
    modifier publicSaleLive() {
        if (block.timestamp < launchTime) revert PublicSaleNotLive();
        _;
    }

    /// Constructor ------------------------------------------------------

    /// @notice Registrar Controller construction sets all of the requisite external contracts.
    ///
    /// @dev Assigns ownership of this contract's reverse record to the `owner_`.
    ///
    /// @param base_ The base registrar contract.
    /// @param prices_ The pricing oracle contract.
    /// @param reverseRegistrar_ The reverse registrar contract.
    /// @param whitelistSigner_ The whitelist signer contract.
    /// @param freeWhitelistSigner_ The free whitelist signer contract.
    /// @param reservedRegistry_ The reserved registry contract.
    /// @param owner_ The permissioned address initialized as the `owner` in the `Ownable` context.
    /// @param rootNode_ The node for which this registrar manages registrations.
    /// @param rootName_ The name of the root node which this registrar manages.
    /// @param paymentReceiver_ The address that will receive ETH funds upon `withdraw()` being called.
    constructor(
        BaseRegistrar base_,
        IPriceOracle prices_,
        IReverseRegistrar reverseRegistrar_,
        address whitelistSigner_,
        address freeWhitelistSigner_,
        IReservedRegistry reservedRegistry_,
        address owner_,
        bytes32 rootNode_,
        string memory rootName_,
        address paymentReceiver_
    ) Ownable(owner_) {
        base = base_;
        prices = prices_;
        reverseRegistrar = reverseRegistrar_;
        if (whitelistSigner_ == address(0)) revert InvalidWhitelistSigner();
        whitelistAuthorizer = whitelistSigner_;
        if (freeWhitelistSigner_ == address(0)) revert InvalidFreeWhitelistSigner();
        freeWhitelistAuthorizer = freeWhitelistSigner_;
        rootNode = rootNode_;
        rootName = rootName_;
        paymentReceiver = paymentReceiver_;
        reservedRegistry = reservedRegistry_;
        reverseRegistrar.claim(owner_);
    }

    /// Admin Functions ------------------------------------------------

    /// @notice Allows the `owner` to set the pricing oracle contract.
    ///
    /// @dev Emits `PriceOracleUpdated` after setting the `prices` contract.
    ///
    /// @param prices_ The new pricing oracle.
    function setPriceOracle(IPriceOracle prices_) external onlyOwner {
        prices = prices_;
        emit PriceOracleUpdated(address(prices_));
    }

    /// @notice Allows the `owner` to set the reverse registrar contract.
    ///
    /// @dev Emits `ReverseRegistrarUpdated` after setting the `reverseRegistrar` contract.
    ///
    /// @param reverse_ The new reverse registrar contract.
    function setReverseRegistrar(IReverseRegistrar reverse_) external onlyOwner {
        reverseRegistrar = reverse_;
        emit ReverseRegistrarUpdated(address(reverse_));
    }

    /// @notice Allows the `owner` to set the stored `launchTime`.
    ///
    /// @param launchTime_ The new launch time timestamp.
    function setLaunchTime(uint256 launchTime_) external onlyOwner {
        if (launchTime_ < block.timestamp) {
            revert LaunchTimeInPast();
        }

        launchTime = launchTime_;
        emit LaunchTimeUpdated(launchTime_);
    }

    /// @notice Allows the `owner` to set the reverse registrar contract.
    ///
    /// @dev Emits `PaymentReceiverUpdated` after setting the `paymentReceiver` address.
    ///
    /// @param paymentReceiver_ The new payment receiver address.
    function setPaymentReceiver(address paymentReceiver_) external onlyOwner {
        if (paymentReceiver_ == address(0)) revert InvalidPaymentReceiver();
        paymentReceiver = paymentReceiver_;
        emit PaymentReceiverUpdated(paymentReceiver_);
    }

    /// @notice Checks whether the provided `name` is valid. A name is valid if it's longer than 0 chars and not a single emoji (simple or complex).
    /// a => valid
    /// foo => valid
    /// a💩 => valid
    /// 💩💩 => valid
    /// 💩 => invalid
    /// 👁️ => invalid
    /// @param name The name to check the length of.
    ///
    /// @return `true` if the name is valid, else `false`.
    function valid(string memory name) public pure returns (bool) {
        uint256 utfLen = name.utf8Length();
        uint256 strlen = name.strlen();
        return utfLen > 0 && !(strlen == MIN_NAME_LENGTH && utfLen > MIN_NAME_LENGTH);
    }

    /// @notice Checks whether the provided `name` is available.
    ///
    /// @param name The name to check the availability of.
    ///
    /// @return `true` if the name is `valid` and available on the `base` registrar, else `false`.
    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.isAvailable(uint256(label));
    }

    /// @notice Checks the rent price for a provided `name` and `duration`.
    ///
    /// @param name The name to check the rent price of.
    /// @param duration The time that the name would be rented.
    ///
    /// @return price The `Price` tuple containing the base and premium prices respectively, denominated in wei.
    function rentPrice(string memory name, uint256 duration) public view returns (IPriceOracle.Price memory price) {
        bytes32 label = keccak256(bytes(name));
        price = prices.price(name, _getExpiry(uint256(label)), duration);
    }

    /// @notice Checks the register price for a provided `name` and `duration`.
    ///
    /// @param name The name to check the register price of.
    /// @param duration The time that the name would be registered.
    ///
    /// @return The all-in price for the name registration, denominated in wei.
    function registerPrice(string memory name, uint256 duration) public view returns (uint256) {
        IPriceOracle.Price memory price = rentPrice(name, duration);
        return price.base - price.discount;
    }

    /// @notice Enables a caller to register a name.
    ///
    /// @dev Validates the registration details via the `validRegistration` modifier.
    ///     This `payable` method must receive appropriate `msg.value` to pass `_validatePayment()`.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function register(RegisterRequest calldata request) public payable publicSaleLive {
        _validateRegistration(request);
        _register(request);
    }

    /// @notice Allows a whitelisted address to register a name.
    ///
    /// @dev Validates the registration details via the `validRegistration` modifier.
    ///     This `payable` method must receive appropriate `msg.value` to pass `_validatePayment()`.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    /// @param signature The signature of the whitelisted address.
    function whitelistRegister(WhitelistRegisterRequest calldata request, bytes calldata signature) public payable {
        _validateWhitelist(request, signature);
        _validateRegistration(request.registerRequest);
        _register(request.registerRequest);
    }

    /// @notice Allows a whitelisted address to register a name for free
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    /// @param signature The signature of the whitelisted address.
    function whitelistFreeRegister(RegisterRequest calldata request, bytes calldata signature)
        public
        validRegistration(request)
    {
        _validateFreeWhitelist(request, signature);

        uint256 strlen = request.name.strlen();
        if (strlen < 3) revert NameNotAvailable(request.name);

        _validateRegistration(request);
        _registerRequest(request);
    }

    /// @notice Allows the reserved names minter to register a reserved name.
    ///
    /// @dev Skips the _validateRegistration because it's callable only by reservedNamesMinter
    /// @dev Calls the _registerRequest directly because it's not payable, so we don't need to validate payment
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function reservedRegister(RegisterRequest calldata request) public validRegistration(request) {
        if (msg.sender != reservedNamesMinter) {
            revert NotAuthorisedToMintReservedNames();
        }
        if (!reservedRegistry.isReservedName(request.name)) revert NameNotReserved();
        if (request.reverseRecord) revert ReverseRecordNotAllowedForReservedNames();

        _registerRequest(request);
    }

    /// @notice Internal helper for registering a name.
    ///
    /// @dev Validates the registration details via the `validRegistration` modifier.
    ///     This `payable` method must receive appropriate `msg.value` to pass `_validatePayment()`.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function _register(RegisterRequest calldata request) internal validRegistration(request) {
        uint256 price = registerPrice(request.name, request.duration);

        _validatePayment(price);
        _registerRequest(request);
        _refundExcessEth(price);
    }

    /// @notice Allows a caller to renew a name for a specified duration.
    ///
    /// @dev This `payable` method must receive appropriate `msg.value` to pass `_validatePayment()`.
    ///     The price for renewal never incorporates pricing `premium`. This is because we only expect
    ///     renewal on names that are not expired or are in the grace period. Use the `base` price returned
    ///     by the `rentPrice` tuple to determine the price for calling this method.
    ///
    /// @param name The name that is being renewed.
    /// @param duration The duration to extend the expiry, in seconds.
    function renew(string calldata name, uint256 duration) external payable {
        bytes32 labelhash = keccak256(bytes(name));
        uint256 tokenId = uint256(labelhash);
        uint256 price = registerPrice(name, duration);

        _validatePayment(price);

        uint256 expires = base.renew(tokenId, duration);

        _refundExcessEth(price);

        emit NameRenewed(name, labelhash, expires);
    }

    /// @notice Internal helper for validating ETH payments
    ///
    /// @dev Emits `ETHPaymentProcessed` after validating the payment.
    ///
    /// @param price The expected value.
    function _validatePayment(uint256 price) internal {
        if (msg.value < price) {
            revert InsufficientValue();
        }
        emit ETHPaymentProcessed(msg.sender, price);
    }

    function _validateRegistration(RegisterRequest calldata request) internal view {
        if (reservedRegistry.isReservedName(request.name)) revert NameReserved();
        if (request.owner != msg.sender && request.reverseRecord) revert CantSetReverseRecordForOthers();
    }

    /// @notice Validates the whitelist registration request and signature.
    /// @param request The `WhitelistRegisterRequest` struct containing the details for the registration.
    /// @param signature The signature of the whitelisted address.
    /// @dev Encodes the payload following the WhitelistRegisterRequest struct order. Writes the payload hash to the `usedSignatures` mapping.
    /// @dev Checks if the payload hash has already been used.
    /// @dev Checks if the mint count for the round has not exceeded the total mint limit.
    /// @dev Checks if the signer is the whitelist authorizer.
    function _validateWhitelist(WhitelistRegisterRequest calldata request, bytes calldata signature) internal {
        bytes memory payload = abi.encode(
            request.registerRequest.name,
            request.registerRequest.owner,
            request.registerRequest.duration,
            request.registerRequest.resolver,
            request.registerRequest.data,
            request.registerRequest.reverseRecord,
            request.registerRequest.referrer,
            request.round_id,
            request.round_total_mint
        );
        bytes32 payloadHash = generatePersonalPayloadHash(payload);

        if (usedSignatures[payloadHash]) revert SignatureAlreadyUsed();
        if (mintsCountByRoundByAddress[msg.sender][request.round_id] >= request.round_total_mint) {
            revert MintLimitForRoundReached();
        }

        address signer = getSignerFromSignature(payloadHash, signature);

        if (signer == address(0) || signer != whitelistAuthorizer) revert InvalidSignature();

        usedSignatures[payloadHash] = true;
        mintsCountByRoundByAddress[msg.sender][request.round_id]++;
    }

    /// @notice Validates the free whitelist registration request and signature.
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    /// @param signature The signature of the whitelisted address.
    /// @dev Encodes the payload following the RegisterRequest struct order. Writes the payload hash to the `usedFreeMintsSignatures` mapping.
    /// @dev Checks if the payload hash has already been used.
    /// @dev Checks if the owner has just one free mint.
    function _validateFreeWhitelist(RegisterRequest calldata request, bytes calldata signature) internal {
        bytes memory payload = abi.encode(
            request.name,
            request.owner,
            request.duration,
            request.resolver,
            request.data,
            request.reverseRecord,
            request.referrer
        );
        bytes32 payloadHash = generatePersonalPayloadHash(payload);

        if (usedFreeMintsSignatures[payloadHash]) revert FreeMintSignatureAlreadyUsed();
        if (freeMintsByAddress[msg.sender] != 0) revert FreeMintLimitReached();

        address signer = getSignerFromSignature(payloadHash, signature);

        if (signer == address(0) || signer != freeWhitelistAuthorizer) revert InvalidSignature();

        usedFreeMintsSignatures[payloadHash] = true;
        freeMintsByAddress[msg.sender]++;
    }

    function generatePersonalPayloadHash(bytes memory payload) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(payload)));
    }

    function getSignerFromSignature(bytes32 payloadHash, bytes calldata signature) internal pure returns (address) {
        return ECDSA.recover(payloadHash, signature);
    }

    /// @notice Get the whitelist authorizer.
    /// @return The address of the whitelist authorizer.
    function getWhitelistAuthorizer() public view returns (address) {
        return whitelistAuthorizer;
    }

    /// @notice Get the free whitelist authorizer.
    /// @return The address of the free whitelist authorizer.
    function getFreeWhitelistAuthorizer() public view returns (address) {
        return freeWhitelistAuthorizer;
    }

    /// @notice Get the reserved names minter.
    /// @return The address of the reserved names minter.
    function getReservedNamesMinter() public view returns (address) {
        return reservedNamesMinter;
    }

    /// @notice Helper for deciding whether to include a launch-premium.
    ///
    /// @dev If the token returns a `0` expiry time, it hasn't been registered before. On launch, this will be true for all
    ///     names. Use the `launchTime` to establish a premium price around the actual launch time.
    ///
    /// @param tokenId The ID of the token to check for expiry.
    ///
    /// @return expires Returns the expiry + GRACE_PERIOD for previously registered names, else `launchTime`.
    function _getExpiry(uint256 tokenId) internal view returns (uint256 expires) {
        expires = base.nameExpires(bytes32(tokenId));
        if (expires == 0) {
            return launchTime;
        }
        return expires + GRACE_PERIOD;
    }

    /// @notice Shared registration logic for both `register()` and `whitelistRegister()`.
    ///
    /// @dev Will set records in the specified resolver if the resolver address is non zero and there is `data` in the `request`.
    ///     Will set the reverse record's owner as msg.sender if `reverseRecord` is `true`.
    ///     Emits `NameRegistered` upon successful registration.
    ///
    /// @param request The `RegisterRequest` struct containing the details for the registration.
    function _registerRequest(RegisterRequest calldata request) internal {
        uint256 expires = base.registerWithRecord(
            uint256(keccak256(bytes(request.name))), request.owner, request.duration, request.resolver, 0
        );

        if (request.data.length > 0) {
            _setRecords(request.resolver, keccak256(bytes(request.name)), request.data);
        }

        if (request.reverseRecord) {
            _setReverseRecord(request.name, request.resolver, msg.sender);
        }

        // two different events for ENS compatibility
        emit NameRegistered(request.name, keccak256(bytes(request.name)), request.owner, expires);
        if (request.referrer != address(0)) {
            emit NameRegisteredWithReferral(
                request.name, keccak256(bytes(request.name)), request.owner, request.referrer, expires
            );
        }
    }

    /// @notice Refunds any remaining `msg.value` after processing a registration or renewal given`price`.
    /// @param price The total value to be retained, denominated in wei.
    function _refundExcessEth(uint256 price) internal nonReentrant {
        if (msg.value > price) {
            (bool sent,) = payable(msg.sender).call{value: (msg.value - price)}("");
            if (!sent) revert TransferFailed();
        }
    }

    /// @notice Uses Multicallable to iteratively set records on a specified resolver.
    /// @dev `multicallWithNodeCheck` ensures that each record being set is for the specified `label`.
    /// @param resolverAddress The address of the resolver to set records on.
    /// @param label The keccak256 namehash for the specified name.
    /// @param data  The abi encoded calldata records that will be used in the multicallable resolver.
    function _setRecords(address resolverAddress, bytes32 label, bytes[] calldata data) internal {
        bytes32 nodehash = keccak256(abi.encodePacked(rootNode, label));
        BeraDefaultResolver resolver = BeraDefaultResolver(resolverAddress);
        resolver.multicallWithNodeCheck(nodehash, data);
    }

    /// @notice Sets the reverse record to `owner` for a specified `name` on the specified `resolver.
    /// @param name The specified name.
    /// @param resolver The resolver to set the reverse record on.
    /// @param owner  The owner of the reverse record.
    function _setReverseRecord(string memory name, address resolver, address owner) internal {
        reverseRegistrar.setNameForAddr(msg.sender, owner, resolver, string.concat(name, rootName));
    }

    /// @notice Allows anyone to withdraw the eth accumulated on this contract back to the `paymentReceiver`.
    function withdrawETH() public {
        (bool sent,) = payable(paymentReceiver).call{value: (address(this).balance)}("");
        if (!sent) revert TransferFailed();
    }

    /// @notice Allows the owner to recover ERC20 tokens sent to the contract by mistake.
    function recoverFunds(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /// @notice Allows the owner to set the reserved names minter.
    /// @param reservedNamesMinter_ The address of the reserved names minter.
    function setReservedNamesMinter(address reservedNamesMinter_) external onlyOwner {
        reservedNamesMinter = reservedNamesMinter_;
        emit ReservedNamesMinterChanged(reservedNamesMinter);
    }

    function setWhitelistAuthorizer(address _whitelistAuthorizer) external onlyOwner {
        whitelistAuthorizer = _whitelistAuthorizer;
        emit WhitelistAuthorizerChanged(_whitelistAuthorizer);
    }

    function setFreeWhitelistAuthorizer(address _freeWhitelistAuthorizer) external onlyOwner {
        freeWhitelistAuthorizer = _freeWhitelistAuthorizer;
        emit FreeWhitelistAuthorizerChanged(_freeWhitelistAuthorizer);
    }
}
