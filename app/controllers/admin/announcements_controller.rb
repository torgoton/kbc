class Admin::AnnouncementsController < Admin::BaseController
  # ponytail: toggle_pin omitted here (Task 5 owns the action); raise_on_missing_callback_actions
  # errors if it's listed in :only before the action method exists.
  before_action :set_announcement, only: %i[ edit update destroy ]

  def index
    @announcements = Announcement.order(pinned: :desc, created_at: :desc)
  end

  def new
    @announcement = Announcement.new
  end

  def create
    @announcement = Announcement.new(announcement_params)
    if @announcement.save
      redirect_to admin_announcements_path, notice: "Announcement created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @announcement.update(announcement_params)
      redirect_to admin_announcements_path, notice: "Announcement updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @announcement.destroy!
    redirect_to admin_announcements_path, notice: "Announcement deleted.", status: :see_other
  end

  private
    def set_announcement
      @announcement = Announcement.find(params.expect(:id))
    end

    def announcement_params
      params.expect(announcement: [ :title, :body, :pinned ])
    end
end
