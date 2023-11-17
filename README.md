# ungit

Fetch the content of a forge's repository at a given reference into a local
directory. [`ungit`](./ungit.sh) uses the various forge APIs, thus
entirely bypasses `git`. You will get a snapshot of the repository at that
reference, with no history. In most cases, this is much quicker than cloning the
repository.

Read further down a more detailed list of `ungit`'s [features](#highlights) and
[limitations](#limitations), or jump straight to the [examples](#examples).

## Examples

### Fetch from `main` branch at GitHub

Provided `ungit.sh` is in your `$PATH`, the following command will download the
latest content of this repository (`main` branch) into a directory called
`ungit` under the current directory.

```bash
ungit.sh efrecon/ungit
```

### Specify a branch/tag/reference

The following command will download the first version of this repository to the
directory `/tmp/ungit`. The reference can either be a branch name, a tag or, as
in the example, a commit reference.

```bash
ungit.sh efrecon/ungit@34bc76507d0e7722811720532587dd6547e8893a /tmp/ungit
```

### Download from GitLab

The following command will download the `renovate/golang-1.x` branch from the
GitLab Runner project. Verbosity feedback is provided, increase the number of
`v`s for even more details.

```bash
ungit.sh -t gitlab -v gitlab-org/gitlab-runner@renovate/golang-1.x
```

## Usage

The behaviour of `ungit` is controlled by a series of environment variables --
all starting with `UNGIT_` -- and by its command-line (short) options. Options
have precedence over the environment variables. Provided `ungit.sh` is in your
`$PATH`, run the following command to get help over both the variables and the
CLI options.

```bash
ungit.sh -h
```

This script has minimal dependencies. It has been tested under `bash` and `ash`
and will be able to download content as long as `curl` (preferred) or `wget`
(including the busybox version) are available at the `$PATH`.

## Highlights

+ Takes either the full URL to a repository, or its owner/name as a first
  parameter. When only an owner/name is provided, the URL is constructed out of
  the value of the `-t` option -- `github` by default.
+ Keeps a cache of downloaded tarballs under a directory called `ungit` in the
  [XDG] cache directory. Cached tarballs are reused if possible, unless the
  `-ff` option is provided (yes: twice the `-f` option!).
+ Will not overwrite the content of the target directory if it already exists,
  unless the `-f` option is provided.
+ When APIs provide a way to make the difference, the search order for the
  reference is: branch name, tag name, commit reference.
+ When `-f`is provided, wipes the content of the target directory, unless the
  `UNGIT_KEEP` variable is set to `1`. Since `ungit` is about obtaining
  snapshots of target repositories, the (good) default prevents mixing several
  snapshots into the same target directory.
+ `-p` can prevent the target directory to be modified by forcing all files and
  sub-directories to be read-only. This can prevent heedless modification of the
  snapshots.

  [XDG]: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html

## Limitations

+ `ungit` does not work for private repositories.
+ If the target repository contains [submodules], the content of these
  submodules will not be part of the downloaded tarball, nor the directory
  snapshot.

## Why?

There are a number of scenarios where this can be useful:

+ When you want to have a quick look at the content of a project from the
  comfort of your favorite editor.
+ When you want to use neither [submodules], nor [subtree], but still want to
  use (and maintain over time) another project's tree within yours.
+ `ungit` implements a rudimentary package manager.
+ It was fun to write and only took a few hours.

  [submodules]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
  [subtree]: https://git.kernel.org/pub/scm/git/git.git/plain/contrib/subtree/git-subtree.txt

## Ideas

+ Implement a github action on top.
+ Add a git mode. When inside a git directory, create a .ungit file with known
  projects added at the root of the git tree. When run again, with a different
  ref, the existing "installation" will be changed. Also add an upgrade mode to
  bring installations in par, e.g. when pointing to main branch?
