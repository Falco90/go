#[system]
mod place_stone_system {
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point};


    fn execute(ctx: Context, x: u32, y: u32, caller: ContractAddress, game_id: felt252) {
        set!(
            ctx.world,
            (Point { game_id: game_id, x: x, y: y, owned_by: Option::Some(Color::White(())) })
        );
    }
}

#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::test_utils::spawn_test_world;
    use go::components::{Game, game, GameTurn, game_turn, Point, point, Color};

    use go::systems::initiate_system;
    use go::systems::place_stone_system;
    use array::ArrayTrait;
    use core::traits::Into;
    use dojo::world::IWorldDispatcherTrait;
    use core::array::SpanTrait;

    #[test]
    #[available_gas(3000000000000000)]
    fn test_move() {
        let white = starknet::contract_address_const::<0x01>();
        let black = starknet::contract_address_const::<0x02>();
        let board_size: u32 = 19;

        // components
        let mut components = array::ArrayTrait::new();
        components.append(game::TEST_CLASS_HASH);
        components.append(game_turn::TEST_CLASS_HASH);
        components.append(point::TEST_CLASS_HASH);

        //systems
        let mut systems = array::ArrayTrait::new();
        systems.append(initiate_system::TEST_CLASS_HASH);
        systems.append(place_stone_system::TEST_CLASS_HASH);
        let world = spawn_test_world(components, systems);

        // initiate
        let mut calldata = array::ArrayTrait::<core::felt252>::new();
        calldata.append(white.into());
        calldata.append(black.into());
        calldata.append(board_size.into());
        world.execute('initiate_system'.into(), calldata);

        let game_id = pedersen(white.into(), black.into());

        // Place white stone in [3,3]
        let mut place_stone_calldata = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata.append(3);
        place_stone_calldata.append(3);
        place_stone_calldata.append(white.into());
        place_stone_calldata.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata);

        //White stone is in (3,3)
        let point = get!(world, (game_id, 3, 3), (Point));
        match point.owned_by {
            Option::Some(owner) => {
                assert(owner == Color::White, '[3,3] should be owned by white');
            },
            Option::None(_) => assert(false, 'should have stone in [3,3]'),
        };
    }
}
