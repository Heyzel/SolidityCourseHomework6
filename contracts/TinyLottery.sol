// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./RandomNumberConsumer.sol";
import "./ComptrollerInterface.sol";
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

    RandomNumberConsumer random;

    ComptrollerInterface comptroller;

    /**
    * Network: Mainnet
    * Address: 
    */
    CTokenInterface cDAI;

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
        address _comptroller,
        address _randomConsumer
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
        comptroller = ComptrollerInterface(_comptroller);
        random = RandomNumberConsumer(_randomConsumer);
    }

    function createLottery() external onlyOwner {
        require(!lotteryInCourse, "There is a lottery in progress");
        Lottery memory newLottery;
        newLottery.initDate = block.timestamp;
        lotteries.push(newLottery);
        currentLottery = currentLottery.add(1);
        lotteryInCourse = true;
    }

    function buyTickets(string memory _crypto) external {
        require(lotteryInCourse, "There is no lottery in progress");
        uint256 funds;
        User memory newUser;
        if(_isPurchasePeriod()){
            if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("DAI"))){
                funds = DAI.allowance(msg.sender, address(this));
                DAI.transferFrom(msg.sender, address(this), funds);
                newUser.addr = msg.sender;
                newUser.funds = funds;
                users[currentLottery].push(newUser);
                lotteries[currentLottery].funds = lotteries[currentLottery].funds.add(funds);
                
            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDC"))){
                // swap()

                
            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDT"))){
                // swap()


            }else{
                revert("That Token is not accepted in this lottery");
            }
        }else{
             if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("DAI"))){
                funds = DAI.allowance(msg.sender, address(this));
                DAI.transferFrom(msg.sender, address(this), funds);
                newUser.addr = msg.sender;
                newUser.funds = funds;
                users[currentLottery+1].push(newUser);
                lotteries[currentLottery+1].funds = lotteries[currentLottery+1].funds.add(funds);

            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDC"))){
                // swap()


            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDT"))){
                // swap()


            }else{
                revert("That Token is not accepted in this lottery");
            }
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
        DAI.transferFrom(address(this), winner, interestEarned*(100 - fee)/100);
        DAI.transferFrom(address(this), feeRecipient, interestEarned*fee/100);

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