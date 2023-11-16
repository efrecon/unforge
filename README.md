# ungit

Fetch the content of a forge's repository at a given reference into a local
directory. This uses the various forge APIs, thus entirely bypasses git. You
will get a snapshot of the repository at that reference, with no history. In
most cases, this is much quicker than cloning the reposotory. It does not work
for private repositories.

## Examples

Provided `ungit.sh` is in your `$PATH`, the following command will download the
latest content of this repository (`main` branch) into a directory called
`ungit` under the current directory.

```bash
ungit.sh efrecon/ungit
```

The following command will download the first version of this repository to the
directory `/tmp/ungit`.

```bash
ungit.sh efrecon/ungit@34bc76507d0e7722811720532587dd6547e8893a /tmp/ungit
```

## Usage

The behaviour of this script is controlled by a series of environment variables
-- all starting by `UNGIT_` -- and by its command-line (short) options. Options
have precedence over the environment variables. Provided `ungit.sh` is in your
`$PATH`, run the following command to get help over both the variables and the
CLI options.

```bash
ungit.sh -h
```

This script has minimal dependencies. It has been tested under `bash` and `ash`
and will be able to download content as long as `curl` (preferred) or `wget`
(including the busybox version) are available at the `$PATH`.

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
