//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

library BytesUtils {
    /*
     * @dev Returns the keccak-256 hash of a byte range.
     * @param self The byte string to hash.
     * @param offset The position to start hashing at.
     * @param len The number of bytes to hash.
     * @return The hash of the byte range.
     */
    function keccak(bytes memory self, uint256 offset, uint256 len) internal pure returns (bytes32 ret) {
        require(offset + len <= self.length);
        assembly {
            ret := keccak256(add(add(self, 32), offset), len)
        }
    }

    /**
     * @dev Returns the ENS namehash of a DNS-encoded name.
     * @param self The DNS-encoded name to hash.
     * @param offset The offset at which to start hashing.
     * @return The namehash of the name.
     */
    function namehash(bytes memory self, uint256 offset) internal pure returns (bytes32) {
        // First count the number of labels
        uint256 labelCount = 0;
        uint256 countOffset = offset;

        while (countOffset < self.length) {
            bytes32 labelhash;
            uint256 newOffset;
            (labelhash, newOffset) = readLabel(self, countOffset);

            if (labelhash == bytes32(0)) {
                break;
            }

            labelCount++;
            countOffset = newOffset;
        }

        // Then find all label hashes
        bytes32[] memory labels = new bytes32[](labelCount);
        uint256 currentOffset = offset;
        uint256 index = 0;

        while (currentOffset < self.length) {
            bytes32 labelhash;
            uint256 newOffset;
            (labelhash, newOffset) = readLabel(self, currentOffset);

            if (labelhash == bytes32(0)) {
                require(currentOffset == self.length - 1, "namehash: Junk at end of name");
                break;
            }

            labels[index] = labelhash;
            index++;
            currentOffset = newOffset;
        }

        // Finally compute namehash from right to left
        bytes32 node = bytes32(0);
        while (labelCount > 0) {
            labelCount--;
            node = keccak256(abi.encodePacked(node, labels[labelCount]));
        }

        return node;
    }

    /**
     * @dev Returns the keccak-256 hash of a DNS-encoded label, and the offset to the start of the next label.
     * @param self The byte string to read a label from.
     * @param idx The index to read a label at.
     * @return labelhash The hash of the label at the specified index, or 0 if it is the last label.
     * @return newIdx The index of the start of the next label.
     */
    function readLabel(bytes memory self, uint256 idx) internal pure returns (bytes32 labelhash, uint256 newIdx) {
        require(idx < self.length, "readLabel: Index out of bounds");
        uint256 len = uint256(uint8(self[idx]));
        if (len > 0) {
            labelhash = keccak(self, idx + 1, len);
        } else {
            labelhash = bytes32(0);
        }
        newIdx = idx + len + 1;
    }
}
