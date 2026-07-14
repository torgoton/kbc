class Admin::AnnouncementsController < Admin::BaseController
  before_action :set_announcement, only: %i[ edit update destroy toggle_pin ]

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

  def toggle_pin
    @announcement.update!(pinned: !@announcement.pinned?)
    redirect_to admin_announcements_path
  end

  private
    def set_announcement
      @announcement = Announcement.find(params.expect(:id))
    end

    def announcement_params
      params.expect(announcement: [ :title, :body, :pinned ])
    end
end
