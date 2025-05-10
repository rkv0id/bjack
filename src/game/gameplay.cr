require "../terminal/input"
require "../terminal/objects"

module Game
  class GamePlay
    property blackjack_ratio : Float64
    property config : Game::Config

    def initialize(@config : Config)
      @bankroll = @config.cash
      @deck = Deck.new(@config.num_decks)
      @blackjack_ratio = parse_ratio(@config.blackjack_pay)
      @side_bets = SideBetFactory.create_random(@config.num_side_bets)
      @status_message = ""
    end

    private def parse_ratio(str : String) : Float64
      nums = str.split(":").map(&.to_i)
      nums[0].to_f / nums[1]
    end

    private def update_status(message : String = "", current_bet : Int32 = 0) : Nil
      @status_message = message
      if @config.clear_screen?
        Terminal.draw_status_dashboard(@bankroll, current_bet, @status_message)
      end
    end

    private def clear_screen : Nil
      if @config.clear_screen?
        Terminal.clear
        Terminal.draw_status_dashboard(@bankroll, 0, @status_message)
      end
    end

    private def display_cards(hand : Hand, title : String, hidden_index : Int32 = -1) : Nil
      puts Terminal.format_info(title)

      if @config.use_ascii_cards?
        hand_visual = Terminal::Hand.new(hand, hidden_index)
        puts hand_visual.to_ascii
        puts "Total: #{hand.best_total}" unless hidden_index != -1
      else
        cards_str = hand.cards.map_with_index do |card, idx|
          if idx == hidden_index
            "???"
          else
            suit_color = case card.suit
                         when "♥", "♦" then Terminal::RED
                         else               Terminal::BLACK
                         end
            "#{suit_color}#{card.rank}#{card.suit}#{Terminal::RESET}"
          end
        end.join(" ")

        puts cards_str
        puts "Total: #{hand.best_total}" unless hidden_index != -1
      end
    end

    private def ask_bet(side : Bool = false) : Int32
      min_bet = side ? @config.min_bet // 5 : @config.min_bet
      max_bet = side ? @config.max_bet // 5 : @config.max_bet
      max_allowed = [@bankroll, max_bet].min

      if side
        prompt = "Enter side bet (0 to skip, #{min_bet}-#{max_allowed}): $"
        amount = Terminal.ask_numeric(prompt, 0, max_allowed, @config)

        # Fix: Even if amount is 0, we should return it (no need to check if >= min_bet)
        return amount if amount == 0

        # Only check against min_bet if amount is not 0
        if amount < min_bet
          print Terminal.format_loss("Side bet must be at least #{min_bet}. ")
          puts Terminal.format_info("Skipping side bet.")
          return 0
        end

        amount
      else
        # Ensure we don't ask for a bet higher than the bankroll
        if min_bet > max_allowed
          puts Terminal.format_loss("Not enough funds for minimum bet. Game over.")
          return 0 # Return 0 to trigger game end
        end
        prompt = "Enter main bet (#{min_bet}-#{max_allowed}): $"
        Terminal.ask_numeric(prompt, min_bet, max_allowed, @config)
      end
    end

    private def player_turn(hands : Array(Hand), dealer_hand : Hand, split_count : Int32 = 0) : Nil
      hands.each_with_index do |hand, idx|
        puts "\n#{Terminal.format_player("Playing hand #{idx + 1} of #{hands.size}")}"
        display_cards(hand, "Your hand:")

        first_move = true
        busted = false

        loop do
          break if hand.blackjack?

          options = {'h' => "it", 's' => "tand"}

          if first_move
            options['d'] = "ouble" if @bankroll >= hand.bet
            options['u'] = "surrender" if @config.surrender? && split_count == 0

            # Only allow splitting if we haven't exceeded max splits and have enough bankroll
            if hand.can_split? && split_count < @config.max_splits && @bankroll >= hand.bet
              options['p'] = "split"
            end
          end

          choice = Terminal.ask_choice("Your turn:", options, @config)

          case choice
          when 'h'
            card = @deck.draw
            hand.add(card)
            puts "You draw: #{Terminal.color_suit(card.suit, card.to_s)} (Total: #{hand.best_total})"
            display_cards(hand, "Your hand:")

            if hand.bust?
              puts Terminal.format_loss("You busted! Lose $#{hand.bet}.")
              busted = true
              break
            end
          when 's'
            puts Terminal.format_info("You stand at #{hand.best_total}.")
            break
          when 'd'
            if first_move && @bankroll >= hand.bet
              @bankroll -= hand.bet
              hand.bet *= 2
              card = @deck.draw
              hand.add(card)
              puts "You double and draw: #{Terminal.color_suit(card.suit, card.to_s)} (Total: #{hand.best_total})"
              display_cards(hand, "Your hand:")

              if hand.bust?
                puts Terminal.format_loss("You busted! Lose $#{hand.bet}.")
                busted = true
              end
              break
            end
          when 'u'
            if first_move && @config.surrender? && split_count == 0
              half_bet = (hand.bet // 2)
              @bankroll += half_bet # Return half the bet
              puts Terminal.format_loss("You surrender. Lose $#{half_bet}.")
              hand.bet = 0 # Mark as surrendered
              break
            end
          when 'p'
            if hand.can_split? && split_count < @config.max_splits && @bankroll >= hand.bet
              process_split(hands, idx, hand, dealer_hand, split_count)
              return # Exit this function as we've restructured the hands array
            end
          end

          first_move = false
        end
      end
    end

    private def process_split(hands : Array(Hand), current_idx : Int32, current_hand : Hand, dealer_hand : Hand, split_count : Int32) : Nil
      puts Terminal.format_info("Splitting #{current_hand.cards[0].rank}s...")

      # Deduct the bet for the second hand
      @bankroll -= current_hand.bet

      # Create two new hands with one card each
      hand1 = Hand.new([current_hand.cards[0]], current_hand.bet)
      hand2 = Hand.new([current_hand.cards[1]], current_hand.bet)

      # Draw a new card for each hand
      card1 = @deck.draw
      card2 = @deck.draw
      hand1.add(card1)
      hand2.add(card2)

      puts "First hand: #{Terminal.color_suit(hand1.cards[0].suit, hand1.cards[0].to_s)} #{Terminal.color_suit(card1.suit, card1.to_s)} (Total: #{hand1.best_total})"
      puts "Second hand: #{Terminal.color_suit(hand2.cards[0].suit, hand2.cards[0].to_s)} #{Terminal.color_suit(card2.suit, card2.to_s)} (Total: #{hand2.best_total})"

      # Replace the current hand and insert the new one
      hands[current_idx] = hand1
      hands.insert(current_idx + 1, hand2)

      # Continue playing with the updated hands array
      player_turn(hands, dealer_hand, split_count + 1)
    end

    private def dealer_turn(hand : Hand) : Nil
      puts "\n#{Terminal.format_dealer("Dealer's turn")}"
      display_cards(hand, "Dealer hand:")

      loop do
        total = hand.best_total
        soft = hand.soft?

        # Dealer stands on hard 17+ and soft 17+ (unless hit_soft17 is true)
        break if total > 17
        break if total == 17 && (!soft || !@config.hit_soft17?)

        card = @deck.draw
        hand.add(card)
        puts "Dealer draws: #{Terminal.color_suit(card.suit, card.to_s)} (Total: #{hand.best_total})"
        display_cards(hand, "Dealer hand:")
      end

      status = hand.bust? ? Terminal.format_loss("busts") : Terminal.format_info("stands")
      puts "Dealer #{status} at #{hand.best_total}."
    end

    private def resolve_bet(player_hand : Hand, dealer_hand : Hand) : Nil
      return if player_hand.bet == 0 # Skip if surrendered

      if player_hand.bust?
        # Player has already busted, bet is already lost
        return
      end

      if dealer_hand.bust?
        win_msg = "Dealer busts! You win $#{player_hand.bet}."
        puts Terminal.format_win(win_msg)
        @bankroll += player_hand.bet * 2 # Return bet + winnings
      else
        p_total = player_hand.best_total
        d_total = dealer_hand.best_total

        if p_total > d_total
          win_msg = "You win $#{player_hand.bet}!"
          puts Terminal.format_win(win_msg)
          @bankroll += player_hand.bet * 2 # Return bet + winnings
        elsif p_total < d_total
          lose_msg = "You lose $#{player_hand.bet}."
          puts Terminal.format_loss(lose_msg)
          # Bet already deducted
        else
          push_msg = "Push."
          puts Terminal.format_push(push_msg)
          @bankroll += player_hand.bet # Return the original bet
        end
      end
    end

    private def process_side_bets(side_bet : Int32, player_hand : Hand, dealer_hand : Hand) : Nil
      return if side_bet <= 0 || @side_bets.empty?

      win_amount = 0
      puts "\n#{Terminal.format_info("Side Bet Results:")}"

      @side_bets.each do |side|
        if side.evaluate(player_hand, dealer_hand)
          curr_win = side.payout(side_bet)
          win_msg = "#{side.name} wins! +$#{curr_win}"
          puts Terminal.format_win(win_msg)
          win_amount += curr_win
        end
      end

      if win_amount == 0
        lose_msg = "All side bets lost! -$#{side_bet}"
        puts Terminal.format_loss(lose_msg)
        # Side bet was already deducted from bankroll
      else
        @bankroll += win_amount + side_bet # Return side bet + winnings
      end
    end

    # Main game loop
    def play : Nil
      puts Terminal.format_info("Welcome to BJACK Classic Blackjack!")

      if !Terminal.ask_yes_no("Start game?", @config)
        return
      end

      while @bankroll >= @config.min_bet
        clear_screen
        update_status("Ready to play")
        print("\n\n\n")

        main_bet = ask_bet()
        # Check if we should exit (bet is 0 means not enough funds)
        break if main_bet == 0

        @bankroll -= main_bet
        update_status("Bet placed: $#{main_bet}", current_bet: main_bet)

        side_bet = 0
        if !@side_bets.empty? && @bankroll > 0
          puts "\n#{Terminal.format_info("Side Bets Available:")}"
          @side_bets.each_with_index do |side_bet_obj, index|
            puts "#{index + 1}. #{side_bet_obj.describe}"
          end

          side_bet = ask_bet(side: true)
          if side_bet > 0
            @bankroll -= side_bet
            update_status("Bets: $#{main_bet} + $#{side_bet} side", main_bet + side_bet)
          end
        end

        # Initial deal
        player_hand = Hand.new(bet: main_bet)
        dealer_hand = Hand.new

        upcard = @deck.draw
        hole_card = @deck.draw
        player_hand.add(@deck.draw)
        player_hand.add(@deck.draw)
        dealer_hand.add(upcard)
        dealer_hand.add(hole_card)

        puts "#{Terminal.format_dealer("Dealer shows:")} #{Terminal.color_suit(upcard.suit, upcard.to_s)}"
        display_cards(dealer_hand, "Dealer hand:", 1) # Hide hole card

        display_cards(player_hand, "Your hand:")

        # Create an array to hold all player hands (for splitting)
        player_hands = [player_hand]

        # Handle side bets (fix: we need to wait to process side bets AFTER dealer cards are revealed)
        # Store the side bet amount for later

        insurance_bet = 0
        if @config.insurance? && upcard.rank == "A" && @bankroll >= (main_bet // 2)
          insurance_bet = main_bet // 2
          if Terminal.ask_yes_no("Buy insurance for $#{insurance_bet}?", @config)
            @bankroll -= insurance_bet
            puts Terminal.format_info("Insurance bet: $#{insurance_bet}")
          else
            insurance_bet = 0
          end
        end

        # Dealer peek
        if @config.peek? && (upcard.rank == "A" || ["10", "J", "Q", "K"].includes?(upcard.rank))
          puts Terminal.format_info("Dealer peeks...")
          if dealer_hand.blackjack?
            puts Terminal.format_dealer("Dealer has Blackjack!")
            display_cards(dealer_hand, "Dealer hand:") # Show hole card

            # Pay insurance if it was placed
            if insurance_bet > 0
              insurance_win = insurance_bet * 2
              @bankroll += insurance_win
              puts Terminal.format_win("Insurance pays $#{insurance_win}!")
            end

            if player_hand.blackjack?
              puts Terminal.format_push("Push!")
              @bankroll += main_bet # Return the original bet
            else
              puts Terminal.format_loss("You lose $#{main_bet}.")
              # Main bet already deducted
            end

            # Process side bets
            process_side_bets(side_bet, player_hand, dealer_hand)

            play_again? ? next : break
          else
            puts Terminal.format_info("No Blackjack.")
            # Insurance bet is lost (already deducted)
          end
        end

        # Dealer blackjack without peek
        if dealer_hand.blackjack? && !@config.peek?
          puts Terminal.format_dealer("Dealer has Blackjack!")
          display_cards(dealer_hand, "Dealer hand:")

          # Pay insurance if it was placed
          if insurance_bet > 0
            insurance_win = insurance_bet * 2
            @bankroll += insurance_win
            puts Terminal.format_win("Insurance pays $#{insurance_win}!")
          end

          if player_hand.blackjack?
            puts Terminal.format_push("Push!")
            @bankroll += main_bet # Return the original bet
          else
            puts Terminal.format_loss("You lose $#{main_bet}.")
            # Main bet already deducted
          end

          # Process side bets
          process_side_bets(side_bet, player_hand, dealer_hand)

          play_again? ? next : break
        end

        # Process side bets for normal gameplay
        process_side_bets(side_bet, player_hand, dealer_hand)

        if player_hand.blackjack?
          blackjack_win = (main_bet * @blackjack_ratio).to_i
          @bankroll += blackjack_win + main_bet # Return original bet plus winnings
          puts Terminal.format_win("Blackjack! You win $#{blackjack_win}.")
        else
          # Player's turn - now with splitting support
          player_turn(player_hands, dealer_hand)

          # If any hand is still in play, dealer needs to play
          active_hands = player_hands.select { |h| h.bet > 0 && !h.bust? }

          if !active_hands.empty?
            dealer_turn(dealer_hand)

            # Resolve all hands against the dealer
            player_hands.each_with_index do |hand, idx|
              puts "\n#{Terminal.format_player("Hand #{idx + 1}")}: #{hand} (Total: #{hand.best_total})"
              resolve_bet(hand, dealer_hand)
            end
          end
        end

        # Fix: Check if bankroll is enough for minimum bet
        if @bankroll < @config.min_bet
          puts Terminal.format_loss("You don't have enough money for the minimum bet.")
          break
        end

        break unless play_again?
      end

      puts Terminal.format_info("Game over! Final bankroll: #{Terminal.format_money(@bankroll)}")
    end

    private def play_again? : Bool
      Terminal.ask_yes_no("Play another round?", @config)
    end
  end
end
