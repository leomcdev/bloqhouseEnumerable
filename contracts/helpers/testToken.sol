// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor () ERC20 ("TEST", "test"){
    }

    function faucet() public {
        _mint(msg.sender, 100000000);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function faucet10000() public {
        _mint(msg.sender, 10000000000);
    }
}
