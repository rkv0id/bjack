module Terminal
  # ANSI color codes
  RESET      = "\e[0m"
  BOLD       = "\e[1m"
  BLACK      = "\e[30m"
  RED        = "\e[31m"
  GREEN      = "\e[32m"
  YELLOW     = "\e[33m"
  BLUE       = "\e[34m"
  MAGENTA    = "\e[35m"
  CYAN       = "\e[36m"
  WHITE      = "\e[37m"
  BG_BLACK   = "\e[40m"
  BG_RED     = "\e[41m"
  BG_GREEN   = "\e[42m"
  BG_YELLOW  = "\e[43m"
  BG_BLUE    = "\e[44m"
  BG_MAGENTA = "\e[45m"
  BG_CYAN    = "\e[46m"
  BG_WHITE   = "\e[47m"

  # Terminal size
  def width : Int32
    `tput cols`.to_i
  rescue
    80 # Fallback width
  end

  def height : Int32
    `tput lines`.to_i
  rescue
    24 # Fallback height
  end

  def clear : Nil
    print "\e[2J\e[H"
  end

  def move_to(row : Int32, col : Int32) : Nil
    print "\e[#{row};#{col}H"
  end

  def save_cursor : Nil
    print "\e[s"
  end

  def restore_cursor : Nil
    print "\e[u"
  end

  def horizontal_line(char : Char = '─', width : Int32 = self.width) : Nil
    puts char.to_s * width
  end

  def draw_box(width : Int32, height : Int32, title : String = "") : Nil
    print "┌" + "─" * (width - 2) + "┐\n"
    (height - 2).times do |i|
      if i == 0 && !title.empty?
        title_display = " #{title} "
        padding_left = (width - 2 - title_display.size) / 2
        padding_right = width - 2 - padding_left - title_display.size
        print "│" + " " * padding_left + title_display + " " * padding_right + "│\n"
      else
        print "│" + " " * (width - 2) + "│\n"
      end
    end
    print "└" + "─" * (width - 2) + "┘\n"
  end

  def color_suit(suit : String, text : String? = nil) : String
    color = case suit
            when "♥", "♦" then RED
            when "♠", "♣" then BLACK
            else               WHITE
            end

    display_text = text || suit
    "#{color}#{display_text}#{RESET}"
  end

  def format_win(text : String) : String
    "#{GREEN}#{BOLD}#{text}#{RESET}"
  end

  def format_loss(text : String) : String
    "#{RED}#{BOLD}#{text}#{RESET}"
  end

  def format_push(text : String) : String
    "#{YELLOW}#{text}#{RESET}"
  end

  def format_info(text : String) : String
    "#{CYAN}#{text}#{RESET}"
  end

  def format_dealer(text : String) : String
    "#{MAGENTA}#{text}#{RESET}"
  end

  def format_player(text : String) : String
    "#{BLUE}#{text}#{RESET}"
  end

  def format_money(amount : Int32) : String
    if amount > 0
      "#{GREEN}$#{amount}#{RESET}"
    elsif amount < 0
      "#{RED}$#{amount.abs}#{RESET}"
    else
      "$0"
    end
  end

  def draw_status_dashboard(bankroll : Int32, bet : Int32, message : String = "") : Nil
    width = self.width
    save_cursor
    move_to(1, 1)
    print "┌" + "─" * (width - 2) + "┐\n"
    print "│ Bankroll: #{format_money(bankroll)} | Current Bet: #{format_money(bet)}"

    if !message.empty?
      padding = width - 4 - "Bankroll: $#{bankroll} | Current Bet: $#{bet}".size - message.size
      padding = padding < 0 ? 0 : padding
      print " " * padding + "#{message} │\n"
    else
      print " " * (width - 2 - " Bankroll: $#{bankroll} | Current Bet: $#{bet}".size) + "│\n"
    end

    print "└" + "─" * (width - 2) + "┘\n"
    restore_cursor
  end

  # Wait for a single keypress
  def get_char : Char
    # Disable terminal echo and canonical mode
    system("stty -echo -icanon")
    char = STDIN.raw &.read_char || ' '
    # Restore terminal settings
    system("stty echo icanon")
    char
  end

  def supports_color? : Bool
    term = ENV["TERM"]?
    !!(term && !term.matches?(/dumb|unknown/))
  end
end
