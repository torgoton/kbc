class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def animate_build_settlement(game, player, row, col)
    # TODO: implement animation logic here
    # - use ActionCable to broadcast to clients on an animation channel?
  end
end
