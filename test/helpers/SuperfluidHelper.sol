// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {SuperfluidFrameworkDeployer, TestToken} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import {ERC1820RegistryCompiled} from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract SuperfluidHelper is Test {
    SuperfluidFrameworkDeployer.Framework internal sf;
    SuperfluidFrameworkDeployer internal deployer;
    TestToken internal underlyingToken;
    ISuperToken internal superToken;

    function setupSuperfluid() internal {
        // Deploy ERC1820Registry
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        // Deploy Superfluid Framework
        deployer = new SuperfluidFrameworkDeployer();
        deployer.deployTestFramework();
        sf = deployer.getFramework();

        // Deploy Super Token
        (underlyingToken, superToken) = deployer.deployWrapperSuperToken(
            "Super Token",
            "STKx",
            18,
            type(uint256).max,
            address(0)
        );
    }

    function mintSuperTokens(address account, uint256 amount) internal {
        vm.startPrank(account);

        // Mint underlying tokens
        underlyingToken.mint(account, amount);
        underlyingToken.approve(address(superToken), amount);

        // Upgrade to super tokens
        superToken.upgrade(amount);

        vm.stopPrank();
    }

    function getSuperfluidFramework()
        internal
        view
        returns (SuperfluidFrameworkDeployer.Framework memory)
    {
        return sf;
    }

    function getUnderlyingToken() internal view returns (TestToken) {
        return underlyingToken;
    }

    function getSuperToken() internal view returns (ISuperToken) {
        return superToken;
    }
}
