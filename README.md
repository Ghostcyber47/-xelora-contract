# Xelora Contract
## Technical Documentation: Multiownable Authorization Update

## 1. Project Overview

This document describes the implementation and validation of a multi-owner
authorization pattern for `TokenVault`.

The change was made in response to the task requirements:

1. Modify an existing function protected by `onlyOwner` to use a
   `Multiownable` authorization pattern.
2. Document the security rationale and implementation approach.

The implementation introduces `Multiownable.sol`, integrates it into
`TokenVault.sol`, adds multi-owner administration functions, synchronizes
multi-owner membership during ownership transfer, and provides Foundry tests
for authorization and edge cases.

The Solidity version remains `0.4.23` to match the existing project.

---

## 2. Initial State and Design Problem

Before this change, `TokenVault.setAllocation()` was protected by `onlyOwner`.
Consequently, only the current owner could call this allocation-management
function.

This creates a single-account authorization boundary for allocation
management. If allocation responsibilities need to be delegated, the owner
must share the owner account or transfer ownership, neither of which is
necessary merely to grant allocation-management permission.

The requested change was to separate allocation-management permission from
the permissions reserved for the contract owner.

### Design objective

Allow explicitly authorized accounts to call `setAllocation()` while keeping
the following operations under the existing owner-only boundary:

- Ownership administration.
- `lock()`.
- `unlock()`.
- `transferFor()`.

This is a scoped access-control change. It is not intended to turn every
owner-only function into a multi-owner function.

---

## 3. Implementation Summary

The implementation changes are:

| File | Change |
|---|---|
| `Multiownable.sol` | New reusable authorization contract. |
| `TokenVault.sol` | Inherits `Multiownable`, registers the deployer, adds owner-only membership administration, updates ownership-claim handling, and changes `setAllocation()` to `onlyMultiOwner`. |
| `test/TokenVaultMultiownable.t.sol` | Tests the primary authorization and ownership-transfer behavior. |
| `test/TokenVaultMultiownableEdgeCases.t.sol` | Tests additional membership and ownership edge cases. |
| `foundry.toml` | Configures the local Foundry project and Solidity version. |
| `README.md` | Documents the rationale, design, test process, and limitations. |

---

## 4. Multiownable Contract Design

`Multiownable.sol` defines the multi-owner authorization mechanism.

### 4.1 Membership mapping

The contract maintains:

    mapping(address => bool) public multiOwners;

An address is authorized for functions protected by `onlyMultiOwner` when
its mapping value is `true`.

Because the mapping is public, Solidity generates a getter that allows
clients and tests to query whether an address is currently authorized.

### 4.2 Authorization modifier

The `onlyMultiOwner` modifier checks:

    require(multiOwners[msg.sender]);

The protected function body executes only if the caller is registered.
Otherwise, the transaction reverts.

### 4.3 Adding an account

The internal `_addMultiOwner(address)` function:

1. Rejects the zero address.
2. Rejects an address that is already registered.
3. Sets the account's membership to `true`.
4. Emits `MultiOwnerAdded`.

These checks prevent invalid membership and duplicate registration.

### 4.4 Removing an account

The internal `_removeMultiOwner(address)` function:

1. Requires that the account is currently registered.
2. Sets its membership to `false`.
3. Emits `MultiOwnerRemoved`.

After removal, the account no longer satisfies `onlyMultiOwner`.

### 4.5 Administrative entry points

`TokenVault` exposes:

- `addMultiOwner(address)` — adds an authorized account.
- `removeMultiOwner(address)` — removes an authorized account.

Both functions use `onlyOwner`. A multi-owner therefore receives permission
to perform the designated protected operation, not permission to administer
the multi-owner list.

---

## 5. TokenVault Integration

### 5.1 Inheritance

`TokenVault` now inherits from both `Recoverable` and `Multiownable`.

This makes the multi-owner mapping and modifier available to `TokenVault`
while preserving its existing recovery and ownership functionality.

### 5.2 Initial registration

During deployment, the constructor registers `msg.sender` as a multi-owner.

This means the deploying owner can continue to call `setAllocation()` after
the access-control change.

### 5.3 Allocation authorization

The `setAllocation()` modifier changes from `onlyOwner` to `onlyMultiOwner`.

The resulting authorization flow is:

1. A caller submits `setAllocation()`.
2. The `onlyMultiOwner` modifier checks the caller's membership.
3. An authorized caller proceeds into the function.
4. An unauthorized caller is rejected before the function body executes.

The function's allocation logic is otherwise retained by this authorization
change.

### 5.4 Owner-only operations

The following functions remain owner-only:

- `lock()`
- `unlock()`
- `transferFor()`
- `addMultiOwner()`
- `removeMultiOwner()`

This preserves the distinction between allocation-management permission and
the broader privileges of the contract owner.

---

## 6. Ownership Transfer and Membership Synchronization

The existing ownership process uses a pending owner and a subsequent
ownership claim.

The updated `claimOwnership()` follows this sequence:

1. Save the current owner address.
2. Call `super.claimOwnership()` to execute the inherited ownership transfer.
3. Remove the previous owner from the multi-owner list if that account is
   registered.
4. Add the new owner to the multi-owner list if it is not already registered.

The intended result is that, after a successful claim:

- `owner()` identifies the new owner.
- `pendingOwner()` is cleared by the inherited ownership logic.
- The former owner no longer has allocation permission through
  `multiOwners`.
- The new owner is registered as a multi-owner.

A pending owner does not become the current owner merely by being nominated;
the ownership claim must complete.

This behavior was exercised by the test suite.

---

## 7. Security Model and Trust Boundaries

### 7.1 What the change provides

The implementation provides a simple allowlist-based authorization model
for allocation management.

The owner controls membership, while any currently registered multi-owner
can independently call the protected allocation function.

### 7.2 What the change does not provide

This pattern is **not a threshold multisignature mechanism**.

It does not require two or more owners to approve an operation. A single
registered multi-owner can call `setAllocation()` without approval from
other multi-owners.

Therefore, every account added to the list must be trusted with the
allocation-management authority granted by the protected function.

### 7.3 Owner authority

The owner remains the administrative authority for the multi-owner list.
A compromised owner account could add an unauthorized account or remove
legitimate multi-owners.

The design therefore reduces dependence on a single account for the
allocation operation, but does not eliminate trust in the owner.

### 7.4 Ownership-transfer assumptions

Membership synchronization is designed to prevent the former owner from
retaining allocation permission after the new owner claims ownership.

The test suite covers the implemented transfer sequence. Additional review
would still be needed to evaluate all interactions with inherited ownership
and recovery functionality.

### 7.5 Scope of this change

This work focuses on the requested authorization change. It does not claim
that all functions, dependencies, inheritance paths, or deployment settings
have undergone a complete security audit.

---

## 8. Test Strategy

Tests are implemented with Foundry and are separated into two files.

### 8.1 Primary authorization tests

File:

    test/TokenVaultMultiownable.t.sol

The eight tests cover:

1. The deployer starts as a multi-owner.
2. An authorized multi-owner can set an allocation.
3. An unauthorized caller cannot set an allocation.
4. An unauthorized caller cannot manage the multi-owner list.
5. Ownership transfer updates multi-owner membership.
6. The former owner cannot set an allocation after the transfer is claimed.
7. A multi-owner cannot call the owner-only `lock()` function.
8. The owner can remove a multi-owner.

### 8.2 Edge-case tests

File:

    test/TokenVaultMultiownableEdgeCases.t.sol

The six tests cover:

1. The zero address cannot be added as a multi-owner.
2. A duplicate multi-owner cannot be added.
3. A removed multi-owner cannot set an allocation.
4. A multi-owner cannot add or remove other multi-owners.
5. A pending owner does not gain ownership or allocation permission before
   claiming ownership.
6. The new owner can set an allocation after claiming ownership.

### 8.3 Recorded test results

The complete test command produced the following results:

    TokenVaultMultiownable.t.sol
    8 passed; 0 failed; 0 skipped

    TokenVaultMultiownableEdgeCases.t.sol
    6 passed; 0 failed; 0 skipped

    Total: 14 passed; 0 failed; 0 skipped

These results confirm that the listed scenarios passed in the tested local
environment. They do not prove the absence of all possible vulnerabilities.

---

## 9. Compiler and Test Environment

The project uses Solidity `0.4.23`.

The local environment used:

- Foundry `1.8.3`.
- `solc-js` version `0.4.23+commit.124ca40d`.
- A local JavaScript compiler wrapper at
  `/tmp/xelora-solc/solc-wrapper.js`.

### 9.1 Compilation issue encountered

The initial `forge test` invocation could not locate a compatible compiler
for the environment.

Calling the `solcjs` executable directly also failed with:

    Empty input was read

The compiler's JavaScript API was already being used successfully by the
project's local compilation script. A wrapper was therefore created to read
Standard JSON input from Forge, invoke the JavaScript compiler API, and
resolve imports from the project and its sibling `zeppelin` dependency.

With the wrapper configured, Forge successfully compiled the sources and
executed both test suites.

### 9.2 Run the tests in the current environment

From the project directory:

    forge test --use /tmp/xelora-solc/solc-wrapper.js -vv

The wrapper path is specific to the development environment. It is not
part of the portable project configuration and must not be assumed to exist
on another machine.

For another environment, configure a compatible Solidity `0.4.23` compiler
and ensure the legacy `zeppelin` imports resolve correctly before running
the tests.

### 9.3 Compiler warnings

The compilation output included deprecation warnings for legacy constructor
syntax in the existing `zeppelin` dependency, along with a test mutability
warning.

Compilation and all 14 tests nevertheless completed successfully. The
legacy dependency was not broadly refactored as part of this scoped change.

---

## 10. Reproduction and Review Checklist

Before committing the changes:

1. Review `TokenVault.sol` and `Multiownable.sol`.
2. Review both test files.
3. Run the complete test suite with the compatible local compiler wrapper.
4. Confirm the test result is 14 passed, 0 failed, 0 skipped.
5. Review the README against the actual implementation.
6. Ensure generated directories such as `cache/` and `out/` are not
   accidentally included in the source commit.
7. Review `git diff` and `git status` before staging files.
8. Commit only the intended source, test, configuration, and documentation
   changes.

---

## 11. Conclusion

The change introduces a multi-owner allowlist for `TokenVault` allocation
management while retaining owner-only control over membership administration
and other designated sensitive operations.

The ownership-claim flow synchronizes the new owner and former owner with
the multi-owner list. The implemented authorization behavior was tested
through 14 passing Foundry tests covering normal use and selected edge cases.

The result is a scoped access-control enhancement, not a complete security
audit or a threshold multisignature system.
