#[system]
mod give_komi_system {
    use dojo::world::Context;
    use go::components::{Score, Color};


    fn execute(ctx: Context, game_id: felt252, amount: u32) {
        let prev_score = get!(ctx.world, (game_id, Color::White), (Score));
        set!(
            ctx.world,
            (Score {
                game_id: game_id,
                color: Color::White,
                territories: prev_score.territories,
                prisoners: prev_score.prisoners,
                komi: amount
            })
        )
    }
}
