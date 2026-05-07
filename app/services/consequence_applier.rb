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

  def self.unapply!(game)
    new(game, []).unapply!
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
      record_click!
    end
    @game
  end

  def unapply!
    click = TurnClick.most_recent_for(@game)
    return @game unless click

    consequences = click.consequences.map { |h| Turn::Consequences.from_h(h) }

    Game.transaction do
      consequences.reverse_each { |c| c.unapply!(@game) }
      @game.save!
      @game.game_players.each(&:save!)
      click.destroy!
    end
    @game
  end

  private

  def record_click!
    next_order = (TurnClick.where(game_id: @game.id).maximum(:order) || 0) + 1
    TurnClick.create!(game: @game, order: next_order, consequences: @consequences.map(&:to_h))
  end
end
