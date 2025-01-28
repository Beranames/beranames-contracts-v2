// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {RegistrarController} from "src/registrar/Registrar.sol";

contract Whitelist is Script {
    address public registrarControllerAddress = address(0xEdCfC63e5628a6c0a32F981294577E4010C08582);

    function run() public {
        vm.startBroadcast();
        RegistrarController registrarController = RegistrarController(registrarControllerAddress);
        // vm.deal(msg.sender, 1000 ether);

        bytes memory signature =
            hex"b9ed538360344670957ee50524355872763d426d7b44ba700f58afed74f0a03231a210a26106b04499d40962757fd77659771776b03ff62f6dce9ea57bd8e4e11c"; // get this from backend

        registrarController.whitelistRegister{value: 5 ether}(createWhitelistRegisterRequest(), signature);

        vm.stopBroadcast();
    }

    function createWhitelistRegisterRequest()
        public
        pure
        returns (RegistrarController.WhitelistRegisterRequest memory)
    {
        bytes[] memory data = new bytes[](1);
        data[0] = bytes(
            hex"d5fa2b00065ab6f65a15d22317b71131dbdc119e3fa0143b73aade166ded402a311e8ded000000000000000000000000545fa0d7993929fef64158f68799e6fadfbeb983"
        );
        return RegistrarController.WhitelistRegisterRequest({
            registerRequest: RegistrarController.RegisterRequest({
                name: "asdfdawfwadfw2",
                owner: 0x545FA0D7993929FEf64158F68799E6fAdfbEb983,
                duration: 365 days,
                resolver: 0x803f5Be298Ea026b2BfC0e3749279E30BD6EACe4,
                data: data,
                reverseRecord: true,
                referrer: address(0)
            }),
            round_id: uint256(3),
            round_total_mint: uint256(4)
        });
    }
}
