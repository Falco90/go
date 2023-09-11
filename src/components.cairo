use debug::PrintTrait;
use starknet::ContractAddress;

#[derive(Component, Drop, SerdeLen, Serde)]
struct Point {
    #[key]
    game_id: felt252,
    #[key]
    x: u32,
    #[key]
    y: u32,
    owned_by: Option<Color>
}

#[derive(Component, Drop, Serde,  PartialEq)]
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
    black: ContractAddress
}

#[derive(Component, Drop, Serde, SerdeLen)]
struct GameTurn {
    #[key]
    game_id: felt252,
    turn: Color
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