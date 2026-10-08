# Localization design

Translate the current tracked control-repository text into American English. Preserve all machine-readable keys, repository and branch identities, example geographic and time values, placeholders, workflow gates, and executable commands.

Use American English as the default authoring language in AGENTS.md and repository-owned skills. Existing external tools can still emit Chinese diagnostics, so retain those matching alternatives and add English alternatives to the same classifiers. This preserves compatibility while allowing English output to be classified correctly.

No business repository, production service, or deployment is part of this change. Rollback is a normal revert of the localization commit.

The owner's explicit English request supersedes the prior Chinese-language preference. There are no unresolved same-level rule conflicts for this change.
