// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CurveInterface.sol";
import "./RandomNumberConsumer.sol";
import "./CTokenInterface.sol";
import "hardhat/console.sol";

contract TinyLottery is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
    * @notice Event to notify the tickets boughts for the amount given
    */
    event TicketsBought(uint amount, uint lotteryID, uint userID, address user);

    /**
    * @notice Event to notify the funds investeds in the pool
    */
    event FundsInvested(uint amount);

    /**
    * @notice Event to notify how much is the reward, who is the winner and which is the winner ticket
    */
    event Winner(uint amount, uint ticket, address user);

    /**
    * @notice Event to notify that the tokens has been claimeds
    */
    event TokensClaimed(uint amount, uint lotteryID);

    struct User {
        address addr;
        uint256 funds;
    }

    struct Lottery {
        uint256 funds;
        uint256 initDate;
    }

    // ========== VARIABLES V1 ========== //

    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address private constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
    * Network: Mainnet
    * Pool: USDC
    * Address: 0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56'
    */
    CurveInterface public USDCswapper;

    /**
    * Network: Mainnet
    * Pool: USDT
    * Address: 0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C'
    */
    CurveInterface public USDTswapper;

    /**
    * Contract for access to the random number from chainlink
    * Key Hash: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef
    */
    RandomNumberConsumer public random;

    /**
    * Network: Mainnet
    * Token: cDAI
    * Address: 0x5d3a536e4d6dbd6114cc1ead35777bab948e3643
    */
    CTokenInterface public cDAI;

    /**
    * Network: Mainnet
    * Token: DAI
    * Address: 0x6B175474E89094C44Da98b954EedeAC495271d0F
    */
    IERC20 public DAI;

    /**
    * Network: Mainnet
    * Token: USDC
    * Address: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    */
    IERC20 public USDC;

    /**
    * Network: Mainnet
    * Token: USDT
    * Address: 0xdAC17F958D2ee523a2206206994597C13D831ec7
    */
    IERC20 public USDT;

    /** 
    * Receives `fee` of the total ETH used for swaps
    */    
    address public feeRecipient;

    /**
    * fee charged, initialized in 0.1%
    */ 
    uint16 public fee;

    /**
    * @dev Control variable for manage access to lotteries
    */
    uint256 public currentLottery;
    
    /**
    * @dev Control variable for manage the creations of new lotteries and claim tokens
    */
    bool public lotteryInCourse;

    /**
    * @dev In the `currentLottery` position of this array is holded the current
    * lottery and store the time when was created and the funds. Also, in the `currentLottery + 1`
    * position is stored the next week lottery
    */
    Lottery[] lotteries;

    /**
    * @dev Similar as the lotteries, the `currentLottery` position hold an array of users for the
    * current lottery and store his funds for the lottery and his address. Also, in the 
    * `currentLottery + 1` position is stored the participants of the next week lottery
    */
    mapping(uint256 => User[]) users;

    function initialize(
        address _feeRecipient, 
        uint16 _fee, 
        address _DAI, 
        address _USDC, 
        address _USDT,
        address _cDAI,
        address _randomConsumer,
        address _stableSwapUSDC,
        address _stableSwapUSDT
        ) external initializer {
        __Ownable_init();

        require(_feeRecipient != address(0));
        require(_fee > 0);
        feeRecipient = _feeRecipient;
        fee = _fee;
        DAI = IERC20(_DAI);
        USDC = IERC20(_USDC);
        USDT = IERC20(_USDT);
        cDAI = CTokenInterface(_cDAI);
        random = RandomNumberConsumer(_randomConsumer);
        USDCswapper = CurveInterface(_stableSwapUSDC);
        USDTswapper = CurveInterface(_stableSwapUSDT);
    }

    /**
    * @notice This function create lotteries and stores it in `lotteries`
    * @dev In case there are no lotteries created, this function create two lotteries.
    * The first one for the current week and the second one for the next week.
    * In case there are lotteries created, just create one lottery for the next week
    * and set the control variables for use the next lottery as the current lottery
    */
    function createLottery() external onlyOwner {
        require(!lotteryInCourse, "There is a lottery in progress");
        if(lotteries.length == 0){
            Lottery memory firstLottery;
            firstLottery.initDate = block.timestamp;
            lotteries.push(firstLottery);
            Lottery memory secondLottery;
            secondLottery.initDate = block.timestamp + (604800);
            lotteries.push(secondLottery);
            currentLottery = 0;
            lotteryInCourse = true;
        }else{
            Lottery memory newLottery;
            newLottery.initDate = block.timestamp + (604800);
            lotteries.push(newLottery);
            currentLottery = lotteries.length-2;
            lotteryInCourse = true;
        }
    }

    /**
    * @notice Buy tickets for the lottery using ETH, DAI, USDC or USDT
    * @dev In case of buy with DAI, if the user send some extra decimals they will not be taken
    * (e.g. If user send 10.1 DAI the contract just take 10 DAI). In case of other cryptos (ETH,
    * USDC and USDT), the amount is swapped for DAI (the ETH is swapped using Uniswap. The USDC
    * and USDT are swappeds using Curve) and the extra decimals results of the swap are refunded
    * to the sender (i.e. If results 10.1561 DAI from a swap, 0.1561 DAI are refunded to the sender)
    */ 
    function buyTickets(string memory _crypto) external payable{
        require(lotteryInCourse, "There is no lottery in progress");
        uint256 funds;
        uint256 result;
        User memory newUser;
        uint aux;
        if(!_isPurchasePeriod()){
            aux = 1;
        }
        if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("DAI"))){
            funds = DAI.allowance(msg.sender, address(this));
            require(funds > 0, "DAI Insufficient");
            funds = funds.div(10**18).mul(10**18);
            DAI.transferFrom(msg.sender, address(this), funds);
            newUser.addr = msg.sender;
            newUser.funds = funds;
            users[currentLottery + aux].push(newUser);
            lotteries[currentLottery + aux].funds = lotteries[currentLottery + aux].funds.add(funds);
            emit TicketsBought(funds, (currentLottery + aux), users[currentLottery + aux].length-1, msg.sender);
        }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("ETH"))){
            require(msg.value > 0, "Insufficient ETH");
            uint amount = msg.value ; uint amountOut;
            ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH9,
                tokenOut: address(DAI),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp + 1,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            amountOut = swapRouter.exactInputSingle{value: amount}(params);

            funds = amountOut.div(10**18).mul(10**18);
            if(amountOut.sub(funds) > 0){
                DAI.transfer(msg.sender, amountOut.sub(funds));
            }
            newUser.addr = msg.sender;
            newUser.funds = funds;
            users[currentLottery + aux].push(newUser);
            lotteries[currentLottery + aux].funds = lotteries[currentLottery + aux].funds.add(funds);
            emit TicketsBought(funds, (currentLottery + aux), users[currentLottery + aux].length-1, msg.sender);

        }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDC"))){
            funds = USDC.allowance(msg.sender, address(this));
            require(funds > 0, "USDC Insufficient");
            USDC.transferFrom(msg.sender, address(this), funds);
            result = USDCswapper.get_dy_underlying(1, 0, funds);
            USDC.approve(address(USDCswapper),funds);
            USDCswapper.exchange_underlying(1, 0, funds, result.div(10**9).mul(10**9));
            newUser.addr = msg.sender;
            newUser.funds = result.div(10**18).mul(10**18);
            users[currentLottery + aux].push(newUser);
            lotteries[currentLottery + aux].funds = lotteries[currentLottery + aux].funds.add(newUser.funds);
            emit TicketsBought(funds, (currentLottery + aux), users[currentLottery + aux].length-1, msg.sender);
            
        }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDT"))){
            funds = USDT.allowance(msg.sender, address(this));
            require(funds > 0, "USDT Insufficient");
            USDT.safeTransferFrom(msg.sender, address(this), funds);
            result = USDTswapper.get_dy_underlying(2, 0, funds);
            USDT.safeApprove(address(USDTswapper), funds);
            USDTswapper.exchange_underlying(2, 0, funds, result.div(10**9).mul(10**9));
            newUser.addr = msg.sender;
            newUser.funds = result.div(10**18).mul(10**18);
            users[currentLottery + aux].push(newUser);
            lotteries[currentLottery + aux].funds = lotteries[currentLottery + aux].funds.add(newUser.funds);
            emit TicketsBought(funds, (currentLottery + aux), users[currentLottery + aux].length-1, msg.sender);

        }else{
            revert("That Token is not accepted in this lottery");
        }

    }

    /**
    * @notice Invest the funds of the current lottery once two days have passed since the start
    * @dev Mint cDAI tokens for invest in Compound pools
    */
    function invest() external onlyOwner {
        require(lotteryInCourse, "There is no lottery in progress");
        require(block.timestamp > lotteries[currentLottery].initDate.add(172800), "Cannot invest yet");
        DAI.approve(address(cDAI), lotteries[currentLottery].funds);
        cDAI.mint(lotteries[currentLottery].funds);
        emit FundsInvested(cDAI.balanceOf(address(this)));
    }

    /**
    * @notice Choose a winner using a random number from chainlink and send the reward to the winner
    * @dev Recover the DAI investeds in Compound and the interest is the reward. The winner ticket is
    * between 1 and the amount of funds of the lottery. Transfer the interest to the winner and the fee
    * recipient and set LotteryInCourse control variable to false
    */
    function chooseWinner() external onlyOwner {
        require(lotteryInCourse, "There is no lottery in progress");
        require(block.timestamp > lotteries[currentLottery].initDate.add(604800), "Cannot choose a winner yet");
        User[] memory _users = users[currentLottery];
        Lottery memory _lottery = lotteries[currentLottery];
        uint256 totalFunds = cDAI.balanceOf(address(this));
        cDAI.redeem(totalFunds);
        uint256 newDAIBalance = DAI.balanceOf(address(this));
        uint256 interestEarned = newDAIBalance.sub(lotteries[currentLottery].funds);
        uint256 winnerTicket = random.randomResult().mod(_lottery.funds).add(1); // The winning ticket is between 1 and the number of funds
        uint256 lowerLimit = 1;
        uint256 upperLimit = _users[0].funds;
        address winner;
        for(uint256 i = 0; i < _users.length; i++){
            if(winnerTicket >= lowerLimit && winnerTicket <= upperLimit){
                winner = _users[i].addr;
                break;
            }
            upperLimit = upperLimit.add(_users[i].funds);
            lowerLimit = lowerLimit.add(_users[i].funds);
        }
        emit Winner((interestEarned*(100 - fee)/100), winnerTicket, winner);
        DAI.transferFrom(address(this), winner, interestEarned*(100 - fee)/100);
        DAI.transferFrom(address(this), feeRecipient, interestEarned*fee/100);
        lotteryInCourse = false;
    }
    
    /**
    * @notice Users can claim his tokens from past lotteries with this function
    * @dev Only the participant can claim the tokens and he claim exactly that he invest
    */
    function claimTokens(uint256 lotteryID, uint256 userID) external {
        require(lotteryID < currentLottery || (lotteryID == currentLottery && lotteryInCourse == false), "Invalid lottery");
        require(users[lotteryID][userID].addr == msg.sender, "Only the user can claim theirs tokens");
        DAI.transferFrom(address(this), msg.sender, users[lotteryID][userID].funds);
        emit TokensClaimed(users[lotteryID][userID].funds, lotteryID);
    }

    /**
    * @notice Update the recipient of the commissions
    * @dev Only the owner is able to change the recipient
    */
    function setRecipient(address _addr) external onlyOwner {
        feeRecipient = _addr;
    }

    /**
    * @notice Update the fee of the sales
    * @dev Only the owner is able to change the fee
    */
    function setFee(uint8 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
    * @notice Control function to manage the period of purchase for the current lottery
    * @dev Return a boolean depending on the time of the lottery. If two days has been
    * passed since the lottery start returns false, else return true
    */
    function _isPurchasePeriod() internal view returns(bool) {
        if(lotteries[currentLottery].initDate.add(172800) > block.timestamp){
            return true;
        }else{
            return false;
        }
    }

    // ========== GETTERS ========== //
    // Getters for testing
    
    function getLottery(uint lotteryID) external view returns(Lottery memory) {
        require(lotteryID <= currentLottery+1, "Invalid lottery ID");
        return lotteries[lotteryID];
    }

    function getUser(uint lotteryID, uint userID) external view returns(User memory){
        require(lotteryID <= currentLottery+1, "Invalid lottery ID");
        require(userID < users[lotteryID].length, "Invalid user ID");
        return users[lotteryID][userID];
    }
}