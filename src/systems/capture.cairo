//Check if the placed stone triggers a capture by checking if the adjacent string has any room left.
#[system]
mod capture_system {
    use go::components::PointTrait;
    use core::traits::TryInto;
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point};
    use debug::PrintTrait;
    use array::ArrayTrait;
    use dict::Felt252DictTrait;
    use nullable::{nullable_from_box, match_nullable, FromNullableResult};


    fn execute(ctx: Context, game_id: felt252, x: u32, y: u32, caller: ContractAddress) {
        let game: Game = get!(ctx.world, (game_id), (Game));
        let mut opponent: Color = Color::White;

        if caller == game.white {
            opponent = Color::Black;
        }

        let point = get!(ctx.world, (game_id, x, y), (Point));

        let adjacent_coords = point.get_adjacent_coords(game.board_size);
        let mut index: u32 = 0;

        loop {
            if index == adjacent_coords.len() {
                break;
            };
            let (x, y) = *adjacent_coords.at(index);
            let adjacent_point = get!(ctx.world, (game_id, x, y), (Point));
            let mut visited: Felt252Dict<u8> = Default::default();
            if !has_liberties(adjacent_point, ctx, game.board_size, opponent, ref visited) {
                capture(adjacent_point, ctx, game.board_size, opponent, ref visited);
            };

            index += 1;
        };
    }

    fn has_liberties(
        point: Point, ctx: Context, board_size: u32, opponent: Color, ref visited: Felt252Dict<u8>
    ) -> bool {
        let id = point.create_unique_identifier();
        visited.insert(id, 1);

        let adjacent_coords: Array<(u32, u32)> = point.get_adjacent_coords(board_size);
        let mut has_liberties: bool = false;
        let mut index: u32 = 0;

        loop {
            if index == adjacent_coords.len() {
                break;
            };

            let (x, y) = *adjacent_coords.at(index);
            let adjacent_point = get!(ctx.world, (point.game_id, x, y), (Point));
            let adjacent_point_id = adjacent_point.create_unique_identifier();

            let already_visited = visited.get(adjacent_point_id) == 1;

            match adjacent_point.owned_by {
                Option::Some(owner) => {
                    if owner == opponent && !already_visited {
                        if has_liberties(adjacent_point, ctx, board_size, opponent, ref visited) {
                            has_liberties = true;
                            break;
                        };
                    };
                },
                Option::None(_) => {
                    has_liberties = true;
                    break;
                }
            }
            visited.insert(adjacent_point_id, 1);
            index += 1;
        };

        has_liberties
    }

    fn capture(
        point: Point, ctx: Context, board_size: u32, opponent: Color, ref visited: Felt252Dict<u8>
    ) {
        let id = point.create_unique_identifier();
        visited.insert(id, 1);

        set!(
            ctx.world,
            (Point { game_id: point.game_id, x: point.x, y: point.y, owned_by: Option::None(()) })
        );

        let adjacent_coords: Array<(u32, u32)> = point.get_adjacent_coords(board_size);
        let mut index: u32 = 0;

        loop {
            if index == adjacent_coords.len() {
                break;
            };

            let (x, y) = *adjacent_coords.at(index);
            let adjacent_point = get!(ctx.world, (point.game_id, x, y), (Point));
            let adjacent_point_id = adjacent_point.create_unique_identifier();

            let already_visited = visited.get(adjacent_point_id) == 1;

            match adjacent_point.owned_by {
                Option::Some(owner) => {
                    if owner == opponent && !already_visited {
                        capture(adjacent_point, ctx, board_size, opponent, ref visited);
                    };
                },
                Option::None(_) => {}
            }
            visited.insert(adjacent_point_id, 1);
            index += 1;
        };
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
        systems.append(capture_system::TEST_CLASS_HASH);
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

        //White stone is in (0,1)
        let point = get!(world, (game_id, 0, 1), (Point));
        match point.owned_by {
            Option::Some(owner) => {
                assert(owner == Color::White, '[3,3] should be owned by white');
            },
            Option::None(_) => assert(false, 'should have stone in [3,3]'),
        };

        //Check if any adjacent stones to [0,1] can get captured
        let mut capture_calldata = array::ArrayTrait::<core::felt252>::new();
        capture_calldata.append(game_id);
        capture_calldata.append(0);
        capture_calldata.append(1);
        capture_calldata.append(white.into());
        world.execute('capture_system'.into(), capture_calldata);

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

        //Place Black stone in [0,0]
        let mut place_stone_calldata_2 = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata_2.append(0);
        place_stone_calldata_2.append(0);
        place_stone_calldata_2.append(black.into());
        place_stone_calldata_2.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata_2);

        //Check Black stone in [0,0]
        let point_2 = get!(world, (game_id, 0, 0), (Point));
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

        //White places stone in [1,0]
        let mut place_stone_calldata = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata.append(1);
        place_stone_calldata.append(0);
        place_stone_calldata.append(white.into());
        place_stone_calldata.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata);

        //Check if adjacent stones to [1,0] can get captured
        let mut capture_calldata_2 = array::ArrayTrait::<core::felt252>::new();
        capture_calldata_2.append(game_id);
        capture_calldata_2.append(1);
        capture_calldata_2.append(0);
        capture_calldata_2.append(white.into());
        world.execute('capture_system'.into(), capture_calldata_2);

        //Check if stone in [0,0] gets captured by white
        let point_to_capture = get!(world, (game_id, 0, 0), (Point));
        match point_to_capture.owned_by {
            Option::Some(owner) => {
                assert(false, '[0,0] should not have owner');
            },
            Option::None(_) => assert(true, 'should not have stone in [0,0]')
        };
    }
}
