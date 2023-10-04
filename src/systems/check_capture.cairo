//Check if the placed stone triggers a capture by checking if the adjacent string has any room left.
#[system]
mod check_capture_system {
    use core::traits::TryInto;
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point};
    use debug::PrintTrait;


    fn execute(ctx: Context, game_id: felt252, x: u32, y: u32, caller: ContractAddress) {
        // Point is the point that the player just placed a stone upon. Check the adjacent points of this Point to check if there are stones.

        // Point to the right
        let new_x_r = x + 1;
        let point_right: Point = get!(ctx.world, (game_id, new_x_r, y), (Point));

        match point_right.owned_by {
            Option::Some(owner) => {
                match owner {
                    Color::White => {},
                    Color::Black => {
                        set!(
                            ctx.world,
                            (Point {
                                game_id: game_id,
                                x: new_x_r,
                                y: y,
                                owned_by: Option::Some(Color::White(()))
                            })
                        );
                    },
                }
            },
            Option::None(_) => {}
        };

        // Point to the left
        let new_x_l = x - 1;
        let point_left: Point = get!(ctx.world, (game_id, new_x_l, y), (Point));
    }
}
