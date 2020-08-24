// 2020 (c) TON Venture Studio Ltd

pragma solidity >=0.6.0;
import "IElector.sol";
import "IDePool.sol";
import "IProxy.sol";
import "DePoolLib.sol";

contract DePoolProxyContract is IProxy {
    uint64 constant MIN_BALANCE = 5 ton;

    uint constant ERROR_IS_NOT_OWNER = 101;
    uint constant ERROR_IS_NOT_DEPOOL = 102;
    uint constant ERROR_BAD_BALANCE = 103;

    address m_dePool;

    constructor(address depool) public {
        require(msg.pubkey() == tvm.pubkey(), ERROR_IS_NOT_OWNER);
        tvm.accept();
        m_dePool = depool;
    }

    modifier onlyDePoolAndCheckBalance {
        require(msg.sender == m_dePool, ERROR_IS_NOT_DEPOOL);

        // this check is needed for correct work of proxy
        uint carry = msg.value - DePoolLib.PROXY_FEE;
        require(address(this).balance - carry >= MIN_BALANCE, ERROR_BAD_BALANCE);
        _;
    }

    /*
     * process_new_stake
     */

    /// @dev Allows to send validator request to run for validator elections
    function process_new_stake(
        uint64 queryId,
        uint256 validatorKey,
        uint32 stakeAt,
        uint32 maxFactor,
        uint256 adnlAddr,
        bytes signature,
        address elector
    ) external override onlyDePoolAndCheckBalance {
        IElector(elector).process_new_stake{value: msg.value - DePoolLib.PROXY_FEE}(
            queryId, validatorKey, stakeAt, maxFactor, adnlAddr, signature
        );
    }

    /// @dev Elector answer from process_new_stake in case of success.
    function onStakeAccept(uint64 queryId, uint32 comment) public functionID(0xF374484C) {
        // Elector contract always send 1GR
        IDePool(m_dePool).onStakeAccept{value: msg.value - DePoolLib.PROXY_FEE}(queryId, comment, msg.sender);
    }

    /// @dev Elector answer from process_new_stake in case of error.
    function onStakeReject(uint64 queryId, uint32 comment) public functionID(0xEE6F454C) {
        IDePool(m_dePool).onStakeReject{value: msg.value - DePoolLib.PROXY_FEE}(queryId, comment, msg.sender);
    }

    /*
     * recover_stake
     */

    /// @dev Allows to recover validator stake
    function recover_stake(uint64 queryId, address elector) public override onlyDePoolAndCheckBalance {
        IElector(elector).recover_stake{value: msg.value - DePoolLib.PROXY_FEE}(queryId);
    }

    /// @dev Elector answer from recover_stake in case of success.
    function onSuccessToRecoverStake(uint64 queryId) public functionID(0xF96F7324) {
        IDePool(m_dePool).onSuccessToRecoverStake{value: msg.value - DePoolLib.PROXY_FEE}(queryId, msg.sender);
    }

    fallback() external {
        TvmSlice payload = msg.data;
        (uint32 functionId, uint64 queryId) = payload.decode(uint32, uint64);
        if (functionId == 0xfffffffe) {
            IDePool(m_dePool).onFailToRecoverStake{value: msg.value - DePoolLib.PROXY_FEE}(queryId, msg.sender);
        }
    }

    receive() external {}

    /*
     * Public Getters
     */

    function getProxyInfo() public view returns (address depool, uint64 minBalance) {
        depool = m_dePool;
        minBalance = MIN_BALANCE;
    }
}