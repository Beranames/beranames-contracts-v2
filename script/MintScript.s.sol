// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// utils
import {Script} from "forge-std/Script.sol";
import {NameEncoder} from "src/resolver/libraries/NameEncoder.sol";
import {BERA_NODE} from "src/utils/Constants.sol";

// contracts
import {RegistrarController} from "src/registrar/Registrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {ReverseRegistrar} from "src/registrar/ReverseRegistrar.sol";
import {BeraNamesRegistry} from "src/registry/Registry.sol";
import {UniversalResolver} from "src/resolver/UniversalResolver.sol";
import {IAddrResolver} from "src/resolver/interfaces/IAddrResolver.sol";
import {ITextResolver} from "src/resolver/interfaces/ITextResolver.sol";

contract MintScript is Script {
    /// @dev
    /// 0. Make sure to have some BERA in your wallet
    /// 1. change NAME_TO_MINT to the name you want to mint and AVATAR_URL to the avatar you want to use
    /// 2. run script with the following command:
    /// forge script script/MintScript.s.sol:MintScript --rpc-url https://bartio.rpc.berachain.com/ --broadcast --private-key <your-private-key>
    /// or
    /// WALLET_DEV_PRIVATE_KEY=<your-private-key> make testnet--mint-name

    /// if you want to mint a name with less than 5 characters, update the value of .register function call

    string constant NAME_TO_MINT = "lethale";
    string constant AVATAR_URL = "https://gravatar.com/avatar/2f24b170f96b293450485caa47806abb"; // this is a gravatar, but you can also use IPFS or any other URL

    // TODO: update these contract addresses
    address constant REGISTRAR_CONTROLLER_ADDRESS = 0xad8a98885bAdAD04FFf68e519d3AcaB5Bd93f77c;
    address constant RESOLVER = 0xa83d70Ab11a4ADc8D03F4693D82D787A46Ed0a2c;
    address constant REVERSE_REGISTRAR = 0x2Fd452382ACC016F3aF3B082C3a8d6Cb73c9ec08;
    address constant REGISTRY = 0x4b5d3dB6b519244aE78D58de3F98B4D729685A0e;
    address constant UNIVERSAL_RESOLVER = 0x7bBcC659feEC3a9A05766c5Cf43D08C0a64c721F;

    RegistrarController registrar;
    BeraDefaultResolver resolver;
    ReverseRegistrar reverseRegistrar;
    BeraNamesRegistry registry;
    UniversalResolver universalResolver;

    function run() public {
        vm.startBroadcast();

        registrar = RegistrarController(REGISTRAR_CONTROLLER_ADDRESS);
        resolver = BeraDefaultResolver(RESOLVER);
        reverseRegistrar = ReverseRegistrar(REVERSE_REGISTRAR);
        registry = BeraNamesRegistry(REGISTRY);
        universalResolver = UniversalResolver(UNIVERSAL_RESOLVER);

        // mintWithoutData();
        mintWithData();
        verifyMint();

        vm.stopBroadcast();
    }

    function mintWithoutData() public {
        RegistrarController.RegisterRequest memory req = defaultRegisterRequest();

        // mint the name - 👀 - check bartio price oracle for price or call registerPrice()
        registrar.register{value: 1 ether}(req);
        // at this point, name is minted but not resolvable by Viem

        bytes32 node_ = _calculateNode(keccak256(abi.encodePacked(NAME_TO_MINT)), BERA_NODE);
        resolver.setAddr(node_, msg.sender);
        resolver.setText(node_, "avatar", AVATAR_URL);
        // at this point, name is resolvable by Viem
    }

    function mintWithData() public {
        RegistrarController.RegisterRequest memory req = defaultRegisterRequest();

        bytes32 node_ = _calculateNode(keccak256(abi.encodePacked(req.name)), BERA_NODE);
        bytes memory addrPayload = abi.encodeWithSignature("setAddr(bytes32,address)", node_, msg.sender);
        bytes memory avatarPayload =
            abi.encodeWithSignature("setText(bytes32,string,string)", node_, "avatar", AVATAR_URL);

        bytes[] memory data = new bytes[](2);
        data[0] = addrPayload;
        data[1] = avatarPayload;
        req.data = data;

        // mint the name - 👀 - check bartio price oracle for price or call registerPrice()
        registrar.register{value: 1 ether}(req);
        // at this point, name is minted AND resolvable by Viem
    }

    function verifyMint() public view {
        bytes32 node_ = _calculateNode(keccak256(abi.encodePacked(NAME_TO_MINT)), BERA_NODE);

        // 1. checking address => name resolution via reverseRegistrar - not really used because it needs 2 rpc calls
        bytes32 reverseNode = reverseRegistrar.node(msg.sender);
        string memory name = resolver.name(reverseNode);
        require(
            keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked(string.concat(NAME_TO_MINT, ".bera"))),
            "name mismatch via reverse registrar"
        );

        // 2. checking name => address resolution via registry - not really used
        address owner = registry.owner(node_);
        require(owner == msg.sender, "owner mismatch via registry");

        // 3. checking address => name via UniversalResolver - used by Viem
        string memory normalizedAddr = normalizeAddress(msg.sender);
        string memory reverseNodeString = string.concat(normalizedAddr, ".addr.reverse");
        (bytes memory dnsEncName,) = NameEncoder.dnsEncodeName(reverseNodeString);
        (string memory resolvedName,,,) = universalResolver.reverse(dnsEncName);
        require(
            keccak256(abi.encodePacked(resolvedName))
                == keccak256(abi.encodePacked(string.concat(NAME_TO_MINT, ".bera"))),
            "name mismatch via universal resolver"
        );

        // 4. checking name => address via UniversalResolver - used by Viem
        (dnsEncName,) = NameEncoder.dnsEncodeName(string.concat(NAME_TO_MINT, ".bera"));
        (bytes memory res_,) =
            universalResolver.resolve(dnsEncName, abi.encodeWithSelector(IAddrResolver.addr.selector, node_));
        address addr = abi.decode(res_, (address));
        require(addr == msg.sender, "addr mismatch via universal resolver");

        // 5. checking name => avatar resolution via reverseRegistrar
        (res_,) =
            universalResolver.resolve(dnsEncName, abi.encodeWithSelector(ITextResolver.text.selector, node_, "avatar"));
        string memory resolvedAvatar = abi.decode(res_, (string));
        require(
            keccak256(abi.encodePacked(resolvedAvatar)) == keccak256(abi.encodePacked(AVATAR_URL)),
            "avatar mismatch via reverse registrar"
        );
    }

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

        for (uint256 i = 0; i < 20; ++i) {
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

    function defaultRegisterRequest() internal view returns (RegistrarController.RegisterRequest memory) {
        return RegistrarController.RegisterRequest({
            name: NAME_TO_MINT,
            owner: msg.sender,
            duration: 365 days,
            resolver: RESOLVER,
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
    }
}
