# TODO

## Urgent: Hosting Migration

**Status:** Heroku not working well - worker dyno running out of memory

**Plan:** Migrate to [Hatchbox.io](https://hatchbox.io) this week

**Why Hatchbox:**
- Easier server management
- Better resource allocation for background workers
- More control over memory limits

**Migration checklist:**
- [ ] Set up Hatchbox account and server
- [ ] Configure PostgreSQL database
- [ ] Set up Redis (if needed for Solid Queue)
- [ ] Configure environment variables (SECRET_KEY_BASE, RESEND_API_KEY, etc.)
- [ ] Set up SSL for listen.davepaola.com
- [ ] Deploy and test
- [ ] Update DNS to point to new server
- [ ] Decommission Heroku

---

*Last updated: 2026-01-25*
