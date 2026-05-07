class ConsequenceApplier
  class ApplyError < StandardError
    attr_reader :messages

    def initialize(messages)
      @messages = messages
      super(messages.join("; "))
    end
  end

  def self.apply!(game, consequences)
    new(game, consequences).apply!
  end

  def self.unapply!(game, consequences)
    new(game, consequences).unapply!
  end

  def initialize(game, consequences)
    @game = game
    @consequences = Array(consequences)
  end

  def apply!
    errors = @consequences.select { |c| c.respond_to?(:error?) && c.error? }
    raise ApplyError.new(errors.map(&:message)) if errors.any?

    Game.transaction do
      @consequences.each { |c| c.apply!(@game) }
      @game.save!
      @game.game_players.each(&:save!)
    end
    @game
  end

  def unapply!
    Game.transaction do
      @consequences.reverse_each { |c| c.unapply!(@game) }
      @game.save!
      @game.game_players.each(&:save!)
    end
    @game
  end
end
