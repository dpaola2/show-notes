# API authentication helpers for request specs.
# Extends AuthenticationHelpers (defined in authentication_helpers.rb)
# with bearer token helpers for Api:: namespace tests.
module AuthenticationHelpers
  # Creates an ApiToken and returns the plaintext token for use in
  # Authorization headers. Use in API request specs.
  def api_sign_in_as(user)
    _api_token, plaintext = ApiToken.generate_for(user)
    plaintext
  end

  # Returns headers hash with Authorization: Bearer for API requests.
  def api_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
