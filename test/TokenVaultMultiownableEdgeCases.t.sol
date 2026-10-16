pragma solidity 0.4.23;

import "../TokenVault.sol";
import "../XeloraCoin.sol";

contract VmEdgeCases {
    function prank(address sender) public;
}

contract TokenVaultMultiownableEdgeCasesTest {
    VmEdgeCases private vm =
        VmEdgeCases(address(uint256(keccak256("hevm cheat code"))));

    XeloraCoin private token;
    TokenVault private vault;

    address private multiOwner = address(0x2001);
    address private nextOwner = address(0x2002);
    address private unauthorized = address(0x2003);
    address private beneficiary = address(0x2004);

    function setUp() public {
        token = new XeloraCoin();
        vault = new TokenVault(token, 1000, 0);
    }

    // 1. Zero address must not be accepted as a multi-owner.
    function testCannotAddZeroAddress() public {
        bool success = address(vault).call(
            bytes4(keccak256("addMultiOwner(address)")),
            address(0)
        );

        require(!success);
        require(!vault.multiOwners(address(0)));
    }

    // 2. Adding the same multi-owner twice must fail.
    function testCannotAddDuplicateMultiOwner() public {
        vault.addMultiOwner(multiOwner);

        bool success = address(vault).call(
            bytes4(keccak256("addMultiOwner(address)")),
            multiOwner
        );

        require(!success);
        require(vault.multiOwners(multiOwner));
    }

    // 3. A removed multi-owner must no longer set allocations.
    function testRemovedMultiOwnerCannotSetAllocation() public {
        vault.addMultiOwner(multiOwner);
        vault.removeMultiOwner(multiOwner);

        vm.prank(multiOwner);
        bool success = address(vault).call(
            bytes4(keccak256("setAllocation(address,uint256)")),
            beneficiary,
            uint256(100)
        );

        require(!success);
        require(vault.allocations(beneficiary) == 0);
        require(vault.tokensAllocated() == 0);
    }

    // 4. A multi-owner must not manage the multi-owner list.
    function testMultiOwnerCannotManageOtherMultiOwners() public {
        vault.addMultiOwner(multiOwner);

        vm.prank(multiOwner);
        bool addSuccess = address(vault).call(
            bytes4(keccak256("addMultiOwner(address)")),
            unauthorized
        );

        vm.prank(multiOwner);
        bool removeSuccess = address(vault).call(
            bytes4(keccak256("removeMultiOwner(address)")),
            address(this)
        );

        require(!addSuccess);
        require(!removeSuccess);
        require(!vault.multiOwners(unauthorized));
        require(vault.multiOwners(address(this)));
    }

    // 5. Pending ownership alone must not change the current owner.
    function testPendingOwnerHasNoOwnershipBeforeClaim() public {
        vault.transferOwnership(nextOwner);

        require(vault.owner() == address(this));
        require(vault.pendingOwner() == nextOwner);
        require(vault.multiOwners(address(this)));
        require(!vault.multiOwners(nextOwner));

        vm.prank(nextOwner);
        bool success = address(vault).call(
            bytes4(keccak256("setAllocation(address,uint256)")),
            beneficiary,
            uint256(100)
        );

        require(!success);
        require(vault.allocations(beneficiary) == 0);
    }

    // 6. After transfer, the new owner should have multi-owner privileges.
    function testNewOwnerCanSetAllocationAfterClaim() public {
        vault.transferOwnership(nextOwner);

        vm.prank(nextOwner);
        vault.claimOwnership();

        vm.prank(nextOwner);
        bool success = vault.setAllocation(beneficiary, 100);

        require(success);
        require(vault.owner() == nextOwner);
        require(vault.multiOwners(nextOwner));
        require(vault.allocations(beneficiary) == 100);
        require(vault.tokensAllocated() == 100);
    }
}
