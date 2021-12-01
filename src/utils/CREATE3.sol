// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.0;

import {Bytes32AddressLib} from "./Bytes32AddressLib.sol";

/// @notice Deploy to deterministic addresses without an initcode factor.
/// @author Modified from 0xSequence (https://github.com/0xsequence/create3/blob/master/contracts/Create3.sol)
library CREATE3 {
    using Bytes32AddressLib for bytes32;

    //   0x00  0x67  0x67XXXXXXXXXXXXXXXX  PUSH8 bytecode  0x363d3d37363d34f0
    //   0x01  0x3d  0x3d                  RETURNDATASIZE  0 0x363d3d37363d34f0
    //   0x02  0x52  0x52                  MSTORE
    //   0x03  0x60  0x6008                PUSH1 08        8
    //   0x04  0x60  0x6018                PUSH1 18        24 8
    //   0x05  0xf3  0xf3                  RETURN

    //--------------------------------------------------------------------------------//
    // Opcode     | Opcode + Arguments  | Description        | Stack View             //
    //--------------------------------------------------------------------------------//
    // 0x67       |  0x67XXXXXXXXXXXXXXXX | PUSH8 bytecode   | 0x363d3d37363d34f0     //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 0x363d3d37363d34f0   //
    // 0x52       |  0x52                 | MSTORE           |                        //
    // 0x60       |  0x6008               | PUSH1 08         | 8                      //
    // 0x60       |  0x6018               | PUSH1 18         | 24 8                   //
    // 0xf3       |  0xf3                 | RETURN           |                        //
    //--------------------------------------------------------------------------------//

    //   0x00  0x67  0x67XXXXXXXXXXXXXXXX  PUSH8 bytecode  0x363d3d37363d34f0
    //   0x01  0x3d  0x3d                  RETURNDATASIZE  0 0x363d3d37363d34f0
    //   0x02  0x52  0x52                  MSTORE
    //   0x03  0x60  0x6008                PUSH1 08        8
    //   0x04  0x60  0x6018                PUSH1 18        24 8
    //   0x05  0xf3  0xf3                  RETURN
    bytes internal constant PROXY_BYTECODE = hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3";

    bytes32 internal constant PROXY_BYTECODE_HASH = keccak256(PROXY_BYTECODE);

    function deploy(bytes32 salt, bytes memory creationCode) internal returns (address deployed) {
        bytes memory proxyChildBytecode = PROXY_BYTECODE;

        address proxy;
        assembly {
            // Deploy a new contract with our pre-made bytecode via CREATE2.
            // We start 32 bytes into the code to avoid copying the byte length.
            proxy := create2(0, add(proxyChildBytecode, 32), mload(proxyChildBytecode), salt)
        }
        require(proxy != address(0), "DEPLOYMENT_FAILED");

        deployed = getDeployed(salt);
        (bool success, ) = proxy.call(creationCode);
        require(success && deployed.code.length != 0, "INITIALIZATION_FAILED");
    }

    function getDeployed(bytes32 salt) internal view returns (address) {
        address proxy = keccak256(
            abi.encodePacked(
                // Prefix:
                bytes1(0xFF),
                // Creator:
                address(this),
                // Salt:
                salt,
                // Bytecode hash:
                PROXY_BYTECODE_HASH
            )
        ).fromLast20Bytes();

        return keccak256(abi.encodePacked(hex"d6_94", proxy, hex"01")).fromLast20Bytes();
    }
}
