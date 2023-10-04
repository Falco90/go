use debug::PrintTrait;
use array::ArrayTrait;
use starknet::ContractAddress;

#[derive(Component, Copy, Drop, SerdeLen, Serde)]
struct Point {
    #[key]
    game_id: felt252,
    #[key]
    x: u32,
    #[key]
    y: u32,
    owned_by: Option<Color>
}

#[derive(Component, Copy, Drop, Serde, PartialEq)]
enum Color {
    White,
    Black
}

#[derive(Component, Drop, Serde, SerdeLen)]
struct Game {
    #[key]
    game_id: felt252,
    winner: Option<Color>,
    white: ContractAddress,
    black: ContractAddress,
    board_size: u32,
}

#[derive(Component, Drop, Serde, SerdeLen)]
struct GameTurn {
    #[key]
    game_id: felt252,
    turn: Color
}

#[generate_trait]
impl PointTraitImpl of PointTrait {
    fn has_liberties(self: Point) -> bool {
        // check for x + 1, x - 1, y + 1 and y - 1 if the space is empty.
        let point_left = get!(ctx.world, (self.game_id, self.x - 1, self.y), (Point));
        if point_left.owned_by == Option::<Color>::None {
            return true;
        };

        let point_right = get!(ctx.world, (self.game_id, self.x + 1, self.y), (Point));
        if point_left.owned_by == Option::<Color>::None {
            return true;
        };

        let point_top = get!(ctx.world, (self.game_id, self.x, self.y + 1), (Point));
        if point_top.owned_by == Option::<Color>::None {
            return true;
        };

        let point_bottom = get!(ctx.world, (self.game_id, self.x, self.y - 1), (Point));
        if point_bottom.owned_by == Option::<Color>::None {
            return true;
        };

        false
    }
}

impl ColorOptionSerdeLen of dojo::SerdeLen<Option<Color>> {
    #[inline(always)]
    fn len() -> usize {
        2
    }
}

impl ColorSerdeLen of dojo::SerdeLen<Color> {
    #[inline(always)]
    fn len() -> usize {
        1
    }
}

impl ColorPrintTrait of PrintTrait<Color> {
    #[inline(always)]
    fn print(self: Color) {
        match self {
            Color::White(_) => {
                'White'.print();
            },
            Color::Black(_) => {
                'Black'.print();
            },
        }
    }
}

impl ColorOptionPrintTrait of PrintTrait<Option<Color>> {
    #[inline(always)]
    fn print(self: Option<Color>) {
        match self {
            Option::Some(color) => {
                color.print();
            },
            Option::None(_) => {
                'None'.print();
            }
        }
    }
}
