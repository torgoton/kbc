class AnnouncementsController < ApplicationController
  def index
    @offset = params[:offset].to_i
    @unpinned = Announcement.unpinned.offset(@offset).limit(Announcement::PAGE_SIZE)
    @more = Announcement.unpinned.offset(@offset + Announcement::PAGE_SIZE).exists?

    if params[:offset]
      render partial: "page", locals: { announcements: @unpinned, offset: @offset, more: @more }
    else
      @pinned = Announcement.pinned
    end
  end
end
