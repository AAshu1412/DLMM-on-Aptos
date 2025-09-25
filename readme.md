# **DLMM Protocol on Aptos**

This document provides an overview of a **Dynamic Liquidity Market Maker (DLMM)** protocol built on the **Aptos** blockchain. This protocol is designed to offer a more precise and capital-efficient environment for decentralized trading by structuring liquidity in **discrete bins**.

## **Overview**

A **Dynamic Liquidity Market Maker (DLMM)** is an advanced automated market maker (AMM) that moves beyond the traditional continuous liquidity curve. Instead of spreading liquidity across an infinite price range, a DLMM allows **liquidity providers (LPs)** to concentrate their assets into individual, discrete price "bins." Each bin represents a single, fixed price, enabling functionalities like **zero-slippage trades** within a bin and more strategic liquidity provision.

This implementation includes a full suite of functionalities, from pool creation and liquidity management to token swaps, all governed by a central factory contract.

## **Core Concepts**

The protocol is built around three main components:

1.  **Factory:** A singleton contract deployed by the administrator. It serves as a registry for all **liquidity pools** and is responsible for creating new pools.
2.  **Pool:** An individual contract that represents a trading pair (e.g., **TOKEN1/TOKEN2**). Each pool manages its own set of **liquidity bins**, reserves, and fees.
3.  **Bins:** The fundamental innovation of the DLMM. Each bin is tied to a specific price and holds the token reserves available for trading at that exact price. The current market price of a pool is determined by which bin is currently **active**.

---

## **How It Works: Core Functions**

This section details the primary user-facing functions of the protocol.

### 1. **Protocol Initialization**

#### **`initialize_factory`**
This is an **admin-only** function that must be called once to set up the protocol.

```rust
public entry fun initialize_factory(admin: &signer)
```
**Purpose**: Creates the central **Factory** resource, which will be used to create and track all liquidity pools.

**Parameters**:

- **admin**: &signer: The signer of the account that will own and manage the protocol.

**Process**:

1. Checks that a **Factory** has not already been initialized.
2. Creates a new **Factory** struct.
3. Stores the **Factory** as a resource under the admin's account.

2. **Pool Management**
**create_pool**
This function allows any user to create a new **liquidity pool** for a pair of tokens. This user becomes the first **liquidity provider**.

Rust
```rust
public entry fun create_pool(
    creator: &signer,
    token1_address: address,
    token2_address: address,
    initial_token1_amount: u64,
    initial_token2_amount: u64,
    bin_step: u16,
    fees: u64
)
```
**Purpose**: To create a new trading market for two distinct tokens.

**Parameters**:

- **creator**: &signer: The user creating the pool and providing the initial liquidity.
- **token1_address**, **token2_address**: The addresses of the two tokens in the pair.
- **initial_token1_amount**, **initial_token2_amount**: The amounts of each token to seed the pool with.
- **bin_step**: u16: A crucial parameter that defines the price gap between adjacent bins. A smaller step allows for finer price precision.

**Process**:

1. Validates that the tokens are different and initial amounts are greater than zero.
2. Checks with the **Factory** to ensure a pool for this pair and bin_step doesn't already exist.
3. Creates a new, unique account address to house the **Pool** resource.
4. Calculates an initial **active_bin_id** to serve as the starting market price.
5. Creates the first **Bin** and seeds it with the creator's initial token amounts.
6. Initializes the **Pool** resource and moves it to the newly created pool address.
7. Registers the new pool's address in the **Factory**.
8. Deducts the initial token amounts from the creator's balance.
9. Creates a **LiquidatorPosition** for the creator to track their share of the pool.

3. **Liquidity Provision**
**add_liquidity**
Allows users to add liquidity to an existing pool at a specific price point.

Rust
```rust
public entry fun add_liquidity(
    liquidator: &signer,
    token1_address: address,
    token2_address: address,
    bin_step: u16,
    token1_amount: u64,
    token2_amount: u64,
    target_bin_id: u64
)
```
**Purpose**: To provide additional liquidity to a pool, enabling more trading volume.

**Parameters**:

- **liquidator**: &signer: The user providing the liquidity.
- **token1_address**, **token2_address**, **bin_step**: Identifiers for the target pool.
- **token1_amount**, **token2_amount**: The amounts of each token to add.
- **target_bin_id**: u64: The specific price bin where the user wants to place their liquidity.

**Process**:

1. Finds the specified pool using the **Factory**.
2. Transfers the specified token amounts from the user to the pool.
3. If the **target_bin_id** already exists, its token reserves are increased.
4. If the **target_bin_id** does not exist, a new **Bin** is created at that price point.
5. Updates the user's **LiquidatorPosition** to reflect their new, larger share.

**remove_liquidity**
Allows a liquidity provider to withdraw a percentage of their assets from a specific bin they have funded.

Rust
```rust
public entry fun remove_liquidity(
    liquidator: &signer,
    token1_address: address,
    token2_address: address,
    bin_step: u16,
    target_bin_id: u64,
    liquidity_percentage: u64
)
```
**Purpose**: To allow LPs to exit their positions and reclaim their tokens.

**Parameters**:

- **liquidator**: &signer: The user withdrawing liquidity.
- **target_bin_id**: u64: The specific bin to withdraw from.
- **liquidity_percentage**: u64: The percentage of their liquidity in that bin to remove (from 1 to 100).

**Process**:

1. Validates that the user has a **liquidity position** in the specified pool and bin.
2. Calculates the user's proportional share of the liquidity within the **target_bin_id**.
3. Determines the corresponding amounts of **token1** and **token2** to remove based on the requested percentage.
4. Updates the **bin's** and the **pool's** total reserves.
5. Updates the user's **LiquidatorPosition** to reflect their smaller share.
6. Transfers the withdrawn tokens back to the user's account.

4. **Trading**
**swap**
The core function for traders to exchange one token for another.

Rust
```rust
public entry fun swap(
    user: &signer,
    token_in_address: address,
    token_out_address: address,
    bin_step: u16,
    amount_in: u64,
    min_amount_out: u64,
    swap_for_exact_out: bool
)
```
**Purpose**: To execute a trade at the best available price according to the DLMM's **bin** structure.

**Parameters**:

- **user**: &signer: The user performing the swap.
- **token_in_address**, **token_out_address**: The tokens to be swapped.
- **amount_in**: u64: The amount of the input token the user is spending.
- **min_amount_out**: u64: A slippage protection parameter. The transaction will fail if the calculated output is less than this amount.

**Process**:

1. Finds the correct **pool** based on the token pair and **bin_step**.
2. Initiates the swap at the pool's current **active_bin_id**.
3. Calculates the trade outcome by consuming liquidity from the **active bin** at its fixed price.
4. If the **active bin's** liquidity is fully consumed, the trade automatically "hops" to the next adjacent bin and continues, updating the pool's **active_bin_id** to the new price.
5. This process repeats until the user's **amount_in** is fully spent.
6. The final **amount_out** is calculated, and slippage protection is verified.
7. The user's **token_in** is deducted, and the **token_out** is added to their balance.
8. The **pool's** reserves are updated to reflect the trade.

**Simplified Token Management**
This implementation utilizes a simplified, on-chain accounting system to manage user balances for the purpose of demonstrating the core DLMM logic.

- **UserTokens Struct**: A resource stored under a user's account that holds balances for three different tokens.
- **Helper Functions**: `add_user_tokens`, `deduct_single_token`, and `add_single_token` are used to initialize and modify these balances.
- **Note**: This system operates independently of the standard Aptos token and coin standards. It is a mock framework designed to allow the DLMM functions to execute without requiring fully compliant on-chain tokens.

**Getting Started**
1. **Initialize the Protocol**: The admin must call `initialize_factory` once.
2. **Provide Mock Tokens**: Users can call `add_user_tokens` to give themselves a starting balance for testing.
3. **Create a Pool**: A user calls `create_pool` with two token addresses and initial amounts to start a new market.
4. **Interact**: Other users can now `swap` tokens or `add_liquidity` and `remove_liquidity` from the pool.