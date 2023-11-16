# ungit

Fetch the content of a forge's repository at a given reference into a local
directory. This uses the various forge APIs, thus entirely bypasses git. You
will get a snapshot of the repository at that reference, with no history. In
most cases, this is much quicker than cloning the reposotory. It does not work
for private repositories.

## Why?

There are a number of scenarios where this can be useful:

+ When you want to have a quick look at the content of a project from the
  comfort of your favorite editor.
+ When you do want to use neither [submodules], nor [subtree], but still want to
  use (and maintain over time) another project's tree within yours.
+ It was fun to write and only took a few hours.

  [submodules]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
  [subtree]: https://git.kernel.org/pub/scm/git/git.git/plain/contrib/subtree/git-subtree.txt

## Ideas

+ Enforce read-only flags on all downloaded files. Good to make sure no changes
  can be made to the files, meaning good when taking "in" a project as a
  dependency.
+ Implement a github action on top.
