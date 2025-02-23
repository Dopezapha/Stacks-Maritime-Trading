# Maritime Trading Platform

A decentralized maritime trading platform built on Stacks blockchain, enabling secure vessel registration, trade agreements, customs compliance, and GPS tracking.

## Overview

The platform consists of four main smart contracts that work together to facilitate maritime trading operations:

1. `Clarity-Maritime-Trading.clar`: Core trading functionality and vessel registration
2. `Stacks-Customs-Compliance.clar`: Customs documentation and compliance verification
3. `Stacks-Oracle.clar`: GPS tracking and geofencing capabilities
4. `maritime-trade-trait.clar`: Shared trait interface for contract interoperability

## Features

- Vessel registration and ownership management
- Trade agreement creation and management
- Customs documentation submission and verification
- Real-time GPS tracking with geofencing
- Port compliance verification
- Multi-party authorization system

## Contract Dependencies

```
maritime-trade-trait.clar
         ↑
         |
Clarity-Maritime-Trading.clar ← Stacks-Customs-Compliance.clar
         ↑
         |
    Stacks-Oracle.clar
```

## Core Components

### Maritime Trading Contract
- Vessel registration and management
- Trade agreement creation
- Position updates
- Ownership registry

### Customs Compliance Contract
- Document submission and verification
- Port requirement management
- Trade compliance verification
- Support for multiple document types:
  - Bill of Lading
  - Cargo Manifest
  - Customs Declaration

### GPS Oracle Contract
- Vessel position tracking
- Geofence creation and management
- Position verification
- Oracle authorization system

## Key Data Structures

### Vessel Registration
```clarity
{
    vessel-identifier: string-utf8,
    vessel-owner: principal,
    vessel-registration: string-utf8,
    vessel-category: string-utf8,
    cargo-capacity: uint,
    vessel-position: {latitude: int, longitude: int},
    operational-status: bool
}
```

### Trade Contracts
```clarity
{
    trade-identifier: string-utf8,
    selling-party: principal,
    buying-party: principal,
    cargo-category: string-utf8,
    cargo-quantity: uint,
    contract-price: uint,
    contract-status: string-utf8,
    delivery-location: {latitude: int, longitude: int},
    customs-clearance: bool
}
```

## Usage Guidelines

### Vessel Registration
1. Administrator registers vessels using `register-maritime-vessel`
2. Requires valid vessel identifier, registration number, category, and cargo capacity
3. Vessel ownership is automatically recorded

### Creating Trade Agreements
1. Registered vessel owners can create trade contracts using `create-trade-contract`
2. Both parties must have registered vessels
3. Requires valid trade identifier, cargo details, and delivery coordinates

### Customs Documentation
1. Submit trade documents using `submit-trade-document`
2. Authorized verifiers can verify documents using `verify-trade-document`
3. Port requirements must be configured by administrator

### GPS Tracking
1. Authorized oracles update vessel positions using `update-vessel-position`
2. Geofence zones can be created for ports and restricted areas
3. Position updates are validated against coordinate ranges

## Error Handling

The platform implements comprehensive error checking:
- Input validation for all parameters
- Authorization checks for administrative actions
- Duplicate entry prevention
- Coordinate range validation
- Document verification status checks

## Security Considerations

1. Administrative Functions
   - Limited to contract administrator
   - Protected by principal checks

2. Document Verification
   - Only authorized verifiers can approve documents
   - Multi-stage verification process
   - Tamper-evident document hashing

3. GPS Oracle
   - Authorized oracle system
   - Coordinate validation
   - Geofence enforcement

## Development Notes

### Coordinate System
- Coordinates are stored as integers multiplied by 1,000,000
- Latitude range: -90,000,000 to 90,000,000
- Longitude range: -180,000,000 to 180,000,000

### String Limitations
- Vessel Identifier: max 36 characters
- Registration Number: max 50 characters
- Vessel Category: max 20 characters
- Cargo Category: max 50 characters