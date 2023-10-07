#[system]
mod initiate_system {
    use debug::PrintTrait;
    use array::ArrayTrait;
    use traits::Into;
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point, Score, LastMove};
    use core::pedersen::{pedersen};

    fn execute(
        ctx: Context,
        white_address: ContractAddress,
        black_address: ContractAddress,
        board_size: u32,
    ) {
        let game_id = pedersen(white_address.into(), black_address.into());

        set!(
            ctx.world,
            (
                Game {
                    game_id: game_id,
                    winner: Option::None(()),
                    white: white_address,
                    black: black_address,
                    board_size: board_size,
                },
                GameTurn { game_id: game_id, turn: Color::White(()) },
                Score { game_id: game_id, color: Color::White, territories: 0, prisoners: 0, komi: 0},
                Score { game_id: game_id, color: Color::Black, territories: 0, prisoners: 0, komi: 0},
                LastMove { game_id, color: Color::White, coords: Option::None, passed: false},
                LastMove { game_id, color: Color::Black, coords: Option::None, passed: false},
            )
        );

        let mut x: usize = 0;
        let mut y: usize = 0;
        let mut index: u32 = 0;

        loop {
            if y >= board_size {
                break;
            }
            loop {
                if x >= board_size {
                    y += 1;
                    x = 0;
                    break;
                }
                set!(ctx.world, (Point { game_id, x, y, owned_by: Option::None(()) }));
                x += 1;
                index += 1;
            };
        };
    }
}


#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::test_utils::spawn_test_world;
    use go::components::{Game, game, Point, point, GameTurn, game_turn, Color, Score, score, LastMove, last_move};

    use go::systems::initiate_system;
    use array::ArrayTrait;
    use core::traits::Into;
    use dojo::world::IWorldDispatcherTrait;
    use core::array::SpanTrait;
    use core::pedersen::{pedersen};

    #[test]
    #[available_gas(3000000000000000)]
    fn test_initiate() {
        let white = starknet::contract_address_const::<0x01>();
        let black = starknet::contract_address_const::<0x02>();
        let board_size: u32 = 19;

        // components
        let mut components = array::ArrayTrait::new();
        components.append(game::TEST_CLASS_HASH);
        components.append(game_turn::TEST_CLASS_HASH);
        components.append(point::TEST_CLASS_HASH);
        components.append(score::TEST_CLASS_HASH);
        components.append(last_move::TEST_CLASS_HASH);

        //systems
        let mut systems = array::ArrayTrait::new();
        systems.append(initiate_system::TEST_CLASS_HASH);
        let world = spawn_test_world(components, systems);

        let mut calldata = array::ArrayTrait::<core::felt252>::new();
        calldata.append(white.into());
        calldata.append(black.into());
        calldata.append(board_size.into());
        world.execute('initiate_system'.into(), calldata);

        let game_id = pedersen(white.into(), black.into());

        //get game
        let game = get!(world, (game_id), (Game));
        assert(game.white == white, 'white address is incorrect');
        assert(game.black == black, 'black address is incorrect');

        //get bottom-left Point
        let bottom_left = get!(world, (game_id, 0, 0), (Point));
        match bottom_left.owned_by {
            Option::Some(_) => {
                assert(false, 'bottom left must empty');
            },
            Option::None(_) => assert(true, 'should be empty'),
        };

        //get top-right Point
        let top_right = get!(world, (game_id, board_size - 1, board_size - 1), (Point));
        match top_right.owned_by {
            Option::Some(_) => {
                assert(false, 'top right not empty');
            },
            Option::None(_) => assert(true, 'should be empty'),
        };

        //get score
        let score = get!(world, (game_id, Color::White), (Score));
        assert(score.territories == 0, 'should be 0');
        assert(score.prisoners == 0, 'should be 0');
        assert(score.komi == 0, 'should be 0');

        //check last move Black
        let last_move = get!(world, (game_id, Color::Black), (LastMove));
        match last_move.coords {
            Option::Some(coords) => {
                assert(false, 'should not have last move');
            },
            Option::None(_) => {
                assert(true, 'should not have last move')
            }
        }

        //check last move White
        let last_move = get!(world, (game_id, Color::White), (LastMove));
        match last_move.coords {
            Option::Some(coords) => {
                assert(false, 'should not have last move');
            },
            Option::None(_) => {
                assert(true, 'should not have last move')
            }
        }
    }
}
