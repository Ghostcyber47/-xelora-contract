pragma solidity 0.4.23;

/**
 * @title Multiownable
 * @dev Maintains a list of accounts authorized to perform
 * designated multi-owner operations.
 *
 * This is an authorized-owner pattern, not a threshold multisig.
 * Any authorized multi-owner can execute a protected operation.
 */
contract Multiownable {
    mapping(address => bool) public multiOwners;

    event MultiOwnerAdded(address indexed account);
    event MultiOwnerRemoved(address indexed account);

    modifier onlyMultiOwner() {
        require(multiOwners[msg.sender]);
        _;
    }

    function _addMultiOwner(address _account) internal {
        require(_account != address(0));
        require(!multiOwners[_account]);

        multiOwners[_account] = true;

        emit MultiOwnerAdded(_account);
    }

    function _removeMultiOwner(address _account) internal {
        require(multiOwners[_account]);

        multiOwners[_account] = false;

        emit MultiOwnerRemoved(_account);
    }
}
