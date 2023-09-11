#[system]
mod change_turn_system {
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Game, GameTurn, Color, Point};

    fn execute(ctx: Context, caller: ContractAddress, game_id: felt252) {
        let game_turn = get!(ctx.world, (game_id), (GameTurn));

        match game_turn.turn {
            Color::White => {
                set!(ctx.world, (GameTurn { game_id: game_id, turn: Color::Black(()) }));
            },
            Color::Black => {
                set!(ctx.world, (GameTurn { game_id: game_id, turn: Color::White(()) }));
            }
        };
    }
}