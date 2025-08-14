# FlowSwap

A decentralized exchange (DEX) protocol built on Stacks blockchain that enables seamless token swapping between STX and alternative currencies through automated market making.

## Overview

FlowSwap is an AMM-based DEX that allows users to:
- Swap STX for alternative tokens and vice versa
- Provide liquidity to earn trading fees
- Participate in decentralized finance on the Stacks ecosystem

The protocol uses a constant product formula (x * y = k) with a 0.3% trading fee distributed to liquidity providers.

## Key Features

### 🔄 Token Swapping
- Exchange STX for any supported SIP-010 token
- Exchange supported tokens back to STX
- Slippage protection with minimum output guarantees

### 💧 Liquidity Provision
- Add liquidity to earn trading fees
- Remove liquidity with proportional asset withdrawal
- LP shares represent pool ownership

### 📊 Transparent Pricing
- Real-time exchange rate calculations
- Fee-adjusted pricing (0.3% trading fee)
- No hidden costs or surprise charges

## Smart Contract Functions

### Public Functions

#### Pool Management
- `open-bank(currency-interface, stx-capital, alt-capital)` - Initialize a new trading pool
- `make-deposit(currency-interface, stx-deposit, alt-deposit, min-shares)` - Add liquidity
- `make-withdrawal(currency-interface, share-amount, min-stx, min-alt)` - Remove liquidity

#### Token Swapping
- `exchange-stx-for-alt(currency-interface, stx-amount, min-alt-output)` - Swap STX for tokens
- `exchange-alt-for-stx(currency-interface, alt-amount, min-stx-output)` - Swap tokens for STX

### Read-Only Functions

#### Pool Information
- `check-bank-reserves()` - View current pool reserves
- `check-outstanding-shares()` - View total LP shares
- `check-banking-status()` - Check if pool is active
- `check-customer-account(customer)` - View user's LP share balance

#### Price Calculations
- `calculate-exchange-output(input-sum, input-reserves, output-reserves)` - Calculate swap output
- `calculate-required-input(output-sum, input-reserves, output-reserves)` - Calculate required input
- `calculate-share-value(currency-amount, currency-reserves, paired-reserves)` - Calculate LP share value

## Getting Started

### Prerequisites
- Stacks wallet (Hiro Wallet, Xverse, etc.)
- STX tokens for transactions
- SIP-010 compatible tokens for trading

### Usage Example

1. **Create a Pool**
   ```clarity
   (contract-call? .flowswap open-bank 
     .my-token 
     u1000000  ;; 1 STX
     u2000000) ;; 2 tokens
   ```

2. **Swap STX for Tokens**
   ```clarity
   (contract-call? .flowswap exchange-stx-for-alt 
     .my-token 
     u100000   ;; 0.1 STX
     u150000)  ;; minimum tokens expected
   ```

3. **Add Liquidity**
   ```clarity
   (contract-call? .flowswap make-deposit 
     .my-token 
     u500000   ;; 0.5 STX
     u1000000  ;; 1 token
     u1)       ;; minimum shares
   ```

## Technical Details

### Trading Fee
- **0.3%** fee on all swaps
- Fees automatically added to pool reserves
- Benefits liquidity providers through increased pool value

### Price Formula
The protocol uses the constant product formula:
```
x * y = k
```
Where:
- `x` = STX reserves
- `y` = Alt token reserves  
- `k` = constant product

### Slippage Protection
All swap functions include slippage protection via minimum output parameters. Transactions will revert if the actual output falls below the specified minimum.

## Security Features

- **Access Controls**: Only authorized users can perform certain operations
- **Reserve Validation**: Prevents operations that would drain pool reserves
- **Input Validation**: All inputs are validated for correctness
- **Slippage Protection**: Built-in protection against unfavorable trades

## Error Codes

- `u600`: Access denied
- `u601`: Insufficient reserves
- `u602`: Invalid transaction
- `u603`: Rate unfavorable (slippage protection triggered)
- `u604`: Currency error (wrong token contract)
- `u605`: Processing failed
- `u606`: Pool already operational
- `u607`: Pool closed
