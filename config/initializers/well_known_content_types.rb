# Ensure the apple-app-site-association file is served with the correct
# Content-Type header. The file has no extension, so Rails' static file
# server defaults to text/plain. This middleware intercepts the specific
# path and sets application/json.
Rails.application.config.middleware.insert_before(
  ActionDispatch::Static,
  Class.new {
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      if env["PATH_INFO"] == "/.well-known/apple-app-site-association"
        headers["content-type"] = "application/json"
      end

      [ status, headers, response ]
    end
  }
)
