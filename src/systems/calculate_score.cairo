#[system]
mod calculate_score_system {
    use dojo::world::Context;
    use go::components::{Color, Point, PointTrait, Game};
    use debug::PrintTrait;

    fn execute(ctx: Context, game_id: felt252, color: Color) {
        //Final score is territories +  prisoners + extras
        let game: Game = get!(ctx.world, (game_id), (Game));
        let mut x: u32 = 0;
        let mut y: u32 = 0;

        let mut visited: Felt252Dict<u8> = Default::default();
        let mut territory_count: u32 = 0;
        loop {
            if y == game.board_size {
                break;
            }
            loop {
                if x == game.board_size {
                    break;
                };
                let point = get!(ctx.world, (game_id, x, y), (Point));
                match point.owned_by {
                    Option::Some(owner) => {
                        let adjacent_coords = point.get_adjacent_coords(game.board_size);

                        let mut index: u32 = 0;
                        loop {
                            if index == adjacent_coords.len() {
                                break;
                            };
                            let (x, y) = *adjacent_coords.at(index);
                            let adjacent_point = get!(ctx.world, (point.game_id, x, y), (Point));
                            let adjacent_point_id = adjacent_point.create_unique_identifier();
                            match adjacent_point.owned_by {
                                Option::Some(_) => {},
                                Option::None(_) => {
                                    let already_visited = visited.get(adjacent_point_id) == 1;
                                    if !already_visited {
                                        territory_count +=
                                            calculate_territory(
                                                ctx,
                                                adjacent_point,
                                                game.board_size,
                                                color,
                                                ref visited
                                            );
                                    }
                                }
                            };
                            index += 1;
                        };
                    },
                    Option::None(_) => {}
                };
                x += 1;
            };
            y += 1;
        };

        territory_count.print();
    }

    fn calculate_territory(
        ctx: Context, point: Point, board_size: u32, color: Color, ref visited: Felt252Dict<u8>
    ) -> u32 {
        let id = point.create_unique_identifier();
        visited.insert(id, 1);

        let adjacent_coords: Array<(u32, u32)> = point.get_adjacent_coords(board_size);
        let mut index: u32 = 0;

        let mut territory_size: u32 = 0;

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
                    break;
                },
                Option::None(_) => {
                    if !already_visited {
                        territory_size += 1;
                        territory_size +=
                            calculate_territory(
                                ctx, adjacent_point, board_size, color, ref visited
                            );
                    }
                }
            };
            visited.insert(adjacent_point_id, 1);
            index += 1;
        };

        territory_size
    }
}
