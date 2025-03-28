module ApplicationHelper
  def current_user
    @current_user ||= Current.user
  end
end
