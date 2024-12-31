// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {RegistrarController} from "src/registrar/Registrar.sol";

contract Whitelist is Script {
    address public registrarControllerAddress = address(0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e);

    function run() public {
        vm.startBroadcast();
        RegistrarController registrarController = RegistrarController(registrarControllerAddress);
        vm.deal(msg.sender, 1000 ether);
        registrarController.whitelistRegister{value: 5 ether}(
            createWhitelistRegisterRequest(),
            hex"c1172bca805a1f7c3d84d167bff4b068cc3ddb74c2616e39190cbdc4ac96cec94a970717758af18935490ab9f20e68f65e01508f16bb3a50adc9f00a3453a58a1c"
        );

        vm.stopBroadcast();
    }

    function createWhitelistRegisterRequest()
        public
        pure
        returns (RegistrarController.WhitelistRegisterRequest memory)
    {
        bytes[] memory data = new bytes[](1);
        data[0] = bytes(
            hex"d5fa2b008bb94a5e2d4a0f0abd7829191adb60db5577668469dafde04249800532a5c7f3000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"
        );
        return RegistrarController.WhitelistRegisterRequest({
            registerRequest: RegistrarController.RegisterRequest({
                name: "cienwl",
                owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                duration: 365 days,
                resolver: address(0x0165878A594ca255338adfa4d48449f69242Eb8F),
                data: data,
                reverseRecord: false,
                referrer: address(0)
            }),
            round_id: uint256(1),
            round_total_mint: uint256(5)
        });
    }
}
