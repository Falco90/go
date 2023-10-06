//Check if the placed stone triggers a capture by checking if the adjacent string has any room left.
#[system]
mod check_capture_system {
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
        //Check for points left, right, top and bottom to see if they have liberties. Call has_liberties(point_right) etc..
        //If not, check if the stones near them with the same color have liberties.
        //Repeat for all the connected stones
        //If none of the connected stones of the same color have liberties. Capture all of them -> remove them from the board and add points
        let game: Game = get!(ctx.world, (game_id), (Game));
        let mut opponent: Color = Color::White;

        if caller == game.white {
            opponent = Color::Black;
        }

        // Point to the right
        let point_right: Point = get!(ctx.world, (game_id, x + 1, y), (Point));

        match point_right.owned_by {
            Option::Some(owner) => {
                if owner == opponent && !has_liberties(point_right, ctx, game_id, game.board_size) {
                    // if all connected points are checked and none of them have liberties, capture
                    //Keep track of things to capture
                    let mut prisoners: Felt252Dict<Nullable<Point>> = Default::default();
                    //create stack for recursive algoritm
                    let mut stack: Array<Point> = ArrayTrait::<Point>::new();

                    let mut index: u32 = 0;

                    let mut point: Point = get!(
                        ctx.world, (game_id, point_right.x + 1, point_right.y), (Point)
                    );

                    //loop through the stack.
                    loop {
                        match stack.pop_front() {
                            Option::Some(point) => {
                                if has_liberties(point, ctx, game_id, game.board_size) {
                                    break;
                                }
                                let new_point = get!(
                                    ctx.world, (game_id, point.x + 1, point.y), (Point)
                                );
                                match new_point.owned_by {
                                    Option::Some(owner) => {
                                        if owner == opponent {
                                            stack.append(point);
                                        }
                                    },
                                    Option::None(_) => {
                                        break;
                                    }
                                }
                            },
                            Option::None(_) => {
                                break;
                            }
                        }

                        stack.append(point);
                        prisoners.insert(index.into(), nullable_from_box(BoxTrait::new(point)));
                    }
                }
            },
            Option::None(_) => {}
        }

        if !has_liberties(point_right, ctx, game_id, game.board_size) {
            match point_right.owned_by {
                Option::Some(owner) => {
                    match owner {
                        Color::White => {},
                        Color::Black => {
                            set!(
                                ctx.world,
                                (Point {
                                    game_id: game_id,
                                    x: x + 1,
                                    y: y,
                                    owned_by: Option::Some(Color::White(()))
                                })
                            );
                        },
                    }
                },
                Option::None(_) => {}
            };
        }
    }

    fn has_liberties(self: Point, ctx: Context, game_id: felt252, board_size: u32) -> bool {
        let adjacent_coords: Array<(u32, u32)> = self.get_adjacent_coords();
        let mut has_liberties: bool = false;
        let mut index: u32 = 0;

        loop {
            if index == adjacent_coords.len() {
                break;
            };

            let (x, y) = *adjacent_coords.at(index);
            let point = get!(ctx.world, (self.game_id, x, y), (Point));

            if point.owned_by == Option::<Color>::None {
                has_liberties = true;
                break;
            };

            index += 1;
        };

        has_liberties
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
    use go::systems::check_capture_system;
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
        systems.append(check_capture_system::TEST_CLASS_HASH);
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

        // Change turn to Black
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

        //Check the adjacent stones to (3,3)
        let mut check_capture_calldata = array::ArrayTrait::<core::felt252>::new();
        check_capture_calldata.append(game_id);
        check_capture_calldata.append(3);
        check_capture_calldata.append(3);
        check_capture_calldata.append(white.into());
        world.execute('check_capture_system'.into(), check_capture_calldata);

        //Check if stone in [4,3] is captured by white
        let point_3 = get!(world, (game_id, 4, 3), (Point));
        match point_3.owned_by {
            Option::Some(owner) => {
                assert(owner == Color::White, '[4,3] should be white now');
            },
            Option::None(_) => assert(false, 'should have stone in [4,3]')
        };

        //Check if stone in [2,3] does not get captured by white
        let point_4 = get!(world, (game_id, 2, 3), (Point));
        match point_4.owned_by {
            Option::Some(owner) => {
                assert(false, '[2,3] should not have owner');
            },
            Option::None(_) => assert(true, 'should not have stone in [2,3]')
        };

        //Check if stone in [3,4] does not get captured by white
        let point_top = get!(world, (game_id, 3, 4), (Point));
        match point_top.owned_by {
            Option::Some(owner) => {
                assert(false, '[3,4] should not have owner');
            },
            Option::None(_) => assert(true, 'should not have stone in [2,3]')
        };

        //Check if stone in [3,2] does not get captured by white
        let point_bottom = get!(world, (game_id, 3, 2), (Point));
        match point_bottom.owned_by {
            Option::Some(owner) => {
                assert(false, '[3,2] should not have owner');
            },
            Option::None(_) => assert(true, 'should not have stone in [3,2]')
        };
    }
}
