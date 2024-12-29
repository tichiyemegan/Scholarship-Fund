# Scholarship Fund Smart Contract

## Overview

The Scholarship Fund Smart Contract is a transparent and decentralized application for managing donations and scholarships. It ensures funds are used responsibly and provides a mechanism for awarding scholarships to deserving scholars.

This project includes:
1. A smart contract written in Clarity for the Stacks blockchain.
2. A set of unit tests implemented using Vitest to ensure contract functionality.

---

## Features

### Contract Features:
1. **Donate Funds**: Users can donate STX tokens to the fund.
2. **Award Scholarships**: The contract owner can allocate funds to scholars.
3. **Track Contributions**: Donor contributions are recorded and can be queried.
4. **Scholar Information**: Details of awarded scholarships are stored and accessible.
5. **Read Total Funds**: Retrieve the total amount of STX tokens in the fund.

### Key Benefits:
- Transparent tracking of donations and scholarships.
- Controlled access for awarding scholarships (only contract owner).
- Error handling for insufficient funds or unauthorized actions.

---

## Contract Details

### Constants:
- **`contract-owner`**: The address that deployed the contract, with exclusive rights to award scholarships.
- **Errors**:
  - `err-owner-only (u100)`: Raised when a non-owner tries to award scholarships.
  - `err-insufficient-funds (u101)`: Raised when trying to award more funds than available.

### Data Variables:
- **`total-funds`**: Tracks the total funds available in the contract.

### Data Maps:
- **`donors`**: Maps donor addresses to the amounts they contributed.
- **`scholars`**: Maps scholar addresses to their awarded amounts and status.

### Public Functions:
1. **`donate-funds`**: Donate STX tokens to the scholarship fund.
2. **`award-scholarship`**: Allocate a specific amount to a scholar (owner-only).

### Read-Only Functions:
1. **`get-total-funds`**: Returns the current total funds in the contract.
2. **`get-donor-contribution`**: Retrieves the amount donated by a specific address.
3. **`get-scholar-info`**: Retrieves information about a specific scholar.

---

## Unit Tests

Unit tests are implemented using Vitest to validate the functionality of the contract in a simulated environment.

### Test Summary:
1. **Donation Functionality**:
   - Donations increase the total funds.
   - Contributions are tracked correctly by donor.
2. **Scholarship Allocation**:
   - Scholarships can only be awarded by the contract owner.
   - Funds are deducted from the total after a scholarship is awarded.
   - Error handling for insufficient funds or unauthorized actions.
3. **Data Retrieval**:
   - Accurate retrieval of donor contributions.
   - Scholar information is stored and accessible.

### Commands to Run Tests:
To run the tests, ensure you have Node.js and Vitest installed. Use the following commands:

```bash
# Install dependencies
npm install

# Run tests
npm test
