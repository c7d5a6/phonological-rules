pub const LexerError = error{
    WrongPlaceForDiacritic,
    WrongPlaceForWhitespace,
    EndAfterAffricate,
    UnexpectedSymbol,
};
