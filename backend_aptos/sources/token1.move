address ashu_address {
module token11 {
    use std::string;
    use std::signer;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, FreezeCapability};
    use aptos_framework::account;
    
    /// DLT1 Token for Receipt Rewards
    struct DLT1 {}

    /// Capabilities for managing DLT1 token
    struct DLT1Capabilities has key {
        mint_cap: MintCapability<DLT1>,
        burn_cap: BurnCapability<DLT1>,
        freeze_cap: FreezeCapability<DLT1>,
    }

    /// Configuration for token parameters
    struct TokenConfig has key {
        decimals: u8,
        total_supply_cap: u128,
        current_supply: u128,
    }

    /// Errors
    const E_NOT_ADMIN: u64 = 1;
    const E_INSUFFICIENT_PERMISSIONS: u64 = 2;
    const E_SUPPLY_EXCEEDED: u64 = 3;

    /// Constants
    const DECIMALS: u8 = 8;
    const MAX_SUPPLY: u128 = 1000000000 * 100000000; // 1B tokens with 8 decimals

    /// Initialize the DLT1 token
    fun init_module(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Initialize the coin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<DLT1>(
            admin,
            string::utf8(b"Receipt Token"),
            string::utf8(b"DLT1"),
            DECIMALS,
            true, // monitor_supply
        );

        // Store capabilities
        move_to(admin, DLT1Capabilities {
            mint_cap,
            burn_cap,
            freeze_cap,
        });

        // Store token configuration
        move_to(admin, TokenConfig {
            decimals: DECIMALS,
            total_supply_cap: MAX_SUPPLY,
            current_supply: 0,
        });

        // Register admin for DLT1
        coin::register<DLT1>(admin);
    }

    /// Mint DLT1 tokens (only by admin)
    public entry fun mint_tokens(
        admin: &signer, 
        to: address, 
        amount: u64
    ) acquires DLT1Capabilities, TokenConfig {
        let admin_addr = signer::address_of(admin);
        assert!(exists<DLT1Capabilities>(admin_addr), E_NOT_ADMIN);
        
        let config = borrow_global_mut<TokenConfig>(admin_addr);
        let new_supply = config.current_supply + (amount as u128);
        assert!(new_supply <= config.total_supply_cap, E_SUPPLY_EXCEEDED);
        
        let caps = borrow_global<DLT1Capabilities>(admin_addr);
        let coins = coin::mint<DLT1>(amount, &caps.mint_cap);
        coin::deposit(to, coins);
        config.current_supply = new_supply;
    }

    /// Burn DLT1 tokens
    public entry fun burn_tokens(
        admin: &signer,
        amount: u64
    ) acquires DLT1Capabilities, TokenConfig {
        let admin_addr = signer::address_of(admin);
        assert!(exists<DLT1Capabilities>(admin_addr), E_NOT_ADMIN);
        
        let caps = borrow_global<DLT1Capabilities>(admin_addr);
        let coins = coin::withdraw<DLT1>(admin, amount);
        coin::burn(coins, &caps.burn_cap);
        
        let config = borrow_global_mut<TokenConfig>(admin_addr);
        config.current_supply = config.current_supply - (amount as u128);
    }

    /// Register account for DLT1 token
    public entry fun register_account(account: &signer) {
        coin::register<DLT1>(account);
    }

    /// Get token balance
    #[view]
    public fun get_balance(account: address): u64 {
        coin::balance<DLT1>(account)
    }

    /// Get token info
    #[view]
    public fun get_token_info(): (string::String, string::String, u8) {
        (string::utf8(b"Receipt Token"), string::utf8(b"DLT1"), DECIMALS)
    }

    /// Get current supply
    #[view]
    public fun get_current_supply(admin_addr: address): u128 acquires TokenConfig {
        if (exists<TokenConfig>(admin_addr)) {
            borrow_global<TokenConfig>(admin_addr).current_supply
        } else {
            0
        }
    }

    /// Transfer tokens between accounts
    public entry fun transfer(
        from: &signer,
        to: address,
        amount: u64
    ) {
        coin::transfer<DLT1>(from, to, amount);
    }

    /// Internal function to mint rewards (called by other modules)
    public fun mint_rewards(
        admin_addr: address,
        to: address,
        amount: u64
    ): Coin<DLT1> acquires DLT1Capabilities, TokenConfig {
        assert!(exists<DLT1Capabilities>(admin_addr), E_NOT_ADMIN);
        
        let config = borrow_global_mut<TokenConfig>(admin_addr);
        let new_supply = config.current_supply + (amount as u128);
        assert!(new_supply <= config.total_supply_cap, E_SUPPLY_EXCEEDED);
        
        let caps = borrow_global<DLT1Capabilities>(admin_addr);
        let coins = coin::mint<DLT1>(amount, &caps.mint_cap);
        
        config.current_supply = new_supply;
        coins
    }
}

// module dlmm {
//     use aptos_framework::coin;
//     use aptos_framework::fungible_asset::{Self, Metadata, FungibleStore};
//     use aptos_framework::object::{Self, Object};
//     use aptos_framework::primary_fungible_store;
//     use std::error;
//     use std::signer;
//     use std::string::{Self, String};
//     use std::option;
//     use std::simple_map::{SimpleMap, Self as simple_map};
//     use std::vector;
//     use aptos_framework::event;
//     use aptos_framework::timestamp;
//     use std::bcs;

//     // Error codes
//     const E_POOL_ALREADY_EXISTS: u64 = 1;
//     const E_POOL_NOT_EXISTS: u64 = 2;
//     const E_INSUFFICIENT_LIQUIDITY: u64 = 3;
//     const E_INVALID_TOKEN_PAIR: u64 = 4;
//     const E_INSUFFICIENT_AMOUNT: u64 = 5;
//     const E_NOT_POOL_CREATOR: u64 = 6;

//     // Global factory resource stored under module publisher's address
//     struct Factory has key {
//         pools: SimpleMap<PoolKey, address>,
//         pool_count: u64,
//         fee_recipient: address,
//         default_bin_step: u16
//     }

//     // Unique identifier for each pool
//     struct PoolKey has copy, drop, store {
//         token1_address: address,
//         token2_address: address,
//         bin_step: u16
//     }

//     // Individual pool resource stored under its own address
//     struct Pool has key {
//         id: u64,
//         token1_metadata: Object<Metadata>,
//         token2_metadata: Object<Metadata>,
//         token1_reserve: u64,
//         token2_reserve: u64,
//         active_bin_id: u64,
//         bin_step: u16,
//         bin_count: u64,
//         all_bins: SimpleMap<u64, Bin>,
//         liquidators: vector<address>,
//         total_liquidity: u64,
//         fees_collected: u64,
//         creator: address,
//         created_at: u64
//     }

//     // Liquidator position tracking
//     struct LiquidatorPosition has key {
//         pools: SimpleMap<PoolKey, LiquidatorData>
//     }

//     struct LiquidatorData has store {
//         token1_amount: u64,
//         token2_amount: u64,
//         active_bin_id: u64,
//         liquidity_share: u64
//     }

//     // Bin for DLMM liquidity distribution
//     struct Bin has store {
//         bin_id: u64,
//         token1_amount: u64,
//         token2_amount: u64,
//         liquidator_addresses: vector<address>,
//         total_liquidity: u64,
//         price_range_low: u64,
//         price_range_high: u64
//     }

//     // Events
//     struct PoolCreatedEvent has drop, store {
//         pool_id: u64,
//         creator: address,
//         token1_address: address,
//         token2_address: address,
//         initial_token1_amount: u64,
//         initial_token2_amount: u64,
//         bin_step: u16
//     }

//     struct LiquidityAddedEvent has drop, store {
//         pool_id: u64,
//         liquidator: address,
//         token1_amount: u64,
//         token2_amount: u64,
//         bin_id: u64
//     }

//     // Initialize the factory (should be called once by module publisher)
//     public entry fun initialize_factory(admin: &signer) {
//         let admin_addr = signer::address_of(admin);
        
//         // Ensure factory doesn't already exist
//         assert!(!exists<Factory>(admin_addr), error::already_exists(E_POOL_ALREADY_EXISTS));
        
//         let factory = Factory {
//             pools: simple_map::create(),
//             pool_count: 0,
//             fee_recipient: admin_addr,
//             default_bin_step: 25 // 0.25% default bin step
//         };
        
//         move_to(admin, factory);
//     }

//     // Create a new liquidity pool
//     public entry fun create_pool(
//         creator: &signer,
//         token1_address: address,
//         token2_address: address,
//         initial_token1_amount: u64,
//         initial_token2_amount: u64,
//         bin_step: u16,
//         fees: u64
//     ) acquires Factory, LiquidatorPosition {
//         let creator_addr = signer::address_of(creator);
        
//         // Validate inputs
//         assert!(token1_address != token2_address, error::invalid_argument(E_INVALID_TOKEN_PAIR));
//         assert!(initial_token1_amount > 0 && initial_token2_amount > 0, error::invalid_argument(E_INSUFFICIENT_AMOUNT));
        
//         // Get factory and increment pool count
//         let factory = borrow_global_mut<Factory>(@ashu_address);
//         let pool_id = factory.pool_count + 1;
//         factory.pool_count = pool_id;
        
//         // Create pool key
//         let pool_key = PoolKey {
//             token1_address,
//             token2_address,
//             bin_step
//         };
        
//         // Ensure pool doesn't already exist
//         assert!(!simple_map::contains_key(&factory.pools, &pool_key), error::already_exists(E_POOL_ALREADY_EXISTS));
        
//         // Create pool constructor reference
//         let pool_constructor_ref = object::create_object(creator_addr);
//         let pool_signer = object::generate_signer(&pool_constructor_ref);
//         let pool_address = signer::address_of(&pool_signer);
        
//         // Get token metadata
//         let token1_metadata = object::address_to_object<Metadata>(token1_address);
//         let token2_metadata = object::address_to_object<Metadata>(token2_address);
        
//         // Calculate active bin (middle bin)
//         let active_bin_id = 8388608; // 2^23, middle bin for balanced start
        
//         // Create initial bin
//         let initial_bin = Bin {
//             bin_id: active_bin_id,
//             token1_amount: initial_token1_amount,
//             token2_amount: initial_token2_amount,
//             liquidator_addresses: vector[creator_addr],
//             total_liquidity: initial_token1_amount + initial_token2_amount, // Simplified liquidity calculation
//             price_range_low: active_bin_id * (bin_step as u64),
//             price_range_high: (active_bin_id + 1) * (bin_step as u64)
//         };
        
//         // Create bins map and add initial bin
//         let all_bins = simple_map::create();
//         simple_map::add(&mut all_bins, active_bin_id, initial_bin);
        
//         // Create pool
//         let pool = Pool {
//             id: pool_id,
//             token1_metadata,
//             token2_metadata,
//             token1_reserve: initial_token1_amount,
//             token2_reserve: initial_token2_amount,
//             active_bin_id,
//             bin_step,
//             bin_count: 1,
//             all_bins,
//             liquidators: vector[creator_addr],
//             total_liquidity: initial_token1_amount + initial_token2_amount,
//             fees_collected: 0,
//             creator: creator_addr,
//             created_at: timestamp::now_seconds()
//         };
        
//         // Store pool
//         move_to(&pool_signer, pool);
        
//         // Add pool to factory registry
//         simple_map::add(&mut factory.pools, pool_key, pool_address);
        
//         // Transfer tokens from creator to pool
//         primary_fungible_store::transfer(creator, token1_metadata, pool_address, initial_token1_amount);
//         primary_fungible_store::transfer(creator, token2_metadata, pool_address, initial_token2_amount);
        
//         // Initialize liquidator position if doesn't exist
//         if (!exists<LiquidatorPosition>(creator_addr)) {
//             let liquidator_position = LiquidatorPosition {
//                 pools: simple_map::create()
//             };
//             move_to(creator, liquidator_position);
//         };
        
//         // Add liquidator data
//         let liquidator_position = borrow_global_mut<LiquidatorPosition>(creator_addr);
//         let liquidator_data = LiquidatorData {
//             token1_amount: initial_token1_amount,
//             token2_amount: initial_token2_amount,
//             active_bin_id,
//             liquidity_share: initial_token1_amount + initial_token2_amount
//         };
//         simple_map::add(&mut liquidator_position.pools, pool_key, liquidator_data);
        
//         // Emit event
//         event::emit(PoolCreatedEvent {
//             pool_id,
//             creator: creator_addr,
//             token1_address,
//             token2_address,
//             initial_token1_amount,
//             initial_token2_amount,
//             bin_step
//         });
//     }

//     // Add liquidity to existing pool
//     public entry fun add_liquidity(
//         liquidator: &signer,
//         token1_address: address,
//         token2_address: address,
//         bin_step: u16,
//         token1_amount: u64,
//         token2_amount: u64,
//         target_bin_id: u64
//     ) acquires Factory, Pool, LiquidatorPosition {
//         let liquidator_addr = signer::address_of(liquidator);
        
//         // Get pool
//         let factory = borrow_global<Factory>(@ashu_address);
//         let pool_key = PoolKey { token1_address, token2_address, bin_step };
//         assert!(simple_map::contains_key(&factory.pools, &pool_key), error::not_found(E_POOL_NOT_EXISTS));
        
//         let pool_address = *simple_map::borrow(&factory.pools, &pool_key);
//         let pool = borrow_global_mut<Pool>(pool_address);
        
//         // Transfer tokens to pool
//         primary_fungible_store::transfer(liquidator, pool.token1_metadata, pool_address, token1_amount);
//         primary_fungible_store::transfer(liquidator, pool.token2_metadata, pool_address, token2_amount);
        
//         // Update pool reserves
//         pool.token1_reserve = pool.token1_reserve + token1_amount;
//         pool.token2_reserve = pool.token2_reserve + token2_amount;
//         pool.total_liquidity = pool.total_liquidity + token1_amount + token2_amount;
        
//         // Update or create bin
//         if (simple_map::contains_key(&pool.all_bins, &target_bin_id)) {
//             let bin = simple_map::borrow_mut(&mut pool.all_bins, &target_bin_id);
//             bin.token1_amount = bin.token1_amount + token1_amount;
//             bin.token2_amount = bin.token2_amount + token2_amount;
//             bin.total_liquidity = bin.total_liquidity + token1_amount + token2_amount;
            
//             // Add liquidator if not already present
//             if (!vector::contains(&bin.liquidator_addresses, &liquidator_addr)) {
//                 vector::push_back(&mut bin.liquidator_addresses, liquidator_addr);
//             };
//         } else {
//             // Create new bin
//             let new_bin = Bin {
//                 bin_id: target_bin_id,
//                 token1_amount,
//                 token2_amount,
//                 liquidator_addresses: vector[liquidator_addr],
//                 total_liquidity: token1_amount + token2_amount,
//                 price_range_low: target_bin_id * (pool.bin_step as u64),
//                 price_range_high: (target_bin_id + 1) * (pool.bin_step as u64)
//             };
//             simple_map::add(&mut pool.all_bins, target_bin_id, new_bin);
//             pool.bin_count = pool.bin_count + 1;
//         };
        
//         // Add liquidator to pool if not already present
//         if (!vector::contains(&pool.liquidators, &liquidator_addr)) {
//             vector::push_back(&mut pool.liquidators, liquidator_addr);
//         };
        
//         // Update liquidator position
//         if (!exists<LiquidatorPosition>(liquidator_addr)) {
//             let liquidator_position = LiquidatorPosition {
//                 pools: simple_map::create()
//             };
//             move_to(liquidator, liquidator_position);
//         };
        
//         let liquidator_position = borrow_global_mut<LiquidatorPosition>(liquidator_addr);
//         if (simple_map::contains_key(&liquidator_position.pools, &pool_key)) {
//             let liquidator_data = simple_map::borrow_mut(&mut liquidator_position.pools, &pool_key);
//             liquidator_data.token1_amount = liquidator_data.token1_amount + token1_amount;
//             liquidator_data.token2_amount = liquidator_data.token2_amount + token2_amount;
//             liquidator_data.liquidity_share = liquidator_data.liquidity_share + token1_amount + token2_amount;
//         } else {
//             let liquidator_data = LiquidatorData {
//                 token1_amount,
//                 token2_amount,
//                 active_bin_id: target_bin_id,
//                 liquidity_share: token1_amount + token2_amount
//             };
//             simple_map::add(&mut liquidator_position.pools, pool_key, liquidator_data);
//         };
        
//         // Emit event
//         event::emit(LiquidityAddedEvent {
//             pool_id: pool.id,
//             liquidator: liquidator_addr,
//             token1_amount,
//             token2_amount,
//             bin_id: target_bin_id
//         });
//     }



//     // View functions
//     #[view]
//     public fun get_pool_info(
//         token1_address: address,
//         token2_address: address,
//         bin_step: u16
//     ): (u64, u64, u64, u64, u64) acquires Factory, Pool {
//         let factory = borrow_global<Factory>(@dlmm_addr);
//         let pool_key = PoolKey { token1_address, token2_address, bin_step };
        
//         if (!simple_map::contains_key(&factory.pools, &pool_key)) {
//             return (0, 0, 0, 0, 0)
//         };
        
//         let pool_address = *simple_map::borrow(&factory.pools, &pool_key);
//         let pool = borrow_global<Pool>(pool_address);
        
//         (pool.id, pool.token1_reserve, pool.token2_reserve, pool.total_liquidity, pool.active_bin_id)
//     }

//     #[view]
//     public fun get_pool_count(): u64 acquires Factory {
//         let factory = borrow_global<Factory>(@dlmm_addr);
//         factory.pool_count
//     }

//     #[view]
//     public fun pool_exists(
//         token1_address: address,
//         token2_address: address,
//         bin_step: u16
//     ): bool acquires Factory {
//         let factory = borrow_global<Factory>(@dlmm_addr);
//         let pool_key = PoolKey { token1_address, token2_address, bin_step };
//         simple_map::contains_key(&factory.pools, &pool_key)
//     }

//     #[view]
//     public fun get_liquidator_position(
//         liquidator: address,
//         token1_address: address,
//         token2_address: address,
//         bin_step: u16
//     ): (u64, u64, u64, u64) acquires LiquidatorPosition {
//         if (!exists<LiquidatorPosition>(liquidator)) {
//             return (0, 0, 0, 0)
//         };
        
//         let liquidator_position = borrow_global<LiquidatorPosition>(liquidator);
//         let pool_key = PoolKey { token1_address, token2_address, bin_step };
        
//         if (!simple_map::contains_key(&liquidator_position.pools, &pool_key)) {
//             return (0, 0, 0, 0)
//         };
        
//         let liquidator_data = simple_map::borrow(&liquidator_position.pools, &pool_key);
//         (liquidator_data.token1_amount, liquidator_data.token2_amount, 
//          liquidator_data.active_bin_id, liquidator_data.liquidity_share)
//     }


//     /////////////////////////////////////////////////
//     /// 
//     /// 
//     // Additional error codes (add to existing ones)
// const E_INSUFFICIENT_LIQUIDITY_FOR_SWAP: u64 = 7;
// const E_SLIPPAGE_EXCEEDED: u64 = 8;
// const E_INVALID_SWAP_DIRECTION: u64 = 9;
// const E_NO_LIQUIDITY_TO_REMOVE: u64 = 10;
// const E_INSUFFICIENT_LP_TOKENS: u64 = 11;

// // Additional events (add to existing events)
// struct SwapEvent has drop, store {
//     pool_id: u64,
//     user: address,
//     token_in: address,
//     token_out: address,
//     amount_in: u64,
//     amount_out: u64,
//     fees_paid: u64,
//     bins_crossed: u64
// }

// struct LiquidityRemovedEvent has drop, store {
//     pool_id: u64,
//     liquidator: address,
//     token1_removed: u64,
//     token2_removed: u64,
//     bin_id: u64,
//     liquidity_share_burned: u64
// }

// // Add this helper function to standardize token pair ordering
// fun standardize_token_pair(token_a: address, token_b: address): (address, address) {
//     // Convert addresses to bytes for comparison
//     let token_a_bytes = bcs::to_bytes(&token_a);
//     let token_b_bytes = bcs::to_bytes(&token_b);
    
//     // Compare byte vectors to determine canonical order
//     if (compare_byte_vectors(&token_a_bytes, &token_b_bytes)) {
//         (token_a, token_b)  // token_a is "smaller"
//     } else {
//         (token_b, token_a)  // token_b is "smaller"
//     }
// }

// // Helper function to compare two byte vectors
// fun compare_byte_vectors(vec_a: &vector<u8>, vec_b: &vector<u8>): bool {
//     let len_a = vector::length(vec_a);
//     let len_b = vector::length(vec_b);
//     let min_len = if (len_a < len_b) len_a else len_b;
    
//     let i = 0;
//     while (i < min_len) {
//         let byte_a = *vector::borrow(vec_a, i);
//         let byte_b = *vector::borrow(vec_b, i);
        
//         if (byte_a < byte_b) return true;
//         if (byte_a > byte_b) return false;
        
//         i = i + 1;
//     };
    
//     // If all compared bytes are equal, shorter vector comes first
//     len_a < len_b
// }


// // Swap function - exchanges one token for another using DLMM logic
// public entry fun swap(
//     user: &signer,
//     token_in_address: address,
//     token_out_address: address,
//     bin_step: u16,
//     amount_in: u64,
//     min_amount_out: u64,
//     swap_for_exact_out: bool
// ) acquires Factory, Pool {
//     let user_addr = signer::address_of(user);
    
//     // Validate input
//     assert!(amount_in > 0, error::invalid_argument(E_INSUFFICIENT_AMOUNT));
//     assert!(token_in_address != token_out_address, error::invalid_argument(E_INVALID_TOKEN_PAIR));
    
//     // Get pool
//     let factory = borrow_global<Factory>(@ashu_address);
//        let (token1_std, token2_std) = standardize_token_pair(token_in_address, token_out_address);
//     let pool_key = PoolKey { 
//         token1_address: token1_std,
//         token2_address: token2_std,
//         bin_step 
//     };
    

//     assert!(simple_map::contains_key(&factory.pools, &pool_key), error::not_found(E_POOL_NOT_EXISTS));
    
//     let pool_address = *simple_map::borrow(&factory.pools, &pool_key);
//     let pool = borrow_global_mut<Pool>(pool_address);
    
//     // Determine swap direction (true if swapping token1 for token2)
//     let swap_token1_for_token2 = token_in_address == pool_key.token1_address;
    
//     // Calculate swap with DLMM algorithm
//     let (amount_out, fees_collected, bins_crossed) = calculate_swap_amount(
//         pool,
//         amount_in,
//         swap_token1_for_token2,
//         swap_for_exact_out
//     );
    
//     // Check slippage protection
//     assert!(amount_out >= min_amount_out, error::invalid_argument(E_SLIPPAGE_EXCEEDED));
    
//     // Get token metadata
//     let token_in_metadata = if (swap_token1_for_token2) pool.token1_metadata else pool.token2_metadata;
//     let token_out_metadata = if (swap_token1_for_token2) pool.token2_metadata else pool.token1_metadata;
    
//     // Transfer tokens
//     primary_fungible_store::transfer(user, token_in_metadata, pool_address, amount_in);
//     primary_fungible_store::transfer_from_pool(pool_address, token_out_metadata, user_addr, amount_out);
    
//     // Update pool reserves
//     if (swap_token1_for_token2) {
//         pool.token1_reserve = pool.token1_reserve + amount_in;
//         pool.token2_reserve = pool.token2_reserve - amount_out;
//     } else {
//         pool.token2_reserve = pool.token2_reserve + amount_in;
//         pool.token1_reserve = pool.token1_reserve - amount_out;
//     };
    
//     // Update fees collected
//     pool.fees_collected = pool.fees_collected + fees_collected;
    
//     // Emit swap event
//     event::emit(SwapEvent {
//         pool_id: pool.id,
//         user: user_addr,
//         token_in: token_in_address,
//         token_out: token_out_address,
//         amount_in,
//         amount_out,
//         fees_paid: fees_collected,
//         bins_crossed
//     });
// }

// // Helper function to calculate swap amount using DLMM algorithm
// fun calculate_swap_amount(
//     pool: &mut Pool,
//     amount_in: u64,
//     swap_token1_for_token2: bool,
//     swap_for_exact_out: bool
// ): (u64, u64, u64) {
//     let amount_out = 0u64;
//     let total_fees = 0u64;
//     let bins_crossed = 0u64;
//     let remaining_amount_in = amount_in;
//     let current_bin_id = pool.active_bin_id;
    
//     // Traverse bins until swap is complete or liquidity exhausted
//     while (remaining_amount_in > 0) {
//         if (!simple_map::contains_key(&pool.all_bins, &current_bin_id)) {
//             // No more liquidity available
//             break
//         };
        
//         let bin = simple_map::borrow_mut(&mut pool.all_bins, &current_bin_id);
        
//         // Calculate available liquidity in current bin
//         let available_liquidity = if (swap_token1_for_token2) bin.token2_amount else bin.token1_amount;
        
//         if (available_liquidity == 0) {
//             // Move to next bin
//             if (swap_token1_for_token2) {
//                 current_bin_id = current_bin_id + 1; // Move up in price
//             } else {
//                 current_bin_id = current_bin_id - 1; // Move down in price
//             };
//             bins_crossed = bins_crossed + 1;
//             continue
//         };
        
//         // Calculate swap amount for this bin
//         let bin_price = calculate_bin_price(current_bin_id, pool.bin_step);
//         let (bin_amount_out, bin_amount_in_used, bin_fees) = calculate_bin_swap(
//             remaining_amount_in,
//             available_liquidity,
//             bin_price,
//             swap_token1_for_token2,
//             pool.bin_step
//         );
        
//         // Update bin liquidity
//         if (swap_token1_for_token2) {
//             bin.token1_amount = bin.token1_amount + bin_amount_in_used;
//             bin.token2_amount = bin.token2_amount - bin_amount_out;
//         } else {
//             bin.token2_amount = bin.token2_amount + bin_amount_in_used;
//             bin.token1_amount = bin.token1_amount - bin_amount_out;
//         };
        
//         // Accumulate results
//         amount_out = amount_out + bin_amount_out;
//         total_fees = total_fees + bin_fees;
//         remaining_amount_in = remaining_amount_in - bin_amount_in_used - bin_fees;
        
//         // If bin is fully consumed, move to next bin
//         if ((swap_token1_for_token2 && bin.token2_amount == 0) || 
//             (!swap_token1_for_token2 && bin.token1_amount == 0)) {
//             if (swap_token1_for_token2) {
//                 current_bin_id = current_bin_id + 1;
//             } else {
//                 current_bin_id = current_bin_id - 1;
//             };
//             bins_crossed = bins_crossed + 1;
//         };
        
//         // Update active bin
//         pool.active_bin_id = current_bin_id;
        
//         if (remaining_amount_in == 0) break;
//     };
    
//     assert!(amount_out > 0, error::invalid_state(E_INSUFFICIENT_LIQUIDITY_FOR_SWAP));
//     (amount_out, total_fees, bins_crossed)
// }

// // Calculate price for a specific bin
// fun calculate_bin_price(bin_id: u64, bin_step: u16): u64 {
//     // Simplified price calculation: price = base_price * (1 + bin_step/10000)^(bin_id - middle_bin)
//     let middle_bin = 8388608u64; // 2^23
//     let base_price = 1000000u64; // Base price in micro units
    
//     if (bin_id >= middle_bin) {
//         let price_multiplier = 10000u64 + (bin_step as u64);
//         let bin_difference = bin_id - middle_bin;
//         base_price * power(price_multiplier, bin_difference) / power(10000u64, bin_difference)
//     } else {
//         let price_divisor = 10000u64 + (bin_step as u64);
//         let bin_difference = middle_bin - bin_id;
//         base_price * power(10000u64, bin_difference) / power(price_divisor, bin_difference)
//     }
// }

// // Calculate swap within a single bin
// fun calculate_bin_swap(
//     amount_in: u64,
//     available_liquidity: u64,
//     bin_price: u64,
//     swap_token1_for_token2: bool,
//     bin_step: u16
// ): (u64, u64, u64) {
//     // Calculate base fee (0.1% base + variable fee based on volatility)
//     let base_fee_bps = 10u64; // 0.1%
//     let variable_fee_bps = (bin_step as u64) / 4; // Variable fee based on bin step
//     let total_fee_bps = base_fee_bps + variable_fee_bps;
    
//     let fee_amount = (amount_in * total_fee_bps) / 10000u64;
//     let amount_in_after_fees = amount_in - fee_amount;
    
//     // Calculate output amount based on constant product formula within bin
//     let amount_out = if (swap_token1_for_token2) {
//         // Buying token2 with token1
//         let amount_out_before_limit = (amount_in_after_fees * bin_price) / 1000000u64;
//         if (amount_out_before_limit > available_liquidity) available_liquidity else amount_out_before_limit
//     } else {
//         // Buying token1 with token2  
//         let amount_out_before_limit = (amount_in_after_fees * 1000000u64) / bin_price;
//         if (amount_out_before_limit > available_liquidity) available_liquidity else amount_out_before_limit
//     };
    
//     // Calculate actual amount in used (might be less if liquidity is exhausted)
//     let actual_amount_in_used = if (swap_token1_for_token2) {
//         (amount_out * 1000000u64) / bin_price
//     } else {
//         (amount_out * bin_price) / 1000000u64
//     };
    
//     let actual_fee_amount = (actual_amount_in_used * total_fee_bps) / (10000u64 - total_fee_bps);
    
//     (amount_out, actual_amount_in_used, actual_fee_amount)
// }

// // Simple power function for price calculations
// fun power(base: u64, exponent: u64): u64 {
//     if (exponent == 0) return 1;
//     let result = base;
//     let i = 1;
//     while (i < exponent) {
//         result = result * base;
//         i = i + 1;
//     };
//     result
// }

// // Remove liquidity from a specific bin
// public entry fun remove_liquidity(
//     liquidator: &signer,
//     token1_address: address,
//     token2_address: address,
//     bin_step: u16,
//     target_bin_id: u64,
//     liquidity_percentage: u64 // Percentage of position to remove (1-100)
// ) acquires Factory, Pool, LiquidatorPosition {
//     let liquidator_addr = signer::address_of(liquidator);
    
//     // Validate inputs
//     assert!(liquidity_percentage > 0 && liquidity_percentage <= 100, error::invalid_argument(E_INSUFFICIENT_AMOUNT));
    
//     // Get pool
//     let factory = borrow_global<Factory>(@dlmm_addr);
//     let pool_key = PoolKey { token1_address, token2_address, bin_step };
//     assert!(simple_map::contains_key(&factory.pools, &pool_key), error::not_found(E_POOL_NOT_EXISTS));
    
//     let pool_address = *simple_map::borrow(&factory.pools, &pool_key);
//     let pool = borrow_global_mut<Pool>(pool_address);
    
//     // Check liquidator position exists
//     assert!(exists<LiquidatorPosition>(liquidator_addr), error::not_found(E_NO_LIQUIDITY_TO_REMOVE));
//     let liquidator_position = borrow_global_mut<LiquidatorPosition>(liquidator_addr);
//     assert!(simple_map::contains_key(&liquidator_position.pools, &pool_key), error::not_found(E_NO_LIQUIDITY_TO_REMOVE));
    
//     // Get liquidator data
//     let liquidator_data = simple_map::borrow_mut(&mut liquidator_position.pools, &pool_key);
//     assert!(liquidator_data.liquidity_share > 0, error::invalid_state(E_NO_LIQUIDITY_TO_REMOVE));
    
//     // Check if bin exists and liquidator has position in it
//     assert!(simple_map::contains_key(&pool.all_bins, &target_bin_id), error::not_found(E_POOL_NOT_EXISTS));
//     let bin = simple_map::borrow_mut(&mut pool.all_bins, &target_bin_id);
//     assert!(vector::contains(&bin.liquidator_addresses, &liquidator_addr), error::permission_denied(E_NO_LIQUIDITY_TO_REMOVE));
    
//     // Calculate liquidity share in this bin
//     let total_bin_liquidity = bin.total_liquidity;
//     let liquidator_bin_share = calculate_liquidator_bin_share(liquidator_addr, bin, liquidator_data);
    
//     // Calculate amounts to remove based on percentage
//     let liquidity_to_remove = (liquidator_bin_share * liquidity_percentage) / 100;
//     let token1_to_remove = (bin.token1_amount * liquidity_to_remove) / total_bin_liquidity;
//     let token2_to_remove = (bin.token2_amount * liquidity_to_remove) / total_bin_liquidity;
    
//     assert!(token1_to_remove > 0 || token2_to_remove > 0, error::invalid_state(E_INSUFFICIENT_LIQUIDITY));
    
//     // Update bin liquidity
//     bin.token1_amount = bin.token1_amount - token1_to_remove;
//     bin.token2_amount = bin.token2_amount - token2_to_remove;
//     bin.total_liquidity = bin.total_liquidity - liquidity_to_remove;
    
//     // Update pool reserves
//     pool.token1_reserve = pool.token1_reserve - token1_to_remove;
//     pool.token2_reserve = pool.token2_reserve - token2_to_remove;
//     pool.total_liquidity = pool.total_liquidity - liquidity_to_remove;
    
//     // Update liquidator position
//     let liquidity_share_to_burn = (liquidator_data.liquidity_share * liquidity_percentage) / 100;
//     liquidator_data.token1_amount = liquidator_data.token1_amount - token1_to_remove;
//     liquidator_data.token2_amount = liquidator_data.token2_amount - token2_to_remove;
//     liquidator_data.liquidity_share = liquidator_data.liquidity_share - liquidity_share_to_burn;
    
//     // Remove liquidator from bin if no more liquidity
//     if (liquidity_percentage == 100) {
//         let (_, index) = vector::index_of(&bin.liquidator_addresses, &liquidator_addr);
//         vector::remove(&mut bin.liquidator_addresses, index);
        
//         // Remove from pool liquidators list if no positions left
//         let total_position_liquidity = liquidator_data.liquidity_share;
//         if (total_position_liquidity == 0) {
//             let (_, pool_index) = vector::index_of(&pool.liquidators, &liquidator_addr);
//             vector::remove(&mut pool.liquidators, pool_index);
            
//             // Remove liquidator data
//             simple_map::remove(&mut liquidator_position.pools, &pool_key);
//         };
//     };
    
//     // Transfer tokens back to liquidator
//     if (token1_to_remove > 0) {
//         primary_fungible_store::transfer_from_pool(pool_address, pool.token1_metadata, liquidator_addr, token1_to_remove);
//     };
//     if (token2_to_remove > 0) {
//         primary_fungible_store::transfer_from_pool(pool_address, pool.token2_metadata, liquidator_addr, token2_to_remove);
//     };
    
//     // Remove empty bin if no liquidity left
//     if (bin.total_liquidity == 0) {
//         simple_map::remove(&mut pool.all_bins, &target_bin_id);
//         pool.bin_count = pool.bin_count - 1;
//     };
    
//     // Emit event
//     event::emit(LiquidityRemovedEvent {
//         pool_id: pool.id,
//         liquidator: liquidator_addr,
//         token1_removed: token1_to_remove,
//         token2_removed: token2_to_remove,
//         bin_id: target_bin_id,
//         liquidity_share_burned
//     });
// }

// // Helper function to calculate liquidator's share in a specific bin
// fun calculate_liquidator_bin_share(
//     liquidator_addr: address,
//     bin: &Bin,
//     liquidator_data: &LiquidatorData
// ): u64 {
//     let liquidator_count = vector::length(&bin.liquidator_addresses);
//     if (liquidator_count == 0) return 0;
    
//     // Simplified: equal share among all liquidators in bin
//     // In practice, this would be proportional to their actual contributions
//     bin.total_liquidity / liquidator_count
// }

// // Helper function for transferring from pool (would need to be implemented based on your token standard)
// fun primary_fungible_store::transfer_from_pool(
//     pool_address: address,
//     metadata: Object<Metadata>,
//     recipient: address,
//     amount: u64
// ) {
//     // This would need to be implemented based on how you handle pool token custody
//     // For now, assume we have a way to transfer from pool address
//     // In practice, you might need to store a signer capability or use a different approach
// }

// // Additional view functions for swap calculations
// #[view]
// public fun get_swap_quote(
//     token_in_address: address,
//     token_out_address: address,
//     bin_step: u16,
//     amount_in: u64
// ): (u64, u64, u64) acquires Factory, Pool {
//     let factory = borrow_global<Factory>(@dlmm_addr);
//     let pool_key = PoolKey { 
//         token1_address: if (token_in_address < token_out_address) token_in_address else token_out_address,
//         token2_address: if (token_in_address < token_out_address) token_out_address else token_in_address,
//         bin_step 
//     };
    
//     if (!simple_map::contains_key(&factory.pools, &pool_key)) {
//         return (0, 0, 0)
//     };
    
//     let pool_address = *simple_map::borrow(&factory.pools, &pool_key);
//     let pool = borrow_global<Pool>(pool_address);
    
//     let swap_token1_for_token2 = token_in_address == pool_key.token1_address;
    
//     // This would call the same calculation logic as the swap function
//     // For now, return simple approximation
//     let estimated_out = if (swap_token1_for_token2) {
//         (amount_in * pool.token2_reserve) / (pool.token1_reserve + amount_in)
//     } else {
//         (amount_in * pool.token1_reserve) / (pool.token2_reserve + amount_in)
//     };
    
//     let estimated_fees = (amount_in * 25) / 10000; // 0.25% estimated fee
//     (estimated_out, estimated_fees, 0)
// }


//     // Test functions
//     #[test_only]
//     public fun initialize_for_test(creator: &signer) {
//         initialize_factory(creator);
//     }

//     #[test]
//     public fun test_factory_initialization() {
//         let creator = account::create_account_for_test(@dlmm_addr);
//         initialize_for_test(&creator);
        
//         assert!(get_pool_count() == 0, 0);
//     }
// }

}

