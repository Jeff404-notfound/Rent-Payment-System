// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RentPaymentSystem {
    struct RentalAgreement {
        address landlord;
        address tenant;
        uint256 monthlyRent;
        uint256 securityDeposit;
        uint256 agreementStartTime;
        uint256 lastPaymentTime;
        bool isActive;
        bool depositReturned;
    }
    
    mapping(uint256 => RentalAgreement) public agreements;
    mapping(address => uint256[]) public landlordAgreements;
    mapping(address => uint256[]) public tenantAgreements;
    
    uint256 public agreementCounter;
    uint256 public constant LATE_FEE_PERCENTAGE = 5; // 5% late fee
    uint256 public constant GRACE_PERIOD = 5 days;
    
    event AgreementCreated(uint256 indexed agreementId, address indexed landlord, address indexed tenant);
    event RentPaid(uint256 indexed agreementId, uint256 amount, uint256 timestamp);
    event DepositReturned(uint256 indexed agreementId, uint256 amount);
    event AgreementTerminated(uint256 indexed agreementId);
    
    modifier onlyLandlord(uint256 _agreementId) {
        require(agreements[_agreementId].landlord == msg.sender, "Only landlord can perform this action");
        _;
    }
    
    modifier onlyTenant(uint256 _agreementId) {
        require(agreements[_agreementId].tenant == msg.sender, "Only tenant can perform this action");
        _;
    }
    
    modifier agreementActive(uint256 _agreementId) {
        require(agreements[_agreementId].isActive, "Agreement is not active");
        _;
    }
    
    /**
     * @dev Creates a new rental agreement between landlord and tenant
     * @param _tenant Address of the tenant
     * @param _monthlyRent Monthly rent amount in wei
     * @param _securityDeposit Security deposit amount in wei
     */
    function createAgreement(
        address _tenant,
        uint256 _monthlyRent,
        uint256 _securityDeposit
    ) external payable {
        require(_tenant != address(0), "Invalid tenant address");
        require(_monthlyRent > 0, "Rent must be greater than zero");
        require(_securityDeposit > 0, "Security deposit must be greater than zero");
        require(msg.value == _securityDeposit, "Must send security deposit amount");
        
        uint256 agreementId = agreementCounter++;
        
        agreements[agreementId] = RentalAgreement({
            landlord: msg.sender,
            tenant: _tenant,
            monthlyRent: _monthlyRent,
            securityDeposit: _securityDeposit,
            agreementStartTime: block.timestamp,
            lastPaymentTime: block.timestamp,
            isActive: true,
            depositReturned: false
        });
        
        landlordAgreements[msg.sender].push(agreementId);
        tenantAgreements[_tenant].push(agreementId);
        
        emit AgreementCreated(agreementId, msg.sender, _tenant);
    }
    
    /**
     * @dev Allows tenant to pay monthly rent
     * @param _agreementId ID of the rental agreement
     */
    function payRent(uint256 _agreementId) external payable onlyTenant(_agreementId) agreementActive(_agreementId) {
        RentalAgreement storage agreement = agreements[_agreementId];
        
        uint256 rentDue = agreement.monthlyRent;
        uint256 daysSinceLastPayment = (block.timestamp - agreement.lastPaymentTime) / 1 days;
        
        // Check if payment is late and apply late fee
        if (daysSinceLastPayment > 30 + (GRACE_PERIOD / 1 days)) {
            uint256 lateFee = (rentDue * LATE_FEE_PERCENTAGE) / 100;
            rentDue += lateFee;
        }
        
        require(msg.value >= rentDue, "Insufficient payment amount");
        
        // Transfer rent to landlord
        payable(agreement.landlord).transfer(rentDue);
        
        // Return excess payment if any
        if (msg.value > rentDue) {
            payable(msg.sender).transfer(msg.value - rentDue);
        }
        
        agreement.lastPaymentTime = block.timestamp;
        
        emit RentPaid(_agreementId, rentDue, block.timestamp);
    }
    
    /**
     * @dev Terminates rental agreement and handles security deposit return
     * @param _agreementId ID of the rental agreement
     * @param _returnDeposit Whether to return the security deposit to tenant
     */
    function terminateAgreement(uint256 _agreementId, bool _returnDeposit) 
        external 
        onlyLandlord(_agreementId) 
        agreementActive(_agreementId) 
    {
        RentalAgreement storage agreement = agreements[_agreementId];
        
        agreement.isActive = false;
        
        if (_returnDeposit && !agreement.depositReturned) {
            agreement.depositReturned = true;
            payable(agreement.tenant).transfer(agreement.securityDeposit);
            emit DepositReturned(_agreementId, agreement.securityDeposit);
        }
        
        emit AgreementTerminated(_agreementId);
    }
    
    // View functions
    function getAgreementDetails(uint256 _agreementId) external view returns (
        address landlord,
        address tenant,
        uint256 monthlyRent,
        uint256 securityDeposit,
        uint256 agreementStartTime,
        uint256 lastPaymentTime,
        bool isActive,
        bool depositReturned
    ) {
        RentalAgreement memory agreement = agreements[_agreementId];
        return (
            agreement.landlord,
            agreement.tenant,
            agreement.monthlyRent,
            agreement.securityDeposit,
            agreement.agreementStartTime,
            agreement.lastPaymentTime,
            agreement.isActive,
            agreement.depositReturned
        );
    }
    
    function getLandlordAgreements(address _landlord) external view returns (uint256[] memory) {
        return landlordAgreements[_landlord];
    }
    
    function getTenantAgreements(address _tenant) external view returns (uint256[] memory) {
        return tenantAgreements[_tenant];
    }
    
    function calculateRentDue(uint256 _agreementId) external view returns (uint256) {
        RentalAgreement memory agreement = agreements[_agreementId];
        require(agreement.isActive, "Agreement is not active");
        
        uint256 rentDue = agreement.monthlyRent;
        uint256 daysSinceLastPayment = (block.timestamp - agreement.lastPaymentTime) / 1 days;
        
        // Add late fee if applicable
        if (daysSinceLastPayment > 30 + (GRACE_PERIOD / 1 days)) {
            uint256 lateFee = (rentDue * LATE_FEE_PERCENTAGE) / 100;
            rentDue += lateFee;
        }
        
        return rentDue;
    }
}
