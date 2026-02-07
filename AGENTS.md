# Agent-Discovered Patterns & Gotchas

Hard-won lessons from debugging sessions. Check here before implementing similar features.

## Turbo Drive & Form Submissions

Turbo Drive intercepts all `<form>` submissions and enforces strict response rules:

- **Redirects (3xx)** — required for successful form submissions (use `redirect_to`)
- **422 Unprocessable Entity** — accepted for validation errors (re-renders the form)
- **200 OK with HTML body** — **rejected** with `Form responses must redirect to another location`

**Never `render` a template from a POST action.** Use the PRG (Post/Redirect/Get) pattern instead:

```ruby
# Bad — Turbo will reject this
def create
  @result = SomeService.call(params)
  render :next_step  # 200 OK — Turbo error
end

# Good — redirect to a GET action
def create
  result = SomeService.call(params)
  session[:result_data] = result.summary
  redirect_to next_step_path
end

def next_step
  @data = session.delete(:result_data)
end
```

### Session Serialization Caveat

When storing hashes in the session, symbol keys become strings after the JSON round-trip:

```ruby
# In the controller
session[:import_failed] = [{ feed_url: "https://...", error: "..." }]

# After redirect — keys are now strings
session[:import_failed].first["feed_url"]  # correct
session[:import_failed].first[:feed_url]   # nil
```
