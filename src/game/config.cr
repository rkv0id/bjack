module Game
  struct Config
    # Add UI configuration options
    property ui_mode : Symbol = :normal     # :compact or :normal
    property use_colors : Bool = true       # Use ANSI colors
    property use_ascii_cards : Bool = true  # Use ASCII art for cards
    property single_key_input : Bool = true # Allow single key input without Enter
    property clear_screen : Bool = true     # Clear screen between rounds

    # Keep the original properties
    property cash : Int32 = 300
    property min_bet : Int32 = 10
    property max_bet : Int32 = 500
    property num_decks : Int8 = 6
    property num_side_bets : Int8 = 3
    property blackjack_pay : String = "3:2"
    property peek : Bool = true
    property hit_soft17 : Bool = false
    property insurance : Bool = false
    property surrender : Bool = false
    property double_split : Bool = false
    property max_splits : Int8 = 3
  end
end
