# Authentication helpers for request specs
module AuthenticationHelpers
  def sign_in(user)
    post login_path, params: { email: user.email }
    token = user.reload.magic_token
    get verify_magic_link_path(token: token)
  end

  def sign_in_as(user)
    # Directly set session for faster test execution
    # This bypasses the magic link flow but mimics the end result
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
