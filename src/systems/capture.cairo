#[system]
mod capture_system {
    use go::components::PointTrait;
    use core::traits::TryInto;
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point, Score};
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
                let captured_amount = capture(
                    adjacent_point, ctx, game.board_size, opponent, ref visited
                );
                update_prisoners_score(ctx, opponent, game_id, captured_amount);
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
    ) -> u32 {
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

        let captured_amount = index - 1;

        captured_amount
    }

    fn update_prisoners_score(ctx: Context, opponent: Color, game_id: felt252, amount: u32) {
        let mut color = Color::Black;

        if opponent == Color::Black {
            color = Color::White;
        }
        let prev_score = get!(ctx.world, (game_id, color), (Score));

        set!(
            ctx.world,
            (Score {
                game_id: game_id,
                color: color,
                territories: prev_score.territories,
                prisoners: prev_score.prisoners + amount,
                komi: prev_score.komi
            })
        )
    }
}

#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::test_utils::spawn_test_world;
    use go::components::{Game, game, GameTurn, game_turn, Point, point, Color, Score, score};

    use go::systems::initiate_system;
    use go::systems::place_stone_system;
    use go::systems::change_turn_system;
    use go::systems::capture_system;
    use go::systems::calculate_score_system;
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
        components.append(score::TEST_CLASS_HASH);

        //systems
        let mut systems = array::ArrayTrait::new();
        systems.append(initiate_system::TEST_CLASS_HASH);
        systems.append(place_stone_system::TEST_CLASS_HASH);
        systems.append(change_turn_system::TEST_CLASS_HASH);
        systems.append(capture_system::TEST_CLASS_HASH);
        systems.append(calculate_score_system::TEST_CLASS_HASH);
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

        // Change turn to Black
        let mut change_turn_calldata = array::ArrayTrait::<core::felt252>::new();
        change_turn_calldata.append(white.into());
        change_turn_calldata.append(game_id);
        world.execute('change_turn_system'.into(), change_turn_calldata);

        //Place Black stone in [0,0]
        let mut place_stone_calldata_2 = array::ArrayTrait::<core::felt252>::new();
        place_stone_calldata_2.append(0);
        place_stone_calldata_2.append(0);
        place_stone_calldata_2.append(black.into());
        place_stone_calldata_2.append(game_id);
        world.execute('place_stone_system'.into(), place_stone_calldata_2);

        // Change turn to White
        let mut change_turn_calldata = array::ArrayTrait::<core::felt252>::new();
        change_turn_calldata.append(black.into());
        change_turn_calldata.append(game_id);
        world.execute('change_turn_system'.into(), change_turn_calldata);

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

        //Check if stone in [0,0] got captured by white
        let point_to_capture = get!(world, (game_id, 0, 0), (Point));
        match point_to_capture.owned_by {
            Option::Some(owner) => {
                assert(false, '[0,0] should not have owner');
            },
            Option::None(_) => assert(true, 'should not have stone in [0,0]')
        };

        //Check if white score increased by correct amount
        let score: Score = get!(world, (game_id, Color::White), (Score));
        assert(score.prisoners == 1, 'should have captured one stone');

        //calculate territories
        let mut calculate_score_calldata = array::ArrayTrait::<core::felt252>::new();
        calculate_score_calldata.append(game_id);
        calculate_score_calldata.append(white.into());
        world.execute('calculate_score_system'.into(), calculate_score_calldata);
    }
}
