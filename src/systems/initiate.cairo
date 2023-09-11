#[system]
mod initiate_system {
    use array::ArrayTrait;
    use traits::Into;
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point};

    fn execute(ctx: Context, white_address: ContractAddress, black_address: ContractAddress) {
        let game_id = pedersen(white_address.into(), black_address.into());

        set!(
            ctx.world,
            (
                Game {
                    game_id: game_id,
                    winner: Option::None(()),
                    white: white_address,
                    black: black_address,
                },
                GameTurn { game_id: game_id, turn: Color::White(()) }
            )
        );

        let mut x: usize = 0;
        let mut y: usize = 0;

        loop {
            if y > 8 {
                break;
            }
            loop {
                if x > 8 {
                    y += 1;
                    break;
                }
                set!(
                    ctx.world, (Point { game_id: game_id, x: 0, y: 0, owned_by: Option::None(()) })
                );
                x += 1;
            };
        }
    }
}

#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::test_utils::spawn_test_world;
    use go::components::{Game, game, Point, point, GameTurn, game_turn};

    use go::systems::initiate_system;
    use array::ArrayTrait;
    use core::traits::Into;
    use dojo::world::IWorldDispatcherTrait;
    use core::array::SpanTrait;

    #[test]
    #[available_gas(3000000000000000)]
    fn test_initiate() {
        let white = starknet::contract_address_const::<0x01>();
        let black = starknet::contract_address_const::<0x02>();

        // components
        let mut components = array::ArrayTrait::new();
        components.append(game::TEST_CLASS_HASH);
        components.append(game_turn::TEST_CLASS_HASH);
        components.append(point::TEST_CLASS_HASH);

        //systems
        let mut systems = array::ArrayTrait::new();
        systems.append(initiate_system::TEST_CLASS_HASH);
        let world = spawn_test_world(components, systems);

        let mut calldata = array::ArrayTrait::<core::felt252>::new();
        calldata.append(white.into());
        calldata.append(black.into());
        world.execute('initiate_system'.into(), calldata);

        let game_id = pedersen(white.into(), black.into());

        //get game
        let game = get!(world, (game_id), (Game));
        assert(game.white == white, 'white address is incorrect');
        assert(game.black == black, 'black address is incorrect');

        //get top-left Point
        let top_left = get!(world, (game_id, 0, 0), (Point));
        match top_left.owned_by {
            Option::Some(piece) => {
                assert(false, 'should not be owned');
            },
            Option::None(_) => assert(true, 'should be empty'),
        };

        //get bottom-right Point
        let bottom_right = get!(world, (game_id, 0, 0), (Point));
        match bottom_right.owned_by {
            Option::Some(piece) => {
                assert(false, 'should not be owned');
            },
            Option::None(_) => assert(true, 'should be empty'),
        };
    }
}
