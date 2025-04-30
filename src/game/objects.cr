module Game
  struct Card
    RANKS = %w[A 2 3 4 5 6 7 8 9 10 J Q K]
    SUITS = ["♠", "♥", "♦", "♣"]

    getter rank : String
    getter suit : String

    def initialize(@rank : String, @suit : String)
    end

    def value : Array(Int32)
      case @rank
      when "A"
        [1, 11]
      when "J", "Q", "K"
        [10]
      else
        [@rank.to_i]
      end
    end

    def rank_index : Int8
      RANKS.index!(@rank).to_i8!
    end

    def to_s : String
      "#{@rank}#{@suit}"
    end

    def to_s(io : IO) : Nil
      io << @rank << @suit
    end

    def self.is_straight(cards : Array(Card)) : Bool
      indices = cards.map(&.rank_index)
      indices.each_cons_pair.all? { |a, b| (b - a) % RANKS.size == 1 }
    end

    def self.is_three_of_a_kind(cards : Array(Card)) : Bool
      cards.map(&.rank).uniq.size == 1
    end

    def self.is_flush(cards : Array(Card)) : Bool
      cards.map(&.suit).uniq.size == 1
    end
  end

  class Deck
    def initialize(num_decks : Int32)
      @cards = [] of Card
      populate_deck(num_decks)
      shuffle!
    end

    private def populate_deck(num_decks : Int32) : Nil
      num_decks.times do
        Card::RANKS.each do |rank|
          Card::SUITS.each do |suit|
            @cards << Card.new(rank, suit)
          end
        end
      end
    end

    def shuffle! : Nil
      @cards.shuffle!
    end

    def draw : Card
      shuffle! if @cards.empty?
      @cards.shift
    end

    def size : Int32
      @cards.size
    end
  end

  class Hand
    getter cards : Array(Card)
    property bet : Int32

    def initialize(@cards = [] of Card, @bet = 0)
    end

    def add(card : Card) : Nil
      @cards << card
    end

    # Calculate all possible hand values
    def values : Array(Int32)
      sums = [0]
      @cards.each do |card|
        new_sums = [] of Int32
        card.value.each do |val|
          sums.each { |s| new_sums << s + val }
        end
        sums = new_sums
      end
      sums.uniq.sort
    end

    # Get the best valid total (<=21 if possible)
    def best_total : Int32
      valid = values.select { |v| v <= 21 }
      valid.empty? ? values.min : valid.max
    end

    def blackjack? : Bool
      @cards.size == 2 && values.includes?(21)
    end

    def bust? : Bool
      best_total > 21
    end

    # Check if the hand has a soft total (Ace counting as 11)
    def soft? : Bool
      return false if @cards.empty?
      has_ace = @cards.any? { |c| c.rank == "A" }
      return false unless has_ace

      values.any? { |v| v <= 21 && v > best_total - 10 }
    end

    def can_split? : Bool
      @cards.size == 2 && @cards[0].rank == @cards[1].rank
    end

    def is_pair : Bool
      can_split?
    end

    def is_suited : Bool
      @cards.size == 2 && cards[0].suit == cards[1].suit
    end

    def to_s : String
      @cards.map(&.to_s).join(" ")
    end

    def to_s(io : IO) : Nil
      @cards.each_with_index do |card, idx|
        card.to_s(io)
        io << ' ' if idx < @cards.size - 1
      end
    end
  end

  struct SideBet
    getter name : String
    getter desc : String
    getter ratio : Tuple(Int32, Int32)
    getter type : Symbol

    def initialize(@name, @ratio, @desc, @type)
    end

    def evaluate(player_hand : Hand, dealer_hand : Hand) : Bool
      SideBetEvaluator.evaluate(@type, player_hand, dealer_hand)
    end

    def describe : String
      "#{@name} - #{ratio_string} - #{@desc}"
    end

    def ratio_string : String
      "#{@ratio[0]}:#{@ratio[1]}"
    end

    def payout(bet_amount : Int32) : Int32
      (@ratio[0] * bet_amount / @ratio[1]).to_i
    end
  end

  module SideBetEvaluator
    extend self

    def evaluate(type : Symbol, player_hand : Hand, dealer_hand : Hand) : Bool
      case type
      when :mixed_pairs
        player_hand.is_pair && !player_hand.is_suited
      when :perfect_pairs
        player_hand.is_pair && player_hand.is_suited
      when :twenty_one_plus_three
        cards = player_hand.cards[0..1] + [dealer_hand.cards[0]]
        Card.is_flush(cards) || Card.is_straight(cards) || Card.is_three_of_a_kind(cards)
      when :royal_match
        player_hand.is_suited
      when :super_sevens
        player_hand.cards.any? { |c| c.rank == "7" }
      when :lucky_lucky
        total_hand = Hand.new(player_hand.cards + dealer_hand.cards.first(1))
        total_hand.values.any? { |val| [19, 20, 21, 22].includes?(val) }
      when :in_between
        player_ranks = player_hand.cards.map(&.rank_index).sort
        dealer_rank = dealer_hand.cards[0].rank_index
        player_ranks[0] < dealer_rank && dealer_rank < player_ranks[1]
      when :suited_blackjack
        player_hand.blackjack? && player_hand.is_suited
      when :first_card_ace
        player_hand.cards[0].rank == "A"
      when :unlucky_eights
        player_hand.cards.size == 2 && player_hand.cards.all? { |c| c.rank == "8" }
      when :king_of_hearts
        player_hand.cards.any? { |c| c.rank == "K" && c.suit == "♥" }
      when :total_exactly_21
        player_hand.best_total == 21
      when :jackpot_jack
        player_hand.cards.any? { |c| c.rank == "J" && c.suit == "♠" }
      when :queen_of_diamonds
        player_hand.cards.any? { |c| c.rank == "Q" && c.suit == "♦" }
      when :jokers_wild
        player_hand.cards.size == 2 && player_hand.cards.map(&.rank).sort == ["J", "J"]
      when :lucky_thirteen
        player_hand.values.includes?(13)
      when :two_faced
        face_ranks = ["J", "Q", "K"]
        player_hand.cards.size == 2 && player_hand.cards.all? { |c| face_ranks.includes?(c.rank) }
      else
        false
      end
    end
  end

  # Side bet catalog
  module SideBetFactory
    extend self

    SIDE_BET_SPECS = [
      {:mixed_pairs, "Mixed Pairs", {3, 1}, "Your two cards are a mixed pair"},
      {:perfect_pairs, "Perfect Pairs", {10, 1}, "Your two cards are a perfect pair"},
      {:twenty_one_plus_three, "21+3", {6, 1}, "Your first two + dealer's upcard form a flush, straight, or three-of-a-kind"},
      {:royal_match, "Royal Match", {3, 1}, "Your first two cards are suited"},
      {:super_sevens, "Super Sevens", {3, 1}, "You have at least one 7"},
      {:lucky_lucky, "Lucky Lucky", {4, 1}, "Your two cards plus dealer's upcard total 19-22"},
      {:in_between, "Hard In-Between", {4, 1}, "Dealer's upcard is between your two cards - Ace being the first card"},
      {:suited_blackjack, "Suited Blackjack", {20, 1}, "Your blackjack is suited"},
      {:first_card_ace, "First Card Ace", {3, 1}, "Your first card is an Ace"},
      {:unlucky_eights, "Unlucky Eights", {15, 1}, "You get two 8s"},
      {:king_of_hearts, "King of Hearts", {15, 1}, "You have the King of Hearts"},
      {:total_exactly_21, "Total Exactly 21", {10, 1}, "Your initial hand totals exactly 21"},
      {:jackpot_jack, "Jackpot Jack", {15, 1}, "You get the Jack of Spades"},
      {:queen_of_diamonds, "Queen of Diamonds", {25, 1}, "You get the Queen of Diamonds"},
      {:jokers_wild, "Joker's Wild", {15, 1}, "You get two Jacks"},
      {:lucky_thirteen, "Lucky Thirteen", {6, 1}, "Your initial two cards total exactly 13"},
      {:two_faced, "Two Faced", {6, 1}, "Both your cards are face cards (J, Q, K)"},
    ]

    # Select random side bets
    def create_random(count : Int32) : Array(SideBet)
      return [] of SideBet if count <= 0

      selected_specs = SIDE_BET_SPECS.sample(count)
      selected_specs.map do |type, name, ratio, desc|
        SideBet.new(name, ratio, desc, type)
      end
    end
  end
end
