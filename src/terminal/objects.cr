require "../game/game"

module Terminal
  class Card
    property card : Game::Card
    property hidden : Bool

    def initialize(@card, @hidden = false)
    end

    def to_ascii : Array(String)
      return hidden_ascii if @hidden

      rank_display = @card.rank
      rank_display = rank_display.rjust(2) if rank_display.size < 2

      suit_color = case @card.suit
                   when "♥", "♦" then Terminal::RED
                   else               Terminal::BLACK
                   end

      [
        "┌─────┐",
        "│#{rank_display}   │",
        "│  #{suit_color}#{@card.suit}#{Terminal::RESET}  │",
        "│   #{rank_display}│",
        "└─────┘",
      ]
    end

    def hidden_ascii : Array(String)
      [
        "┌─────┐",
        "│░░░░░│",
        "│░░░░░│",
        "│░░░░░│",
        "└─────┘",
      ]
    end

    def to_s : String
      return "???" if @hidden

      color = case @card.suit
              when "♥", "♦" then Terminal::RED
              when "♠", "♣" then Terminal::BLACK
              else               Terminal::WHITE
              end

      "#{color}#{@card.rank}#{@card.suit}#{Terminal::RESET}"
    end

    def to_s(io : IO) : Nil
      io << to_s
    end
  end

  class Hand
    property hand : Game::Hand
    property hidden_index : Int32

    def initialize(@hand, @hidden_index = -1)
    end

    def to_ascii : String
      card_visuals = @hand.cards.map_with_index do |card, idx|
        Card.new(card, idx == @hidden_index).to_ascii
      end

      result = ""
      5.times do |row|
        line = card_visuals.map { |c| c[row] }.join(" ")
        result += line + "\n"
      end

      result
    end

    def to_s : String
      @hand.cards.map_with_index do |card, idx|
        if idx == @hidden_index
          "???"
        else
          color = case card.suit
                  when "♥", "♦" then Terminal::RED
                  when "♠", "♣" then Terminal::BLACK
                  else               Terminal::WHITE
                  end

          "#{color}#{card.rank}#{card.suit}#{Terminal::RESET}"
        end
      end.join(" ")
    end

    def to_s(io : IO) : Nil
      io << to_s
    end
  end
end
