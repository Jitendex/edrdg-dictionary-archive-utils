# EDRDG Dictionary Archive Utils

Dictionary file versions are archived in the
[EDRDG Dictionary Archive](https://github.com/Jitendex/edrdg-dictionary-archive)
as sequences of patches. The script in this repo allows for files to
be easily rebuilt from those patches and for new patches to be written
to the archive.

```
Usage: edrdg_dictionary_archive [OPTIONS] <command>

Commands
  get
      Build a specified file and print its path.

  update
      Get the latest file data from 'ftp.edrdg.org::nihongo',
      add the patches to the archive, and commit to Git.

General Options
  -h, --help
      Print this message.

  -v, --version
      Print the version of this script.

  -r, --repo-dir=<path>
      Path to the local edrdg-dictionary-archive Git repo.
      Default: '$XDG_DATA_HOME/edrdg-dictionary-archive'

  -i, --init
      Download the edrdg-dictionary-archive Git repo from
      https://github.com/Jitendex/edrdg-dictionary-archive
      if it doesn't already exist.

Options for the 'get' Command
  -f, --file=<file>
      Name of the file to get. Must be one of
        JMdict
        JMdict_e
        JMdict_e_examp
        JMnedict.xml
        kanjidic2.xml
        examples.utf

  -d, --date=<YYYY-MM-DD>
      Date of the file to get.

  -l, --latest
      Instead of specifying a date, use the most recent available.
```

# Building a File

The `get` command builds a particular file for a particular date.

```fish
# Build JMdict from January 1, 2024
fish edrdg_dictionary_archive.fish get --file=JMdict --date=2024-01-01

# Build the latest available version of kanjidic2.xml
fish edrdg_dictionary_archive.fish get --file=kanjidic2.xml --latest
```

The resulting file is compressed and written to the user's cache
directory (`$XDG_CACHE_HOME`). The full path to the Brotli-compressed
file is printed to `stdout`.

If an older version of the file is present in the user's cache, the
script will use it as the base file for patching. For example, if a
JMdict file for 2025-11-01 exists in the cache, then only one patch
file will be applied to it to get the file for 2025-11-02. Otherwise,
hundreds of patches would be applied to the repo's original base file
(from 2023) to get to 2025.

> [!WARNING]
> Patching these large XML files is computationally expensive, and it
> may take several minutes to patch a base file from 2023 to the latest
> version. If the latest version of a file is all you need, you should
> get it from the EDRDG FTP server instead.

# Updating the Archive

The `update` command builds the latest archived version of each file
and compares them to the current versions of the files on the EDRDG
FTP server. The `diff` of each file is written to the archive as a new
patch.

The updated files are saved to the user's cache directory. Since this
update is intended to be run daily, the previous versions of the files
are removed from the cache.

```fish
# Usage example
fish edrdg_dictionary_archive.fish update

# Using a different data directory
fish edrdg_dictionary_archive update --repo-dir=/path/to/data/directory
```

# Job Scheduling

A systemd service unit and timer are included for running this script daily.
To push commits to GitHub without entering a password, a
[fine-grained personal access token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
should be created and given "content" privileges for the relevant repo.

If git is configured to store credentials, it will save the PAT to
`~/.git-credentials` after the token is used for the first time.

```
git config credential.helper store
```

# Dependencies

In addition to the the `fish` shell and the standard GNU coreutils
(`mkdir`, `cp`, `rm`, `date`, etc.), these scripts also expect the
following commands to be available.

- `git`
- `rsync`
- `brotli`
- `patch`
- `diff`
- `cmp`
- `grep`
- `uuidgen`

# License

Copyright (c) 2025 Stephen Kraus

Licensed under the Apache License, Version 2.0 (the "License");
you may not use these files except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
