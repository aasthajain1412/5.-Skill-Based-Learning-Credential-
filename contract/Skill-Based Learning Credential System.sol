// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Skill-Based Learning Credential System
 * @author Blockchain Developer
 * @notice A decentralized platform for issuing, managing, and verifying skill-based learning credentials
 * @dev Implements a credential system using blockchain technology for transparency and immutability
 */
contract SkillCredentialSystem {
    
    // Struct to represent a skill credential
    struct Credential {
        uint256 id;
        address learner;
        address issuer;
        string skillName;
        string description;
        uint8 proficiencyLevel; // 1-5 scale (1=Beginner, 5=Expert)
        uint256 issueDate;
        uint256 expiryDate;
        bool isActive;
        string metadataHash; // IPFS hash for additional credential data
    }
    
    // Struct to represent authorized issuers
    struct Issuer {
        address issuerAddress;
        string name;
        string organization;
        bool isVerified;
        uint256 credentialsIssued;
        uint256 registrationDate;
    }
    
    // State variables
    mapping(uint256 => Credential) public credentials;
    mapping(address => Issuer) public issuers;
    mapping(address => uint256[]) public learnerCredentials;
    mapping(address => bool) public authorizedIssuers;
    
    uint256 private credentialCounter;
    address public owner;
    
    // Events
    event CredentialIssued(
        uint256 indexed credentialId,
        address indexed learner,
        address indexed issuer,
        string skillName,
        uint8 proficiencyLevel
    );
    
    event IssuerRegistered(
        address indexed issuer,
        string name,
        string organization
    );
    
    event CredentialRevoked(
        uint256 indexed credentialId,
        address indexed issuer,
        string reason
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }
    
    modifier onlyAuthorizedIssuer() {
        require(authorizedIssuers[msg.sender], "Only authorized issuers can perform this action");
        _;
    }
    
    modifier credentialExists(uint256 _credentialId) {
        require(_credentialId > 0 && _credentialId <= credentialCounter, "Credential does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        credentialCounter = 0;
    }
    
    /**
     * @notice CORE FUNCTION 1: Issue a new skill credential to a learner
     * @param _learner Address of the learner receiving the credential
     * @param _skillName Name of the skill being certified
     * @param _description Detailed description of the skill and achievement
     * @param _proficiencyLevel Skill proficiency level (1-5)
     * @param _validityPeriod Validity period in seconds (0 for permanent)
     * @param _metadataHash IPFS hash containing additional credential metadata
     * @return credentialId The unique identifier of the issued credential
     */
    function issueCredential(
        address _learner,
        string memory _skillName,
        string memory _description,
        uint8 _proficiencyLevel,
        uint256 _validityPeriod,
        string memory _metadataHash
    ) public onlyAuthorizedIssuer returns (uint256) {
        require(_learner != address(0), "Invalid learner address");
        require(bytes(_skillName).length > 0, "Skill name cannot be empty");
        require(_proficiencyLevel >= 1 && _proficiencyLevel <= 5, "Proficiency level must be between 1-5");
        
        credentialCounter++;
        uint256 newCredentialId = credentialCounter;
        
        uint256 expiryDate = _validityPeriod == 0 ? 0 : block.timestamp + _validityPeriod;
        
        credentials[newCredentialId] = Credential({
            id: newCredentialId,
            learner: _learner,
            issuer: msg.sender,
            skillName: _skillName,
            description: _description,
            proficiencyLevel: _proficiencyLevel,
            issueDate: block.timestamp,
            expiryDate: expiryDate,
            isActive: true,
            metadataHash: _metadataHash
        });
        
        learnerCredentials[_learner].push(newCredentialId);
        issuers[msg.sender].credentialsIssued++;
        
        emit CredentialIssued(newCredentialId, _learner, msg.sender, _skillName, _proficiencyLevel);
        
        return newCredentialId;
    }
    
    /**
     * @notice CORE FUNCTION 2: Verify the authenticity and validity of a credential
     * @param _credentialId The unique identifier of the credential to verify
     * @return isValid Boolean indicating if the credential is valid
     * @return credential The complete credential information
     * @return issuerInfo Information about the credential issuer
     */
    function verifyCredential(uint256 _credentialId) 
        public 
        view 
        credentialExists(_credentialId)
        returns (
            bool isValid,
            Credential memory credential,
            Issuer memory issuerInfo
        ) 
    {
        credential = credentials[_credentialId];
        issuerInfo = issuers[credential.issuer];
        
        // Check if credential is valid
        bool isNotExpired = (credential.expiryDate == 0) || (block.timestamp <= credential.expiryDate);
        bool issuerStillAuthorized = authorizedIssuers[credential.issuer];
        
        isValid = credential.isActive && 
                 isNotExpired && 
                 issuerStillAuthorized && 
                 issuerInfo.isVerified;
        
        return (isValid, credential, issuerInfo);
    }
    
    /**
     * @notice CORE FUNCTION 3: Register as an authorized credential issuer
     * @param _name Full name of the issuer
     * @param _organization Name of the issuing organization/institution
     * @dev This function allows educational institutions, training providers, etc. to register
     */
    function registerIssuer(
        string memory _name,
        string memory _organization
    ) public {
        require(bytes(_name).length > 0, "Issuer name cannot be empty");
        require(bytes(_organization).length > 0, "Organization name cannot be empty");
        require(!authorizedIssuers[msg.sender], "Address already registered as issuer");
        
        issuers[msg.sender] = Issuer({
            issuerAddress: msg.sender,
            name: _name,
            organization: _organization,
            isVerified: false, // Requires owner verification
            credentialsIssued: 0,
            registrationDate: block.timestamp
        });
        
        emit IssuerRegistered(msg.sender, _name, _organization);
    }
    
    // Additional utility functions
    
    /**
     * @notice Authorize an issuer to start issuing credentials (only owner)
     * @param _issuer Address of the issuer to authorize
     */
    function authorizeIssuer(address _issuer) public onlyOwner {
        require(issuers[_issuer].issuerAddress != address(0), "Issuer not registered");
        authorizedIssuers[_issuer] = true;
        issuers[_issuer].isVerified = true;
    }
    
    /**
     * @notice Revoke a credential (only by the original issuer)
     * @param _credentialId ID of the credential to revoke
     * @param _reason Reason for revocation
     */
    function revokeCredential(
        uint256 _credentialId,
        string memory _reason
    ) public credentialExists(_credentialId) {
        require(credentials[_credentialId].issuer == msg.sender, "Only original issuer can revoke");
        require(credentials[_credentialId].isActive, "Credential already inactive");
        
        credentials[_credentialId].isActive = false;
        
        emit CredentialRevoked(_credentialId, msg.sender, _reason);
    }
    
    /**
     * @notice Get all credentials for a specific learner
     * @param _learner Address of the learner
     * @return Array of credential IDs owned by the learner
     */
    function getLearnerCredentials(address _learner) 
        public 
        view 
        returns (uint256[] memory) 
    {
        return learnerCredentials[_learner];
    }
    
    /**
     * @notice Get total number of credentials issued
     * @return Total credential count
     */
    function getTotalCredentials() public view returns (uint256) {
        return credentialCounter;
    }
    
    /**
     * @notice Check if an address is an authorized issuer
     * @param _issuer Address to check
     * @return Boolean indicating authorization status
     */
    function isAuthorizedIssuer(address _issuer) public view returns (bool) {
        return authorizedIssuers[_issuer];
    }
}
