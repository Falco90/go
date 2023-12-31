#[system]
mod place_stone_system {
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point, PointTrait};
    use debug::PrintTrait;


    fn execute(ctx: Context, x: u32, y: u32, caller: ContractAddress, game_id: felt252) {
        let mut game = get!(ctx.world, (game_id), (Game));
        let mut player = Color::Black;

        if game.white == caller {
            player = Color::White;
        };

        let mut game_turn = get!(ctx.world, (game_id), (GameTurn));
        let point = get!(ctx.world, (game_id, x, y), (Point));

        assert(is_correct_turn(caller, ref game_turn, ref game), 'Not correct turn');
        assert(!is_out_of_board(x, y, game.board_size), 'Should be inside board');
        assert(is_point_empty(point), 'Point should be empty');
        assert(!is_self_capture(ctx, point, player, game.board_size), 'Cannot self capture');

        match game_turn.turn {
            Color::White => {
                set!(
                    ctx.world,
                    (Point {
                        game_id: game_id, x: x, y: y, owned_by: Option::Some(Color::White(()))
                    })
                );
            },
            Color::Black => {
                set!(
                    ctx.world,
                    (Point {
                        game_id: game_id, x: x, y: y, owned_by: Option::Some(Color::Black(()))
                    })
                );
            }
        }
    }

    fn is_point_empty(point: Point) -> bool {
        match point.owned_by {
            Option::Some(owner) => {
                return false;
            },
            Option::None(_) => {
                return true;
            }
        }
    }

    fn is_out_of_board(x: u32, y: u32, board_size: u32) -> bool {
        if x >= board_size || x < 0 {
            return true;
        }
        if y >= board_size || y < 0 {
            return true;
        }
        false
    }

    fn is_correct_turn(caller: ContractAddress, ref game_turn: GameTurn, ref game: Game) -> bool {
        if caller == game.white && game_turn.turn == Color::White {
            return true;
        }
        if caller == game.black && game_turn.turn == Color::Black {
            return true;
        }
        false
    }

    fn is_self_capture(ctx: Context, point: Point, color: Color, board_size: u32) -> bool {
        let adjacent_coords: Array<(u32, u32)> = point.get_adjacent_coords(board_size);
        let mut is_self_capture = true;
        let mut index: u32 = 0;
        loop {
            if index == adjacent_coords.len() {
                break;
            };
            let (x, y) = *adjacent_coords.at(index);
            let adjacent_point = get!(ctx.world, (point.game_id, x, y), (Point));
            match adjacent_point.owned_by {
                Option::Some(owner) => {
                    if owner == color {
                        is_self_capture = false;
                        break;
                    }
                },
                Option::None(_) => {
                    is_self_capture = false;
                    break;
                }
            };

            index += 1;
        };

        is_self_capture
    }

    fn is_ko(ctx: Context, point: Point, color: Color, board_size: u32) -> bool {
        let mut is_ko = true;

        // implement ko rule check
        is_ko
    }
}

#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::test_utils::spawn_test_world;
    use go::components::{Game, game, GameTurn, game_turn, Point, point, Color};

    use go::systems::initiate_system;
    use go::systems::place_stone_system;
    use go::systems::change_turn_system;
    use go::systems::capture_system;
    use array::ArrayTrait;
    use core::traits::Into;
    use dojo::world::IWorldDispatcherTrait;
    use core::array::SpanTrait;
    use core::pedersen::{pedersen};

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
        systems.append(change_turn_system::TEST_CLASS_HASH);
        let world = spawn_test_world(components, systems);

        // initiate
        let mut calldata = array::ArrayTrait::<core::felt252>::new();
        calldata.append(white.into());
        calldata.append(black.into());
        calldata.append(board_size.into());
        world.execute('initiate_system'.into(), calldata);

        let game_id = pedersen(white.into(), black.into());

        // Place white stone in [0,1]
        let mut place_stone_calldata = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata.append(0);
        place_stone_calldata.append(1);
        place_stone_calldata.append(white.into());
        place_stone_calldata.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata);

        //White stone is in (3,3)
        let point = get!(world, (game_id, 0, 1), (Point));
        match point.owned_by {
            Option::Some(owner) => {
                assert(owner == Color::White, '[0,1] should be owned by white');
            },
            Option::None(_) => assert(false, 'should have stone in [0,1]'),
        };

        // Change turn to Black
        let mut change_turn_calldata = array::ArrayTrait::<core::felt252>::new();
        change_turn_calldata.append(white.into());
        change_turn_calldata.append(game_id);
        world.execute('change_turn_system'.into(), change_turn_calldata);

        //It's Black's turn now
        let game_turn = get!(world, (game_id), (GameTurn));
        match game_turn.turn {
            Color::White => assert(false, 'should be Black turn'),
            Color::Black => {
                assert(true, 'Should be Black turn');
            },
        };

        //Place Black stone in [4,3]
        let mut place_stone_calldata_2 = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata_2.append(4);
        place_stone_calldata_2.append(3);
        place_stone_calldata_2.append(black.into());
        place_stone_calldata_2.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata_2);

        //Check Black stone in [4,3]
        let point_2 = get!(world, (game_id, 4, 3), (Point));
        match point_2.owned_by {
            Option::Some(owner) => {
                assert(owner == Color::Black, '[4,3] should be owned by black');
            },
            Option::None(_) => assert(false, 'should have stone in [4,3]'),
        };

        // Change turn to White
        let mut change_turn_calldata = array::ArrayTrait::<core::felt252>::new();
        change_turn_calldata.append(black.into());
        change_turn_calldata.append(game_id);
        world.execute('change_turn_system'.into(), change_turn_calldata);

        //It's White's turn again
        let game_turn = get!(world, (game_id), (GameTurn));
        match game_turn.turn {
            Color::White => assert(true, 'should be white turn'),
            Color::Black => {
                assert(false, 'Should be white turn');
            },
        };

        // Place white stone in [1,0]
        let mut place_stone_calldata = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata.append(1);
        place_stone_calldata.append(0);
        place_stone_calldata.append(white.into());
        place_stone_calldata.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata);

        // Change turn to Black
        let mut change_turn_calldata = array::ArrayTrait::<core::felt252>::new();
        change_turn_calldata.append(white.into());
        change_turn_calldata.append(game_id);
        world.execute('change_turn_system'.into(), change_turn_calldata);

        //Place Black stone in [0,0]
        let mut place_stone_calldata_2 = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata_2.append(5);
        place_stone_calldata_2.append(5);
        place_stone_calldata_2.append(black.into());
        place_stone_calldata_2.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata_2);

        //Check Black stone in [0,0] is empty due to no-self-capture rule
        let point_2 = get!(world, (game_id, 0, 0), (Point));
        match point_2.owned_by {
            Option::Some(owner) => {
                assert(false, '[0,0] should not be owned');
            },
            Option::None(_) => assert(true, 'should not have stone in 0,0'),
        };
    }
}
