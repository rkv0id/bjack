require "../game/game"

module Terminal
  def ask_numeric(prompt : String, min : Int32, max : Int32, config : Game::Config? = nil) : Int32
    loop do
      print Terminal.format_info(prompt)
      raw = gets.to_s.strip
      if raw =~ /^\d+$/
        amount = raw.to_i
        return amount if amount >= min && amount <= max
      end
      puts Terminal.format_loss("Invalid input. Please enter a number between #{min} and #{max}.")
    end
  end

  def ask_yes_no(prompt : String, config : Game::Config? = nil) : Bool
    use_single_key = config && config.single_key_input?

    if use_single_key
      print Terminal.format_info("#{prompt} (y/n): ")
      key = Terminal.get_char.downcase
      puts key # Echo the key
      key == 'y'
    else
      print Terminal.format_info("#{prompt} (y/n): ")
      raw = gets.to_s.strip.downcase
      raw.starts_with?("y")
    end
  end

  def ask_choice(prompt : String, options : Hash(Char, String), config : Game::Config? = nil) : Char
    use_single_key = config && config.single_key_input?

    loop do
      # Format prompt
      formatted_options = options.map do |key, desc|
        "#{Terminal::BOLD}(#{key})#{Terminal::RESET}#{desc}"
      end.join(" ")

      print Terminal.format_info("#{prompt} #{formatted_options}: ")

      # Get input
      choice = if use_single_key
                 key = Terminal.get_char.downcase
                 puts key # Echo the key
                 key
               else
                 raw = gets.to_s.strip.downcase
                 raw.empty? ? 's' : raw[0]
               end

      return choice if options.has_key?(choice)
      puts Terminal.format_loss("Invalid choice. Please try again.")
    end
  end
end
