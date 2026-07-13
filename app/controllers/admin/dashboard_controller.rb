class Admin::DashboardController < Admin::BaseController
  def index
    @announcements = Announcement.order(created_at: :desc).limit(2)
    @users = User.order(:handle)
  end
end
