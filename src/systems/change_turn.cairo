#[system]
mod change_turn_system {
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{GameTurn, Color, Game};

    fn execute(ctx: Context, caller: ContractAddress, game_id: felt252) {
        let mut game = get!(ctx.world, (game_id), (Game));
        let mut game_turn = get!(ctx.world, (game_id), (GameTurn));

        assert(is_correct_turn(caller, ref game_turn, ref game), 'Not correct turn');

        match game_turn.turn {
            Color::White => {
                set!(ctx.world, (GameTurn { game_id: game_id, turn: Color::Black(()) }));
            },
            Color::Black => {
                set!(ctx.world, (GameTurn { game_id: game_id, turn: Color::White(()) }));
            }
        };
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
}
