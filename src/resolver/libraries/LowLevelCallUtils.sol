// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

library LowLevelCallUtils {
    using Address for address;

    /**
     * @dev Makes a static call to the specified `target` with `data`. Return data can be fetched with
     *      `returnDataSize` and `readReturnData`.
     * @param target The address to staticcall.
     * @param data The data to pass to the call.
     * @return success True if the call succeeded, or false if it reverts.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bool success) {
        assembly {
            // Check if the target address has code
            if iszero(extcodesize(target)) { revert(0, 0) }
            // Perform the static call
            success := staticcall(gas(), target, add(data, 32), mload(data), 0, 0)
        }
    }

    /**
     * @dev Returns the size of the return data of the most recent external call.
     */
    function returnDataSize() internal pure returns (uint256 len) {
        assembly {
            len := returndatasize()
        }
    }

    /**
     * @dev Reads return data from the most recent external call.
     * @param offset Offset into the return data.
     * @param length Number of bytes to return.
     * @return data The copied return data
     * @dev Reverts if offset + length exceeds returndatasize
     */
    function readReturnData(uint256 offset, uint256 length) internal pure returns (bytes memory data) {
        data = new bytes(length);
        assembly {
            // Validate that offset + length <= returndatasize()
            if gt(add(offset, length), returndatasize()) { revert(0, 0) }
            returndatacopy(add(data, 32), offset, length)
        }
    }

    /**
     * @dev Reverts with the return data from the most recent external call.
     */
    function propagateRevert() internal pure {
        assembly {
            returndatacopy(0, 0, returndatasize())
            revert(0, returndatasize())
        }
    }
}
