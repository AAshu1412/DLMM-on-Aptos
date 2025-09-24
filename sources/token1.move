address ashu_address {
module token1 {

    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use 0x1::error;
    use 0x1::signer;
    use 0x1::string;
    use std::option;
    use std::debug::print;

    struct Tokenn1 has store {
        value: u64
    }

    fun init_module(sender: signer) {
        // managed_coin::register<Tokenn1>(&sender);
        managed_coin::initialize<Tokenn1>(&sender, b"Token1", b"T1", 6, false);
        let adada = signer::address_of(&sender);
        managed_coin::mint<Tokenn1>(&sender, adada, 2000000);

        print(&string::utf8(b"Module initialized"));
    }

    // #[view]
    fun get_info() {
        let data = coin::supply<Tokenn1>();
        //     match data {
        //     Some(value)=>print(value),
        //     None=>print(utf8(b"It is not a real number"))
        //  }
        print(&data);
    }

    #[test(account = @ashu_address)]
    fun test_function(account: signer) {
        init_module(account);
        get_info();
    }
}

module dlmm {
    use aptos_framework::coin;
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleStore};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::option;
    use std::simple_map::{SimpleMap, Self as simple_map};
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    // Error codes
    const E_POOL_ALREADY_EXISTS: u64 = 1;
    const E_POOL_NOT_EXISTS: u64 = 2;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 3;
    const E_INVALID_TOKEN_PAIR: u64 = 4;
    const E_INSUFFICIENT_AMOUNT: u64 = 5;
    const E_NOT_POOL_CREATOR: u64 = 6;

    // Global factory resource stored under module publisher's address
    struct Factory has key {
        pools: SimpleMap<PoolKey, address>,
        pool_count: u64,
        fee_recipient: address,
        default_bin_step: u16
    }

    // Unique identifier for each pool
    struct PoolKey has copy, drop, store {
        token1_address: address,
        token2_address: address,
        bin_step: u16
    }

    // Individual pool resource stored under its own address
    struct Pool has key {
        id: u64,
        token1_metadata: Object<Metadata>,
        token2_metadata: Object<Metadata>,
        token1_reserve: u64,
        token2_reserve: u64,
        active_bin_id: u64,
        bin_step: u16,
        bin_count: u64,
        all_bins: SimpleMap<u64, Bin>,
        liquidators: vector<address>,
        total_liquidity: u64,
        fees_collected: u64,
        creator: address,
        created_at: u64
    }

    // Liquidator position tracking
    struct LiquidatorPosition has key {
        pools: SimpleMap<PoolKey, LiquidatorData>
    }

    struct LiquidatorData has store {
        token1_amount: u64,
        token2_amount: u64,
        active_bin_id: u64,
        liquidity_share: u64
    }

    // Bin for DLMM liquidity distribution
    struct Bin has store {
        bin_id: u64,
        token1_amount: u64,
        token2_amount: u64,
        liquidator_addresses: vector<address>,
        total_liquidity: u64,
        price_range_low: u64,
        price_range_high: u64
    }

    // Events
    struct PoolCreatedEvent has drop, store {
        pool_id: u64,
        creator: address,
        token1_address: address,
        token2_address: address,
        initial_token1_amount: u64,
        initial_token2_amount: u64,
        bin_step: u16
    }

    struct LiquidityAddedEvent has drop, store {
        pool_id: u64,
        liquidator: address,
        token1_amount: u64,
        token2_amount: u64,
        bin_id: u64
    }

    // Initialize the factory (should be called once by module publisher)
    public entry fun initialize_factory(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Ensure factory doesn't already exist
        assert!(!exists<Factory>(admin_addr), error::already_exists(E_POOL_ALREADY_EXISTS));
        
        let factory = Factory {
            pools: simple_map::create(),
            pool_count: 0,
            fee_recipient: admin_addr,
            default_bin_step: 25 // 0.25% default bin step
        };
        
        move_to(admin, factory);
    }

    // Create a new liquidity pool
    public entry fun create_pool(
        creator: &signer,
        token1_address: address,
        token2_address: address,
        initial_token1_amount: u64,
        initial_token2_amount: u64,
        bin_step: u16,
        fees: u64
    ) acquires Factory, LiquidatorPosition {
        let creator_addr = signer::address_of(creator);
        
        // Validate inputs
        assert!(token1_address != token2_address, error::invalid_argument(E_INVALID_TOKEN_PAIR));
        assert!(initial_token1_amount > 0 && initial_token2_amount > 0, error::invalid_argument(E_INSUFFICIENT_AMOUNT));
        
        // Get factory and increment pool count
        let factory = borrow_global_mut<Factory>(@ashu_address);
        let pool_id = factory.pool_count + 1;
        factory.pool_count = pool_id;
        
        // Create pool key
        let pool_key = PoolKey {
            token1_address,
            token2_address,
            bin_step
        };
        
        // Ensure pool doesn't already exist
        assert!(!simple_map::contains_key(&factory.pools, &pool_key), error::already_exists(E_POOL_ALREADY_EXISTS));
        
        // Create pool constructor reference
        let pool_constructor_ref = object::create_object(creator_addr);
        let pool_signer = object::generate_signer(&pool_constructor_ref);
        let pool_address = signer::address_of(&pool_signer);
        
        // Get token metadata
        let token1_metadata = object::address_to_object<Metadata>(token1_address);
        let token2_metadata = object::address_to_object<Metadata>(token2_address);
        
        // Calculate active bin (middle bin)
        let active_bin_id = 8388608; // 2^23, middle bin for balanced start
        
        // Create initial bin
        let initial_bin = Bin {
            bin_id: active_bin_id,
            token1_amount: initial_token1_amount,
            token2_amount: initial_token2_amount,
            liquidator_addresses: vector[creator_addr],
            total_liquidity: initial_token1_amount + initial_token2_amount, // Simplified liquidity calculation
            price_range_low: active_bin_id * bin_step as u64,
            price_range_high: (active_bin_id + 1) * bin_step as u64
        };
        
        // Create bins map and add initial bin
        let all_bins = simple_map::create();
        simple_map::add(&mut all_bins, active_bin_id, initial_bin);
        
        // Create pool
        let pool = Pool {
            id: pool_id,
            token1_metadata,
            token2_metadata,
            token1_reserve: initial_token1_amount,
            token2_reserve: initial_token2_amount,
            active_bin_id,
            bin_step,
            bin_count: 1,
            all_bins,
            liquidators: vector[creator_addr],
            total_liquidity: initial_token1_amount + initial_token2_amount,
            fees_collected: 0,
            creator: creator_addr,
            created_at: timestamp::now_seconds()
        };
        
        // Store pool
        move_to(&pool_signer, pool);
        
        // Add pool to factory registry
        simple_map::add(&mut factory.pools, pool_key, pool_address);
        
        // Transfer tokens from creator to pool
        primary_fungible_store::transfer(creator, token1_metadata, pool_address, initial_token1_amount);
        primary_fungible_store::transfer(creator, token2_metadata, pool_address, initial_token2_amount);
        
        // Initialize liquidator position if doesn't exist
        if (!exists<LiquidatorPosition>(creator_addr)) {
            let liquidator_position = LiquidatorPosition {
                pools: simple_map::create()
            };
            move_to(creator, liquidator_position);
        };
        
        // Add liquidator data
        let liquidator_position = borrow_global_mut<LiquidatorPosition>(creator_addr);
        let liquidator_data = LiquidatorData {
            token1_amount: initial_token1_amount,
            token2_amount: initial_token2_amount,
            active_bin_id,
            liquidity_share: initial_token1_amount + initial_token2_amount
        };
        simple_map::add(&mut liquidator_position.pools, pool_key, liquidator_data);
        
        // Emit event
        event::emit(PoolCreatedEvent {
            pool_id,
            creator: creator_addr,
            token1_address,
            token2_address,
            initial_token1_amount,
            initial_token2_amount,
            bin_step
        });
    }

    // Add liquidity to existing pool
    public entry fun add_liquidity(
        liquidator: &signer,
        token1_address: address,
        token2_address: address,
        bin_step: u16,
        token1_amount: u64,
        token2_amount: u64,
        target_bin_id: u64
    ) acquires Factory, Pool, LiquidatorPosition {
        let liquidator_addr = signer::address_of(liquidator);
        
        // Get pool
        let factory = borrow_global<Factory>(@ashu_address);
        let pool_key = PoolKey { token1_address, token2_address, bin_step };
        assert!(simple_map::contains_key(&factory.pools, &pool_key), error::not_found(E_POOL_NOT_EXISTS));
        
        let pool_address = *simple_map::borrow(&factory.pools, &pool_key);
        let pool = borrow_global_mut<Pool>(pool_address);
        
        // Transfer tokens to pool
        primary_fungible_store::transfer(liquidator, pool.token1_metadata, pool_address, token1_amount);
        primary_fungible_store::transfer(liquidator, pool.token2_metadata, pool_address, token2_amount);
        
        // Update pool reserves
        pool.token1_reserve = pool.token1_reserve + token1_amount;
        pool.token2_reserve = pool.token2_reserve + token2_amount;
        pool.total_liquidity = pool.total_liquidity + token1_amount + token2_amount;
        
        // Update or create bin
        if (simple_map::contains_key(&pool.all_bins, &target_bin_id)) {
            let bin = simple_map::borrow_mut(&mut pool.all_bins, &target_bin_id);
            bin.token1_amount = bin.token1_amount + token1_amount;
            bin.token2_amount = bin.token2_amount + token2_amount;
            bin.total_liquidity = bin.total_liquidity + token1_amount + token2_amount;
            
            // Add liquidator if not already present
            if (!vector::contains(&bin.liquidator_addresses, &liquidator_addr)) {
                vector::push_back(&mut bin.liquidator_addresses, liquidator_addr);
            };
        } else {
            // Create new bin
            let new_bin = Bin {
                bin_id: target_bin_id,
                token1_amount,
                token2_amount,
                liquidator_addresses: vector[liquidator_addr],
                total_liquidity: token1_amount + token2_amount,
                price_range_low: target_bin_id * pool.bin_step as u64,
                price_range_high: (target_bin_id + 1) * pool.bin_step as u64
            };
            simple_map::add(&mut pool.all_bins, target_bin_id, new_bin);
            pool.bin_count = pool.bin_count + 1;
        };
        
        // Add liquidator to pool if not already present
        if (!vector::contains(&pool.liquidators, &liquidator_addr)) {
            vector::push_back(&mut pool.liquidators, liquidator_addr);
        };
        
        // Update liquidator position
        if (!exists<LiquidatorPosition>(liquidator_addr)) {
            let liquidator_position = LiquidatorPosition {
                pools: simple_map::create()
            };
            move_to(liquidator, liquidator_position);
        };
        
        let liquidator_position = borrow_global_mut<LiquidatorPosition>(liquidator_addr);
        if (simple_map::contains_key(&liquidator_position.pools, &pool_key)) {
            let liquidator_data = simple_map::borrow_mut(&mut liquidator_position.pools, &pool_key);
            liquidator_data.token1_amount = liquidator_data.token1_amount + token1_amount;
            liquidator_data.token2_amount = liquidator_data.token2_amount + token2_amount;
            liquidator_data.liquidity_share = liquidator_data.liquidity_share + token1_amount + token2_amount;
        } else {
            let liquidator_data = LiquidatorData {
                token1_amount,
                token2_amount,
                active_bin_id: target_bin_id,
                liquidity_share: token1_amount + token2_amount
            };
            simple_map::add(&mut liquidator_position.pools, pool_key, liquidator_data);
        };
        
        // Emit event
        event::emit(LiquidityAddedEvent {
            pool_id: pool.id,
            liquidator: liquidator_addr,
            token1_amount,
            token2_amount,
            bin_id: target_bin_id
        });
    }

    

    // View functions
    #[view]
    public fun get_pool_info(
        token1_address: address,
        token2_address: address,
        bin_step: u16
    ): (u64, u64, u64, u64, u64) acquires Factory, Pool {
        let factory = borrow_global<Factory>(@dlmm_addr);
        let pool_key = PoolKey { token1_address, token2_address, bin_step };
        
        if (!simple_map::contains_key(&factory.pools, &pool_key)) {
            return (0, 0, 0, 0, 0)
        };
        
        let pool_address = *simple_map::borrow(&factory.pools, &pool_key);
        let pool = borrow_global<Pool>(pool_address);
        
        (pool.id, pool.token1_reserve, pool.token2_reserve, pool.total_liquidity, pool.active_bin_id)
    }

    #[view]
    public fun get_pool_count(): u64 acquires Factory {
        let factory = borrow_global<Factory>(@dlmm_addr);
        factory.pool_count
    }

    #[view]
    public fun pool_exists(
        token1_address: address,
        token2_address: address,
        bin_step: u16
    ): bool acquires Factory {
        let factory = borrow_global<Factory>(@dlmm_addr);
        let pool_key = PoolKey { token1_address, token2_address, bin_step };
        simple_map::contains_key(&factory.pools, &pool_key)
    }

    #[view]
    public fun get_liquidator_position(
        liquidator: address,
        token1_address: address,
        token2_address: address,
        bin_step: u16
    ): (u64, u64, u64, u64) acquires LiquidatorPosition {
        if (!exists<LiquidatorPosition>(liquidator)) {
            return (0, 0, 0, 0)
        };
        
        let liquidator_position = borrow_global<LiquidatorPosition>(liquidator);
        let pool_key = PoolKey { token1_address, token2_address, bin_step };
        
        if (!simple_map::contains_key(&liquidator_position.pools, &pool_key)) {
            return (0, 0, 0, 0)
        };
        
        let liquidator_data = simple_map::borrow(&liquidator_position.pools, &pool_key);
        (liquidator_data.token1_amount, liquidator_data.token2_amount, 
         liquidator_data.active_bin_id, liquidator_data.liquidity_share)
    }

    // Test functions
    #[test_only]
    public fun initialize_for_test(creator: &signer) {
        initialize_factory(creator);
    }

    #[test]
    public fun test_factory_initialization() {
        let creator = account::create_account_for_test(@dlmm_addr);
        initialize_for_test(&creator);
        
        assert!(get_pool_count() == 0, 0);
    }
}

}

