pragma solidity ^0.4.18;

contract PayrollInterface { 
    address owner;
    uint256 funds;
    uint256 nextId = 0;
    address[] public usedTokens;
    
    struct Employee {
      address employeeAddress;
      uint256 employeeId;
      uint256 yearlyEURSalary;
      uint256 paymentDue;
      uint256 lastPayDay;
      uint256 lastSetAllocations;
      address[] allowedTokens;
      mapping(address => uint256) tokenAllocation; 
    }
    Employee[] public employees;
    
    mapping(address => Employee) employeeByAddress;
    mapping(uint256 => Employee) employeeById;

    mapping(address => bool) isEmployee;
    mapping(address => uint256) index;

    modifier ownerOnly() { require(msg.sender == owner); _; }
    modifier employeeOnly() { require(isEmployee[msg.sender]); _; }
    modifier oracleOnly() { require(msg.sender == owner); _; }
    
    modifier sixMonthsFrom(uint _time) { require(_time == 0 || now - _time > 15780000); _; }
    modifier oneMonthFrom(uint _time) { require(now > _time); _; }

    /* OWNER ONLY */ 
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary)
      public
      ownerOnly
    {
      uint256 newId = nextId++;
      employees.push(Employee({
          employeeAddress: accountAddress,
          employeeId: newId,
          yearlyEURSalary: initialYearlyEURSalary,
          paymentDue: 0,
          lastPayDay: 0,
          lastSetAllocations: 0,
          allowedTokens: allowedTokens
        }));
      isEmployee[accountAddress] = true;
      index[accountAddress] = employees.length - 1;
    }

    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary)
      public
      ownerOnly
    {
      employeeById[employeeId].yearlyEURSalary = yearlyEURSalary;
    }
    
    function removeEmployee(uint256 employeeId)
      public
      ownerOnly
    {
      for (uint i = index[employeeById[employeeId].employeeAddress]; i < employees.length - 1; i ++) {
        employees[i] = employees[i+1];
      }
      delete(employees[employees.length - 1]);
      delete(isEmployee[employeeById[employeeId].employeeAddress]);
      delete(index[employeeById[employeeId].employeeAddress]);
      delete(employeeByAddress[employeeById[employeeId].employeeAddress]);
      delete(employeeById[employeeId]); 
    }
    
    function addFunds() 
      public 
      payable
      ownerOnly
    {
      funds += msg.value;
    }

    // function scapeHatch(); 
    // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback
    
    function getEmployeeCount() 
      public 
      ownerOnly
      constant returns (uint256) 
    {
      return employees.length;
    }
    
    // Return all important info too 
    // ^The signature given appears to call for returning 
    // an address, so I'm returning the address,
    // but this could be re-written to return an
    // Employee struct. 
    function getEmployee(uint256 employeeId) 
      public 
      ownerOnly
      constant returns (address employee) 
    {
      return employeeById[employeeId].employeeAddress;
    }
    
    // Monthly EUR amount spent in salaries 
    function calculatePayrollBurnrate() 
      public
      ownerOnly
      constant returns (uint256) 
    {
      uint256 totalAnnualSalaries = 0;
      for (uint i = 0; i < employees.length; i++){
        totalAnnualSalaries += employees[i].yearlyEURSalary; 
      }
      return totalAnnualSalaries/12;
    }

    // Days until the contract can run out of funds
    function calculatePayrollRunway()
      public
      ownerOnly
      constant returns (uint256)
    {
      uint256 dailyPayout = calculatePayrollBurnrate()/30; // assuming a 30 day month
      return funds/dailyPayout;
    }

    /* EMPLOYEE ONLY */

    // only callable once every 6 months
    function determineAllocation(address[] tokens, uint256[] distribution)
      public
      employeeOnly
      sixMonthsFrom(employeeByAddress[msg.sender].lastSetAllocations)
    {
      require(tokens.length == distribution.length);
      for (uint i = 0; i < tokens.length; i++) { 
        employeeByAddress[msg.sender].tokenAllocation[tokens[i]] = distribution[i]; 
      }
      employeeByAddress[msg.sender].lastSetAllocations = now;
    }

    //only callable once a month
    function payday()
      public
      employeeOnly
    {
      msg.sender.transfer(employeeByAddress[msg.sender].paymentDue);
    }

    /* ORACLE ONLY */ 
    //function setExchangeRate(address token, uint256 EURExchangeRate); // uses decimals from token 
}