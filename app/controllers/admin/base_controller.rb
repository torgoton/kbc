class Admin::BaseController < ApplicationController
  before_action :require_admin

  private
    def require_admin
      head :forbidden unless Current.user&.admin?
    end
end
