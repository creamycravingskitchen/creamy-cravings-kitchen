# GitHub Pages For Plaid OAuth Redirect

Host the `docs/` folder with GitHub Pages and register the final URL in the Plaid Dashboard as an allowed OAuth redirect URI.

Recommended final URL shape:

- `https://your-domain.com/plaid/oauth.html`

For GitHub Pages, the usual shape is:

- `https://<github-username>.github.io/<repo-name>/plaid/oauth.html`

Files:

- [oauth.html](/Users/nani/Documents/New%20project/docs/plaid/oauth.html:1)
- [index.html](/Users/nani/Documents/New%20project/docs/index.html:1)

After hosting:

1. Add the exact final URL in the Plaid Dashboard Allowed redirect URIs
2. Put the same exact URL in `backend/.env` as `PLAID_REDIRECT_URI`

Example:

```env
PLAID_REDIRECT_URI=https://<github-username>.github.io/<repo-name>/plaid/oauth.html
```
