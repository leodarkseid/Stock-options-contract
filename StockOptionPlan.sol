// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @title EmployeeStockOptionPlan
 * @dev A contract for managing stock option grants and vesting schedules for employees.
 */

contract EmployeeStockOptionPlan is Ownable, ReentrancyGuard {

    uint256 constant INFINITY = 2**256 - 1;

    struct Employee {
        uint256 stockOptions;
        uint256 vestingSchedule;
    } 
    mapping(address => Employee) public employee;
    mapping(address => uint256) private excercisedBalance;
    mapping(address => uint256) private vestingBalance;




    /**
     * @dev Grants stock options to an employee.
     * @param _employeeAddress The address of the employee.
     * @param _stockOptions The number of stock options to grant.
     */

    function grantStockOptions(address _employeeAddress, uint256 _stockOptions) public onlyOwner nonReentrant {
        require(_employeeAddress != address(0) , "Invalid employee address");

        if (employee[_employeeAddress].stockOptions > 0) {_vest(_employeeAddress);}
        employee[_employeeAddress].stockOptions += _stockOptions;
        if (employee[_employeeAddress].vestingSchedule == 0){employee[_employeeAddress].vestingSchedule = INFINITY;}

        emit StockOptionsGranted(_employeeAddress, _stockOptions);
    }

    /**
     * @dev Sets the vesting schedule for an employee.
     * @param _employeeAddress The address of the employee.
     * @param _vestingSchedule The timestamp representing the vesting schedule.
     * @notice The vesting schedule must be in the future.
     * @notice To set the desired time correctly, just call getBlockTimeStamp() to get the current block timestamp and add how long you want it to vest for
     */

    function setVestingSchedule(address _employeeAddress, uint256 _vestingSchedule) public onlyOwner nonReentrant{
        require(_vestingSchedule > block.timestamp, "vesting schedule must be in the future");
        require(employee[_employeeAddress].stockOptions > 0,"Employee doesn't exist");

        if (employee[_employeeAddress].stockOptions > 0 && block.timestamp > employee[_employeeAddress].vestingSchedule) {_vest(_employeeAddress);}
        employee[_employeeAddress].vestingSchedule = _vestingSchedule;
        }

    /**
     * @dev Gets the current block timestamp.
     * @return The current block timestamp.
     */
    function getBlockTimeStamp() public view returns(uint256){
        return block.timestamp;
    }

    /**
     * @dev Calculates the remaining time until vesting for an employee.
     * @param _employeeAddress The address of the employee.
     * @return The remaining time until vesting in seconds.
     */

    function vestingCountdown(address _employeeAddress)public view returns(uint256){
        require(isEmployee() == true || msg.sender == owner(), "You are not an employee");
        require(employee[_employeeAddress].stockOptions > 0,"Employee doesn't exist");
        return (employee[_employeeAddress].vestingSchedule - block.timestamp) > 0 ?
        (employee[_employeeAddress].vestingSchedule - block.timestamp):0
        ;
    }

    /**
     * @dev This helps verifiy if msg.sender is an employee
     */

    function isEmployee() internal view returns(bool){
        return(employee[msg.sender].stockOptions > 0 || vestingBalance[msg.sender] > 0 || excercisedBalance[msg.sender] > 0) ? true: false;
    }

   
    /**
     * @dev Performs the vesting process for an employee.
     * @param _employeeAddress The address of the employee.
     */

    function _vest(address _employeeAddress) internal {
        if (block.timestamp > employee[_employeeAddress].vestingSchedule){
            vestingBalance[_employeeAddress] += employee[_employeeAddress].stockOptions;
            employee[msg.sender].stockOptions -= employee[_employeeAddress].stockOptions;
            employee[msg.sender].vestingSchedule -= employee[_employeeAddress].vestingSchedule;
        }
    }

    /**
     * @dev Performs the vesting process for the calling employee.
     */

    function vestOptions() public nonReentrant{
        require(isEmployee() == true, "You are not an employee or you do not have stock options");
        require(employee[msg.sender].vestingSchedule != INFINITY, "Vesting schedule is yet to be set");
        _vest(msg.sender);
    }

    /**
     * @dev Exercises vested stock options for the calling employee.
     */

    function exerciseOptions() public nonReentrant{
        require(isEmployee() == true, "You are not an employee or you do not have stock options");

        excercisedBalance[msg.sender] += vestingBalance[msg.sender];
        vestingBalance[msg.sender] -= vestingBalance[msg.sender];
        emit stockOptionsExcercised(msg.sender);
    }

    /**
     * @dev Gets the number of vested options for an employee.
     * @param _employeeAddress The address of the employee.
     * @return The number of vested options.
     */

    function getVestedOptions(address _employeeAddress) public view returns(uint256){
        require(isEmployee() == true || msg.sender == owner(), "You are not an employee");
        return vestingBalance[_employeeAddress];
    }

     /**
     * @dev Gets the number of exercised options for an employee.
     * @param _employeeAddress The address of the employee.
     * @return The number of exercised options.
     */

    function getExcercisedOptions(address _employeeAddress) public view returns(uint256){
        require(isEmployee() == true || msg.sender == owner(), "You are not an employee");
        return excercisedBalance[_employeeAddress];
    }

    /**
     * @dev Transfers vested stock options from the calling employee to a recipient.
     * @param _recipient The address of the recipient.
     * @param _stockOptionsAmount The number of stock options to transfer.
     */


    function transferOptions(address _recipient, uint256 _stockOptionsAmount)public nonReentrant {
        require(_stockOptionsAmount > 0, "stock options must be greater than zero");
        require(isEmployee() == true, "You are not an employee");
        require(employee[_recipient].stockOptions > 0 || vestingBalance[_recipient] > 0, "Employee does not exist");
        require(_stockOptionsAmount <= vestingBalance[msg.sender], "Employee has insufficient vesting balance");

        if (employee[msg.sender].stockOptions > 0) {_vest(msg.sender);}

        vestingBalance[msg.sender] -= _stockOptionsAmount;
        vestingBalance[_recipient] += _stockOptionsAmount;

        emit StockOptionsGranted(_recipient, _stockOptionsAmount);
    }

    event StockOptionsGranted(address employee, uint256 stockOptionsAmount);
    event StockOptionsTransferred(address recpient, uint256 stockOptionAmount);
    event stockOptionsExcercised(address recipient);

}
