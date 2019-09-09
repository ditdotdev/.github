# Titan Community Contributions

Titan is an open community that welcomes contributions from anyone that is
interested in improving the Titan project.

## Issues

If you're struggling with something, but are unsure if it's a bug or missing
feature, please contact the community through [available resources](RESOURCES.md)
before submitting a new issue. It could simply be a misconfiguration or
misunderstanding. If you do believe that it is a bug or missing feature,
please search existing issues to see if something similar has already been
reported.

When making a chance, it is always recommended to first file an issue that
describes the problem or feature being added. This creates a space for
dialog and discussion, and a place where other users can associate their
experiences, include closing new issues out as a duplicate.

All issues should follow the issue request template used by the project when
opening new issue requests.

## Pull Request Process

To make a change, fork the repository and make any changes to your copy on
GitHub. When you've fully addressed the change you're looking to make,
open a pull request to the `master` branch. If you'd like feedback on
your work prior to completion, include "WIP: " in the title. Fill out any data
requested by the pull request template and submit.

The pull request will run through any automated checks for the repository. If
any of these checks fail, please fix any issues and re-submit. The appropriate
code owners will then review your pull request. If they provide feedback that
must be addressed, please do so and update the pull request. When all checks
and feedback has been addressed, the pull request will be accepted and merged
into master.

By default, Titan projects will [squash and merge](https://help.github.com/en/articles/about-pull-request-merges)
all your commits. This will reduce any commit history down to a single commit
in the permanent history. This keeps the master history clean and easy to
understand, and you don't have to worry about any intermediate commits (like
"undo this thing that didn't work") being part of the history. Anyone can
reference the pull request to see the more detailed discussion and history
of the change. The downside is that if you are addressing multiple issues in one
pull request, it is difficult to known which changes correspond to which issue.
For this reason, it is recommended that each pull request address only a single
issue.

The maintainer doing the merge will set the final commit message. By default
this will be the title of the PR, and a series of `Fixes` lines with references
to any issues fixed by the PR. If possible, please make the last commit fit
this format to simplify the process.

## Branches and Releases

By default, all Titan projects follow the [GitHub Flow](https://guides.github.com/introduction/flow/)
model. This means that all pull requests are merged to `master`, and releases
are triggered by creating a release tag in the master branch. Contributors
should fork repos into their own GitHub space where they can commit updates
and collaborate with others. In rare circumstances, a feature branch can
be created within the Titan community repository, though this practice is
generally discouraged. The master branch is protected - no one can directly
push to the branch, and only maintainers can accept pull requests.

Any "fast" checks (style, build, unit tests, etc) should be automatically run
for each pull request. More complex tests should be run nightly and with each
release. All builds and tests should post alerts to the Titan community slack
workspace.

New releases are triggered by creating a new draft release on GitHub. This should
trigger an automated build process to build, publish artifacts, and optionally
finalize the release. All artifacts should be published via GitHub or an
appropriate package repository (DockerHub, Maven, etc). All third party
packages should be published under a `titan-data` namespace.
