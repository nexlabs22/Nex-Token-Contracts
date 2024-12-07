// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/NEXToken.sol";
import "../src/Vesting.sol";

contract DeployNEXToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin nexTokenProxyAdmin = new ProxyAdmin(msg.sender);

        ProxyAdmin vestingProxyAdmin = new ProxyAdmin(msg.sender);

        NEXToken nexTokenImplementation = new NEXToken();

        Vesting vestingImplementation = new Vesting();

        bytes memory nexTokenData = abi.encodeWithSignature("initialize(address)", address(vestingImplementation));

        bytes memory vestingData = abi.encodeWithSignature("initialize(address)", address(nexTokenImplementation));

        TransparentUpgradeableProxy nexTokenProxy =
            new TransparentUpgradeableProxy(address(nexTokenImplementation), address(nexTokenProxyAdmin), nexTokenData);

        TransparentUpgradeableProxy vestingProxy =
            new TransparentUpgradeableProxy(address(vestingImplementation), address(vestingProxyAdmin), vestingData);

        // Logs
        console.log("NEXToken implementation deployed at:", address(nexTokenImplementation));
        console.log("NEXToken proxy deployed at:", address(nexTokenProxy));
        console.log("ProxyAdmin for NEXToken deployed at:", address(nexTokenProxyAdmin));

        console.log("Vesting implementation deployed at:", address(vestingImplementation));
        console.log("Vesting proxy deployed at:", address(vestingProxy));
        console.log("ProxyAdmin for Vesting deployed at:", address(vestingProxyAdmin));

        vm.stopBroadcast();
    }
}
