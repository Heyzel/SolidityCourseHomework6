// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./CurveInterface.sol";
import "./RandomNumberConsumer.sol";
import "./CTokenInterface.sol";

contract TinyLottery is OwnableUpgradeable {
    using SafeMath for uint256;

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
    * Pool: 3pool
    * Address: 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7
    */
    CurveInterface public swapper;

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

    // Receives `fee` of the total ETH used for swaps   
    address public feeRecipient;

    // fee charged, initialized in 0.1%
    uint16 public fee;

    uint256 public currentLottery;

    bool public lotteryInCourse;

    Lottery[] lotteries;
    mapping(uint256 => User[]) users;

    function initialize(
        address _feeRecipient, 
        uint16 _fee, 
        address _DAI, 
        address _USDC, 
        address _USDT,
        address _cDAI,
        address _randomConsumer,
        address _stableSwap
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
        swapper = CurveInterface(_stableSwap);
    }

    function createLottery() external onlyOwner {
        require(!lotteryInCourse, "There is a lottery in progress");
        Lottery memory newLottery;
        newLottery.initDate = block.timestamp;
        lotteries.push(newLottery);
        currentLottery = currentLottery.add(1);
        lotteryInCourse = true;
    }

    function buyTickets(string memory _crypto) external payable{
        require(lotteryInCourse, "There is no lottery in progress");
        uint256 funds;
        uint256 result;
        User memory newUser;
        uint aux;
        if(_isPurchasePeriod()){
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
        }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("ETH"))){
            require(msg.value > 0, "Insufficient ETH");
            uint amount; uint amountOut;
            ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH9,
                tokenOut: address(DAI),
                fee: 3000,
                recipient: msg.sender,
                deadline: block.timestamp + 1,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            amountOut = swapRouter.exactInputSingle{value: amount}(params);

            funds = amountOut.div(10**18).mul(10**18);
            if(amountOut.sub(funds) > 0){
                DAI.transferFrom(address(this), msg.sender, amountOut.sub(funds));
            }
            newUser.addr = msg.sender;
            newUser.funds = funds;
            users[currentLottery + aux].push(newUser);
            lotteries[currentLottery + aux].funds = lotteries[currentLottery + aux].funds.add(funds);

        }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDC"))){
            funds = USDC.allowance(msg.sender, address(this));
            require(funds > 0, "USDC Insufficient");
            funds = funds.div(10**18).mul(10**18);
            USDC.transferFrom(msg.sender, address(this), funds);
            result = swapper.get_dy_underlying(1, 0, funds);
            swapper.exchange_underlying(1, 0, funds, result);
            newUser.addr = msg.sender;
            newUser.funds = result.div(10**18).mul(10**18);
            users[currentLottery + aux].push(newUser);
            lotteries[currentLottery + aux].funds = lotteries[currentLottery + aux].funds.add(newUser.funds);
            
        }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDT"))){
            funds = USDT.allowance(msg.sender, address(this));
            require(funds > 0, "USDT Insufficient");
            funds = funds.div(10**18).mul(10**18);
            USDT.transferFrom(msg.sender, address(this), funds);
            result = swapper.get_dy_underlying(2, 0, funds);
            swapper.exchange_underlying(2, 0, funds, result);
            newUser.addr = msg.sender;
            newUser.funds = result.div(10**18).mul(10**18);
            users[currentLottery + aux].push(newUser);
            lotteries[currentLottery + aux].funds = lotteries[currentLottery + aux].funds.add(newUser.funds);

        }else{
            revert("That Token is not accepted in this lottery");
        }

    }

    function invest() external onlyOwner {
        require(lotteryInCourse, "There is no lottery in progress");
        require(block.timestamp > lotteries[currentLottery].initDate.add(172800), "Cannot invest yet");
        DAI.approve(address(cDAI), lotteries[currentLottery].funds);
        cDAI.mint(lotteries[currentLottery].funds);
    }

    function chooseWinner() external onlyOwner {
        require(lotteryInCourse, "There is no lottery in progress");
        require(block.timestamp > lotteries[currentLottery].initDate.add(604800), "Cannot choose a winner yet");
        User[] memory _users = users[currentLottery];
        Lottery memory _lottery = lotteries[currentLottery];
        uint256 totalFunds = cDAI.balanceOf(address(this));
        cDAI.redeem(totalFunds);
        uint256 interestEarned = totalFunds.sub(_lottery.funds);
        uint256 winnerTicket = random.randomResult().mod(_lottery.funds).add(1).div(10**18); // The winning ticket is between 1 and the number of funds
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
        DAI.transferFrom(address(this), winner, interestEarned*(100 - fee)/100);
        DAI.transferFrom(address(this), feeRecipient, interestEarned*fee/100);
        lotteryInCourse = false;
        currentLottery = currentLottery.add(1);
    }

    function claimTokens(uint256 lotteryID, uint256 userID) external {
        require(lotteryID < currentLottery, "Invalid lottery");
        require(users[lotteryID][userID].addr == msg.sender, "Only the user can claim theirs tokens");
        DAI.transferFrom(address(this), msg.sender, users[lotteryID][userID].funds);
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

    function _isPurchasePeriod() internal view returns(bool) {
        if(lotteries[currentLottery].initDate.add(172800) > block.timestamp){
            return true;
        }else{
            return false;
        }
    }
}