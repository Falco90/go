#[system]
mod pass_system {
    use dojo::world::Context;
    use starknet::ContractAddress;
    use go::components::{Score, Color, LastMove, Game};


    fn execute(ctx: Context, game_id: felt252, caller: ContractAddress) {
        let game = get!(ctx.world, (game_id), (Game));
        let mut color = Color::Black;

        if game.white == caller {
            color = Color::White;
        }

        match color {
            Color::White => {
                let prev_score_opponent = get!(ctx.world, (game_id, Color::Black), (Score));
                let current_prisoners = prev_score_opponent.prisoners;
                set!(
                    ctx.world,
                    (
                        LastMove {
                            game_id: game_id, color: color, coords: Option::None, passed: true
                        },
                        Score {
                            game_id: game_id,
                            color: Color::Black,
                            territories: prev_score_opponent.territories,
                            prisoners: current_prisoners + 1,
                            komi: prev_score_opponent.komi
                        }
                    )
                );
            },
            Color::Black => {
                let prev_score_opponent = get!(ctx.world, (game_id, Color::White), (Score));
                let current_prisoners = prev_score_opponent.prisoners;
                set!(
                    ctx.world,
                    (
                        LastMove {
                            game_id: game_id, color: color, coords: Option::None, passed: true
                        },
                        Score {
                            game_id: game_id,
                            color: Color::White,
                            territories: prev_score_opponent.territories,
                            prisoners: current_prisoners + 1,
                            komi: prev_score_opponent.komi
                        }
                    )
                );
            }
        };
    }
}
