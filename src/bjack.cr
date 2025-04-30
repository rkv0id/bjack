require "option_parser"
require "./terminal/terminal"
require "./game/game"

config = Game::Config.new
OptionParser.parse do |parser|
  parser.banner = "Usage: bjack [options]"

  parser.on("--cash CASH", "Starting cash (default #{config.cash})") { |v| config.cash = v.to_i }
  parser.on("--minbet MIN", "Minimum bet (default #{config.min_bet})") { |v| config.min_bet = v.to_i }
  parser.on("--maxbet MAX", "Maximum bet (default #{config.max_bet})") { |v| config.max_bet = v.to_i }
  parser.on("--hit-soft17", "Dealer hits soft 17") { config.hit_soft17 = true }
  parser.on("--surrender", "Allow surrender") { config.surrender = true }
  parser.on("--insurance", "Allow insurance") { config.insurance = true }
  parser.on("--max-splits", "Maximum splits allowed (default #{config.max_splits})") { |v| config.max_splits = v.to_i8 }
  parser.on("--double-split", "Allow double after split") { config.double_split = true }
  parser.on("--no-peek", "Dealer does not check hole card for blackjack") { config.peek = false }
  parser.on("--decks NUM", "Number of decks used (default #{config.num_decks})") { |v| config.num_decks = v.to_i8 }
  parser.on("--side-bets NUM", "Number of side bets (default #{config.num_side_bets})") { |v| config.num_side_bets = v.to_i8 }
  parser.on("--pay PAY", "Blackjack payout (e.g. 6:5, default #{config.blackjack_pay})") { |v| config.blackjack_pay = v }

  # UI options
  parser.on("--no-colors", "Disable colored output") { config.use_colors = false }
  parser.on("--no-ascii", "Disable ASCII card art") { config.use_ascii_cards = false }
  parser.on("--no-clear", "Don't clear screen between rounds") { config.clear_screen = false }
  parser.on("--compact", "Use compact UI mode") { config.ui_mode = :compact }
  parser.on("--no-single-key", "Disable single-key input") { config.single_key_input = false }

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

if !Terminal.supports_color?
  config.use_colors = false
end

puts Terminal.format_info(<<-TEXT
[Classic Mode Starting]
Min Bet: $#{config.min_bet}
Max Bet: $#{config.max_bet}
Starting Cash: $#{config.cash}
Number of Decks: #{config.num_decks}
Peek Enabled: #{config.peek}
Dealer Hits Soft 17: #{config.hit_soft17}
Insurance Offered: #{config.insurance}
Surrender Allowed: #{config.surrender}
Blackjack Payout: #{config.blackjack_pay}
Maximum Splits Allowed: #{config.max_splits}
Double After Split Allowed: #{config.double_split}

TEXT
)

game = Game::GamePlay.new(config)
game.play
