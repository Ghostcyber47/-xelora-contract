pragma solidity 0.4.23;

import "../TokenVault.sol";
import "../XeloraCoin.sol";

contract Vm {
    function prank(address sender) public;
}

contract TokenVaultMultiownableTest {
    Vm private vm = Vm(address(uint256(keccak256("hevm cheat code"))));

    XeloraCoin private token;
    TokenVault private vault;

    address private multiOwner = address(0x1001);
    address private nextOwner = address(0x1002);
    address private unauthorized = address(0x1003);
    address private beneficiary = address(0x1004);

    function setUp() public {
        token = new XeloraCoin();
        vault = new TokenVault(token, 1000, 0);
    }

    function testDeployerStartsAsMultiOwner() public {
        require(vault.multiOwners(address(this)));
    }

    function testAuthorizedMultiOwnerCanSetAllocation() public {
        vault.addMultiOwner(multiOwner);

        vm.prank(multiOwner);
        bool success = vault.setAllocation(beneficiary, 1000);

        require(success);
        require(vault.allocations(beneficiary) == 1000);
        require(vault.tokensAllocated() == 1000);
    }

    function testUnauthorizedCallerCannotSetAllocation() public {
        vm.prank(unauthorized);
        bool success = address(vault).call(
            bytes4(keccak256("setAllocation(address,uint256)")),
            beneficiary,
            uint256(100)
        );

        require(!success);
        require(vault.allocations(beneficiary) == 0);
        require(vault.tokensAllocated() == 0);
    }

    function testOnlyOwnerCanManageMultiOwners() public {
        vm.prank(unauthorized);
        bool success = address(vault).call(
            bytes4(keccak256("addMultiOwner(address)")),
            multiOwner
        );

        require(!success);
        require(!vault.multiOwners(multiOwner));
    }

    function testOwnershipTransferUpdatesMultiOwners() public {
        vault.transferOwnership(nextOwner);

        vm.prank(nextOwner);
        vault.claimOwnership();

        require(vault.owner() == nextOwner);
        require(vault.pendingOwner() == address(0));
        require(!vault.multiOwners(address(this)));
        require(vault.multiOwners(nextOwner));
    }

    function testFormerOwnerCannotSetAllocationAfterTransfer() public {
        vault.transferOwnership(nextOwner);

        vm.prank(nextOwner);
        vault.claimOwnership();

        vm.prank(address(this));
        bool success = address(vault).call(
            bytes4(keccak256("setAllocation(address,uint256)")),
            beneficiary,
            uint256(100)
        );

        require(!success);
        require(vault.allocations(beneficiary) == 0);
        require(vault.tokensAllocated() == 0);
    }

    function testMultiOwnerCannotLockVault() public {
        vault.addMultiOwner(multiOwner);

        vm.prank(multiOwner);
        bool success = address(vault).call(
            bytes4(keccak256("lock()"))
        );

        require(!success);
        require(vault.lockedAt() == 0);
    }

    function testOwnerCanRemoveMultiOwner() public {
        vault.addMultiOwner(multiOwner);
        require(vault.multiOwners(multiOwner));

        vault.removeMultiOwner(multiOwner);

        require(!vault.multiOwners(multiOwner));
    }
}
