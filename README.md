# EDRDG Dictionary Archive Utils

Dictionary file versions are archived in the
[EDRDG Dictionary Archive](https://github.com/Jitendex/edrdg-dictionary-archive)
as sequences of patches. The scripts in this repo allow
for files to be easily rebuilt from those patches and for
new patches to be written to the archive.

## get_file_by_date.fish

This script builds a particular file for a particular date.

```fish
# Build JMdict from January 1, 2024
fish get_file_by_date.fish --file=JMdict --date=2024-01-01

# Build the latest available version of kanjidic2.xml
fish get_file_by_date.fish --file=kanjidic2.xml --latest
```

The resulting file is compressed and written to the user's cache
directory (`$XDG_CACHE_HOME`). The full path to the Brotli-compressed
file is printed to `stdout`.

If an older version of the file is present in the user's cache,
the script will use it as the base file for patching. For example,
if a JMdict file for 2025-11-01 exists in the cache, then only
one patch file will be applied to it to get the file for 2025-11-02.
Otherwise, hundreds of patches would be applied to the repo's
original base file (from 2023) to get to 2025.

## update_file.fish

This script builds the latest archived version of a file and compares
it to the current version of the file on the EDRDG FTP server.
The `diff` of the files is written to the archive as a new patch.

```fish
# Usage example
fish update_file.fish --file=JMnedict.xml
```

The updated file is saved to the user's cache directory.
The older version of the file is removed from the cache.

The full path to the new Brotli-compressed patch is printed to `stdout`.

## update_git.fish

This script runs `update_file.fish` for all file types
in the archive and adds the new patches to the repo.

```fish
# Usage example
fish update_git.fish
```

A systemd service unit and timer are included for running this script daily.
To push commits to GitHub without entering a password, a
[fine-grained personal access token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
should be created and given "content" privileges for the relevant repo.
If git is configured to store credentials (`git config credential.helper store`),
it will save the PAT to `~/.git-credentials` after the token is used
for the first time.

# Dependencies

In addition to the the `fish` shell and the standard GNU coreutils
(`mkdir`, `cp`, `rm`, `date`, etc.), these scripts also expect the
commands `git`, `rsync`, `brotli`, `patch`, `diff`, `cmp`, `grep`,
and `uuidgen` to be available.
