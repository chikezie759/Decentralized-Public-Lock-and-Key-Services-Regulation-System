# Decentralized Public Lock and Key Services Regulation System

A comprehensive blockchain-based system for regulating locksmith services, key cutting operations, security clearances, emergency services, and specialized safe/vault services.

## System Overview

This decentralized regulation system consists of five interconnected smart contracts that manage different aspects of locksmith service regulation:

### 1. Locksmith Licensing Contract (`locksmith-licensing.clar`)
- Issues and manages permits for residential and commercial locksmith services
- Tracks license status, expiration dates, and renewal requirements
- Maintains a registry of certified locksmiths with their specializations

### 2. Key Cutting Certification Contract (`key-cutting-certification.clar`)
- Manages licenses for key duplication and lock installation services
- Tracks certification levels and authorized key types
- Maintains equipment certification records

### 3. Security Clearance Verification Contract (`security-clearance.clar`)
- Ensures locksmiths working on government facilities have proper clearances
- Manages different clearance levels and access permissions
- Tracks clearance expiration and renewal status

### 4. Emergency Lockout Service Contract (`emergency-lockout.clar`)
- Coordinates 24/7 locksmith services for emergencies
- Manages service provider availability and response times
- Tracks emergency service completion and customer satisfaction

### 5. Safe and Vault Service Oversight Contract (`safe-vault-oversight.clar`)
- Regulates specialized services for safes and security equipment
- Manages high-security service certifications
- Tracks specialized equipment and training requirements

## Key Features

- **Decentralized Governance**: No single point of failure or control
- **Transparent Operations**: All licensing and certification data on-chain
- **Automated Compliance**: Smart contract enforcement of regulations
- **Real-time Verification**: Instant verification of credentials and certifications
- **Audit Trail**: Complete history of all regulatory actions

## Contract Architecture

Each contract operates independently while maintaining data consistency through standardized interfaces. The system supports:

- Multi-level licensing (Basic, Advanced, Master)
- Geographic service area management
- Automated license renewal reminders
- Violation tracking and penalty enforcement
- Performance metrics and ratings

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js 18+ for testing
- Stacks wallet for contract deployment

### Installation
\`\`\`bash
npm install
clarinet check
clarinet test
\`\`\`

### Testing
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Usage Examples

### Register a New Locksmith
\`\`\`clarity
(contract-call? .locksmith-licensing register-locksmith
"John Smith"
"Residential"
"123 Main St, City, State")
\`\`\`

### Verify Security Clearance
\`\`\`clarity
(contract-call? .security-clearance verify-clearance
'SP1234567890
"SECRET")
\`\`\`

### Request Emergency Service
\`\`\`clarity
(contract-call? .emergency-lockout request-emergency-service
"Locked out of apartment"
"456 Oak Ave, City, State")
\`\`\`

## Governance

The system includes built-in governance mechanisms for:
- Updating regulatory requirements
- Adjusting fee structures
- Managing contract upgrades
- Handling dispute resolution

## Security Considerations

- All sensitive data is encrypted before storage
- Multi-signature requirements for administrative functions
- Regular security audits and updates
- Compliance with data protection regulations

## Contributing

Please read our contributing guidelines and submit pull requests for any improvements.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
