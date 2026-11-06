# GitHub Projects connection and repository cleanup

Updated5November2026. [Project3](https://github.com/users/TheInfinityIQ/projects/3)
is the existing project; no replacement board was created. Current counts and
preservation links are in [the live verification receipt](github_repository_status.json).

The official GitHub Projects MCP connection is named `github_projects`, with
`projects_get`, `projects_list` and `projects_write`. Installed Codex successfully
parsed the connection. A private captured invocation of the deployed header helper
initialized the official server, listed those exact tools and read Project3.
The registered `mcp__github_projects` tools are now available in the lead chat.
A native `projects_get` invocation successfully returned actual private Project3;
this verifies the app connection as well as the earlier private protocol check.

The existing Generic Windows credential `TrenchoProjectsGitHub` has actual update
access to this project. Its token remains owned by Windows Credential Manager.
`tools/github_mcp_headers.py` reads only that named target; stdout is a private
MCP header pipe and must never be displayed or logged. Failure prints only a
constant sanitized error; the native credential buffer is released in finally.
There is no credential enumeration, new token, scope expansion, persistent token
environment variable, background service or token cache. The source diagram was
saved before implementation in `docs/diagrams/github_projects_connection.*`.

A deployment copy lives under the user's private Codex profile so branch switches
do not break the connection. Codex config contains only the official URL, helper
command/target name and three-tool allowlist. Existing settings were preserved
and backed up in that profile. No credentials or private backup are in this repo.
The helper's four dummy-data checks were written/passed before the replacement
verification instruction; they are retained for later and were not rerun.
Current setup proof is the actual private helper→MCP→Project3 read, not an engine
run or regression campaign.

Project management remains limited to the user's requested Trencho work. Keep
valid unmet outcomes open, transfer unique obligations before closing redundant
trackers, preserve historical branches/evidence and use related-system references
instead of stale native blocked-by gates. Active feature PRs require exact-head
lead technical and Designer gameplay review. Shared-account role COMMENT decisions
are not native GitHub APPROVED. Cleanup does not certify gameplay or60FPS.

Sources: [Codex header-helper configuration](https://learn.chatgpt.com/docs/config-file/config-reference),
[official GitHub remote Projects toolset](https://github.com/github/github-mcp-server/blob/main/docs/remote-server.md),
[Windows CredReadW](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credreadw),
[CredFree](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credfree),
[GitHub issue dependencies](https://docs.github.com/en/rest/issues/issue-dependencies)
and [subissues](https://docs.github.com/en/rest/issues/sub-issues).
