# Aetherfall: Unity Cloud Build Automation status reporting

This is a **read-only** status-reporting integration. It never launches Unity builds, changes their configuration, downloads an APK, or publishes raw logs or signed artifact URLs.

## Setup: Unity service account (performed by the Unity organization owner/manager)

1. Open https://cloud.unity.com/ and select the Unity organization associated with Aetherfall.
2. In the account/organization menu, open **Manage organization → Administration → Service Accounts**.
3. Create a service account named **Aetherfall Build Reporter**.
4. Add a **project role** for the Aetherfall Unity Cloud project, selecting the lowest-privilege role that allows viewing Build Automation builds (if a specific read-only Build Automation role is available, use it). Avoid an organization-wide administrator role. If Unity only offers other roles, review their permissions first.
5. Open the service account's **Keys** area and select **Create key**.
6. Copy both the **Key ID** and **Secret key** to a secure password manager. Unity may only show the secret once. Do **not** paste either into ChatGPT, issues, commits, workflow logs, or screenshots.

Official Unity service-account documentation: https://docs.unity.com/en-us/services-web-apis/service-account-auth

## Setup: GitHub repository Actions secrets

Open https://github.com/demetrecerrone-star/Aetherfall/settings/secrets/actions on your phone.

In **Repository secrets** choose **New repository secret** twice:

| Secret name | Secret value |
| --- | --- |
| `UNITY_SERVICE_ACCOUNT_KEY_ID` | Unity service account **Key ID** |
| `UNITY_SERVICE_ACCOUNT_SECRET_KEY` | Unity service account **Secret key** |

The GitHub Actions workflow uses these values only as encrypted environment variables and never prints them. These are **not** the SSH public key, GitHub personal access token, nor the Unity license activation credentials.

## Run and read your first build report

- GitHub Actions workflow: `Aetherfall Unity Build Report` under the **Actions** tab.
- Select **Run workflow** on branch `main`; enter `1` to inspect Unity Cloud build #1 or use `latest` to examine the most recent build.
- Open the completed run → **Summary** for a build status report with a Unity Cloud link, any recognized error codes, and artifact presence.
- The reporter is checked out from `unity-reboot`, but the workflow definition lives on default branch `main` because GitHub schedules and manual workflow dispatch require the default branch.
- Automatic report checks are configured every six hours; these are API reads, **not Unity cloud builds**. You can run an immediate manual check whenever needed.
- The GitHub repository is public. Reports intentionally exclude raw API responses, full build logs, email addresses, authorization headers, tokens, and temporary artifact URLs.
- Download APKs from the Unity Cloud build's **Artifacts** tab. Do not post a time-limited signed download URL in GitHub logs.

Current Unity Cloud identifiers from the Aetherfall build-details URL:

| Parameter | Value |
| --- | --- |
| Organization | `2476066025878` |
| Project | `92204c56-3bcf-41b8-8eec-43d1069287a1` |
| Build target | `aetherfall-android` |
| Initial build | `1` |

## Troubleshooting

- **HTTP 401:** Verify key ID and secret are paired correctly, and regenerate/re-save the key if needed.
- **HTTP 403:** Verify the service account has permission to read Build Automation builds in this project.
- **HTTP 404:** Verify the cloud project, organization and build target identifiers. The Unity page URL may display different IDs than the API on some accounts; update the reporter workflow's environment values if required.
- **No builds:** Confirm the target has at least one build and that its identifier is correct.
- **Run says secrets missing:** Check spelling of repository Actions secrets and workflow branch.
- **Status says failed but no error identifiers:** The report deliberately omits untrusted raw logs. View the full failed-build log in Unity Cloud and share a redacted error excerpt when requesting code fixes.

Official Build Automation API (v2 build-status endpoints):
https://docs.unity.com/en-us/oas-build-automation-client/2.0.0

## Safety

To revoke the connection, disable this GitHub workflow and revoke the Unity service-account key in Unity Cloud. Don't put account credentials into git, and never use a build-reporting key for unrelated projects. For a public repo, GitHub Actions summaries are public.
