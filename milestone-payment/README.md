# Service Agreement Smart Contract

A Clarity smart contract for managing service agreements between providers and clients with built-in payment escrow, milestone tracking, and dispute resolution capabilities.

## Features

- Agreement creation with milestone-based deliverables
- Secure payment escrow
- Milestone completion tracking
- Payment release mechanism
- Dispute filing and resolution
- Agreement cancellation

## Core Components

### Agreement States
- Payment Pending (0): Initial state after agreement creation
- In Progress (1): Active state after payment is escrowed
- Completed (2): All milestones delivered and payment released
- Cancelled (3): Agreement terminated before completion
- Disputed (4): Under dispute resolution

### Data Structures
- `agreement-records`: Stores agreement details and milestones
- `payment-escrow-records`: Manages escrowed payments
- `dispute-records`: Tracks dispute information and resolutions

## Key Functions

### For Customers
- `create-agreement`: Initialize new service agreement
- `submit-payment`: Escrow payment for services
- `release-payment`: Release payment after completion
- `cancel-agreement`: Cancel agreement in payment-pending state

### For Service Providers
- `complete-milestone`: Mark individual milestones as completed

### For Both Parties
- `file-dispute`: Initiate dispute resolution process

### For Contract Owner
- `resolve-dispute`: Resolve disputes and distribute funds

## Usage Flow

1. Customer creates agreement with milestones
2. Customer submits payment to escrow
3. Provider completes milestones
4. Customer releases payment or files dispute
5. If disputed, contract owner resolves and distributes funds

## Security Features

- Authorized party verification
- State transition validation
- Payment amount validation
- Milestone structure verification
- Provider eligibility checks
- Dispute deadline enforcement

## Technical Requirements

- Clarity smart contract language
- Stacks blockchain
- STX token for payments

## Implementation Details

### Milestone Structure
- Fixed 5 milestones per agreement
- Each milestone requires:
  - Title (UTF-8 string, max 100 chars)
  - Cost (in STX)
  - Completion status (boolean)
- Total milestone costs must equal total agreement price

### Error Handling
- `ERROR_ACCESS_DENIED` (100): Unauthorized access attempt
- `ERROR_INVALID_AGREEMENT_STATE` (101): Invalid state transition
- `ERROR_PAYMENT_TOO_LOW` (102): Payment below required amount
- `ERROR_DUPLICATE_AGREEMENT` (103): Agreement ID already exists
- `ERROR_AGREEMENT_MISSING` (104): Agreement not found
- `ERROR_INVALID_MILESTONE_NUMBER` (105): Invalid milestone index
- `ERROR_INVALID_PARAMETERS` (106): Invalid function parameters
- `ERROR_INVALID_PROVIDER_ADDRESS` (107): Invalid provider address
- `ERROR_INVALID_MILESTONE_STRUCTURE` (108): Malformed milestone data

### Timeframes and Deadlines
- Agreement duration specified in blocks
- Dispute deadline: Agreement end + 144 blocks (~24 hours)
- Payments locked until completion or dispute resolution

## Best Practices

### For Customers
1. Verify provider address before agreement creation
2. Submit full payment amount in single transaction
3. Review milestone completion before payment release
4. File disputes before deadline if issues arise

### For Providers
1. Set realistic milestone deliverables
2. Mark milestones as complete promptly
3. Maintain clear communication during disputes
4. Ensure all milestone titles are descriptive

### For Contract Owners
1. Review dispute evidence thoroughly
2. Provide detailed resolution text
3. Set fair refund percentages in disputes
4. Monitor agreement state transitions

## Testing and Deployment

1. Test all state transitions
2. Verify error handling
3. Test payment calculations
4. Validate milestone tracking
5. Check dispute resolution flows

## Security Considerations

1. Funds remain locked until explicit release
2. Only authorized parties can modify agreement state
3. Dispute resolution limited to contract owner
4. Payment validation before state transitions
5. Protected milestone completion verification

## Integration Guide

### Contract Interaction
```clarity
;; Create new agreement
(contract-call? .service-agreement create-agreement 
    u1                  ;; agreement-id
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; provider
    u1000000           ;; total price (1 STX)
    u144               ;; duration (24 hours)
    milestones)        ;; milestone list

;; Submit payment
(contract-call? .service-agreement submit-payment 
    u1                  ;; agreement-id
    u1000000)          ;; payment amount
```

### Milestone Structure Example
```clarity
(define-data-var milestones (list 5 {
    milestone-title: (string-utf8 100),
    milestone-cost: uint,
    milestone-status: bool
}) {
    {milestone-title: "Requirements", milestone-cost: u200000, milestone-status: false},
    {milestone-title: "Design", milestone-cost: u200000, milestone-status: false},
    {milestone-title: "Development", milestone-cost: u300000, milestone-status: false},
    {milestone-title: "Testing", milestone-cost: u200000, milestone-status: false},
    {milestone-title: "Deployment", milestone-cost: u100000, milestone-status: false}
})
```

## Monitoring and Events

### Key States to Monitor
- Payment submission
- Milestone completion
- Dispute filing
- Resolution outcomes

### Read-Only Functions
```clarity
;; Get agreement details
(contract-call? .service-agreement get-agreement-record u1)

;; Check escrow balance
(contract-call? .service-agreement get-escrow-balance u1)

;; View dispute details
(contract-call? .service-agreement get-dispute-record u1)
```

## Common Issues and Solutions

### Payment Issues
- Verify STX balance before submission
- Check agreement state before payment
- Monitor transaction confirmation

### Milestone Tracking
- Maintain local milestone status copy
- Verify completion in sequence
- Monitor block confirmations

### Dispute Resolution
- Document evidence thoroughly
- Submit disputes before deadline
- Keep communication records