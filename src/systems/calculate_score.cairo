#[system]
mod calculate_score_system {
    use dojo::world::Context;
    use go::components::{Color, Point};

    fn execute(ctx: Context, color: Color) {
        //Final score is territories + prisoners + extras

    }

    fn calculate_territory(ctx: Context, board_size: u32, color: Color, ref visited: Felt252Dict<u8>) {

    }


}