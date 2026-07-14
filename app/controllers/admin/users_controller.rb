class Admin::UsersController < Admin::BaseController
  def update
    @user = User.find(params.expect(:id))
    @user.update!(approved: params.expect(user: :approved).require(:approved))
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to admin_path }
    end
  end
end
