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

#[generate_trait]
impl PointTraitImpl of PointTrait {
    fn get_adjacent_coords(self: Point, board_size: u32) -> Array<(u32, u32)> {
        let mut adjacent_coords = ArrayTrait::<(u32, u32)>::new();

        if self.x + 1 < board_size {
            adjacent_coords.append((self.x + 1, self.y));
        }
        if self.x > 0 {
            adjacent_coords.append((self.x - 1, self.y));
        }
        if self.y + 1 < board_size {
            adjacent_coords.append((self.x, self.y + 1));
        }
        if self.y > 0 {
            adjacent_coords.append((self.x, self.y - 1));
        }

        adjacent_coords
    }

    fn create_unique_identifier(self: Point) -> felt252 {
        ((self.x + self.y) * (self.x + self.y + 1) / 2 + self.y).into()
    }
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

#[derive(Component, Drop, Serde, SerdeLen)]
struct LastMove {
    #[key]
    game_id: felt252,
    #[key]
    color: Color,
    x: u32,
    y: u32
}

#[derive(Component, Drop, Serde, SerdeLen)]
struct Passes {
    #[key]
    game_id: felt252,
    #[key]
    color: Color,
    consecutive_passes: u32
}

#[derive(Component, Drop, Serde, SerdeLen)]
struct Score {
    #[key]
    game_id: felt252,
    #[key]
    color: Color,
    territories: u32,
    prisoners: u32,
    komi: u32
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
