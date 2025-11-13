#!/usr/bin/env fish
#
# Copyright (c) 2025 Stephen Kraus
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set COMMANDS \
    'get' \
    'update'

set FILENAMES \
    'JMdict' \
    'JMdict_e' \
    'JMdict_e_examp' \
    'JMnedict.xml' \
    'kanjidic2.xml' \
    'examples.utf'

set REMOTE 'origin'
set BRANCH 'main'

function _get_file_dir -a file_name
    set file_dir_name (string replace -a '.' '_' "$file_name")
    echo "$DATA_DIR"/"$file_dir_name"
end

function _get_data_dir
    set data_dir 'edrdg-dictionary-archive'
    if set -q XDG_DATA_HOME
        echo "$XDG_DATA_HOME"/"$data_dir"
    else
        echo "$HOME"/'.local'/'share'/"$data_dir"
    end
end

function _get_cache_dir -a file_date
    set cache_dir 'edrdg-dictionary-archive'
    if set -q XDG_CACHE_HOME
        echo "$XDG_CACHE_HOME"/"$cache_dir"/"$file_date"
    else
        echo "$HOME"/'.cache'/"$cache_dir"/"$file_date"
    end
end

function _make_tmp_dir
    set tmp_dir '/tmp/edrdg-dictionary-archive-'(uuidgen | cut -c1-8)

    echo "Creating temporary working directory '$tmp_dir'" >&2
    mkdir -p -m 700 "$tmp_dir"

    function tmp_dir_cleanup --inherit-variable tmp_dir --on-event fish_exit
        if test -d "$tmp_dir"
            echo "Deleting temporary working directory '$tmp_dir'" >&2
            rm -r "$tmp_dir"
        end
    end

    echo "$tmp_dir"
end

function _get_latest_date -a file_name
    set file_dir (_get_file_dir "$file_name")
    set patchfiles "$file_dir"/patches/**.patch.br

    # The patches should be sorted first-to-last.
    # The latest should be the last in the array.
    set latest_patchfile $patchfiles[-1]

    if test -n "$latest_patchfile"
        set latest_date (_patchfile_to_date "$latest_patchfile")
        echo "$latest_date"
    else
        echo "No patches found in directory '$file_dir/patches/'" >&2
        return 1
    end
end

function _patchfile_to_date -a patchfile
    string match --regex --groups-only \
        '(\d{4}/\d{2}/\d{2}).patch.br$' "$patchfile" | tr '/' '-'
end

function _get_zeroth_patchfile -a file_name final_patchfile tmp_dir
    set file_dir (_get_file_dir "$file_name")

    for patchfile in "$file_dir"/patches/**.patch.br
        set --local patchfile_date (_patchfile_to_date "$patchfile")
        set --local cache_dir (_get_cache_dir "$patchfile_date")
        set --local cached_file "$cache_dir"/"$file_name".br

        if test -e "$cached_file"
            set zeroth_patchfile "$patchfile"
            set zeroth_file "$cached_file"
        end

        if test "$patchfile" = "$final_patchfile"
            break
        end
    end

    if set -q zeroth_patchfile; and test "$zeroth_patchfile" = "$final_patchfile"
        set --local file_date (_patchfile_to_date "$zeroth_patchfile")
        echo "Patched $file_name already exists in cache for date $file_date" >&2
        return 1
    end

    if not set -q zeroth_file
        set zeroth_file "$file_dir"/"$file_name".br
        if not test -e "$zeroth_file"
            echo "Base file '$zeroth_file' is missing" >&2
            return 1
        end
    end

    echo "Decompressing cached file '$zeroth_file' to '$tmp_dir'" >&2

    brotli --decompress \
        --output="$tmp_dir"/"$file_name" \
        -- "$zeroth_file"

    if set -q zeroth_patchfile
        echo "$zeroth_patchfile"
    end
end

function _get_existing_patchfile -a file_name file_date
    set file_dir (_get_file_dir "$file_name")
    set patch_path (string replace -a '-' '/' "$file_date")
    set patchfile "$file_dir"/patches/"$patch_path".patch.br

    if test -e "$patchfile"
        echo "$patchfile"
    else
        echo "No patch exists for file '$file_name' date '$file_date'" >&2
        return 1
    end
end

function _get_file_by_date -a file_name file_date
    set output_dir (_get_cache_dir "$file_date")
    set output_file "$output_dir"/"$file_name".br

    # Exit quickly if cached file already exists.
    if test -e "$output_file"
        echo "$output_file"
        return
    end

    set final_patchfile (_get_existing_patchfile "$file_name" "$file_date")
    or return 1

    set tmp_dir (_make_tmp_dir)
    or return 1

    set zeroth_patchfile (_get_zeroth_patchfile "$file_name" "$final_patchfile" "$tmp_dir")
    or return 1

    if test -z "$zeroth_patchfile"
        set begin_patching
    end

    for patchfile in (_get_file_dir "$file_name")/patches/**.patch.br
        if not set -q begin_patching
            if test "$patchfile" = "$zeroth_patchfile"
                set begin_patching
            end
            continue
        end

        set -l decompressed_patchfile "$tmp_dir"/'next.patch'

        brotli --decompress --force \
            --output="$decompressed_patchfile" \
            -- "$patchfile"

        set -l patch_date (_patchfile_to_date $patchfile)
        echo "Patching $file_name to version $patch_date" >&2

        patch --quiet \
            "$tmp_dir"/"$file_name" <"$decompressed_patchfile"

        if test "$patchfile" = "$final_patchfile"
            break
        end
    end

    mkdir -p "$output_dir"

    brotli -4 \
        --output="$output_file" \
        -- "$tmp_dir"/"$file_name"

    echo "$output_file"
end

function _get_latest_file -a file_name
    if set file_date (_get_latest_date "$file_name")
        _get_file_by_date "$file_name" "$file_date"
    else
        return 1
    end
end

function _rsync_ftp_file_update -a file_name file_path
    set src 'ftp.edrdg.org::nihongo'/"$file_name"
    set dest "$file_path"
    rsync "$src" "$dest"
end

function _get_file_date -a file_name file_path
    set date_pattern '[0-9]{4}-[0-9]{2}-[0-9]{2}'
    switch "$file_name"
        case 'JMdict' 'JMdict_e' 'JMdict_e_examp'
            grep -m 1 '^<!-- JMdict created:' "$file_path" | grep -Eo "$date_pattern"
        case 'JMnedict.xml'
            grep -m 1 '^<!-- JMnedict created:' "$file_path" | grep -Eo "$date_pattern"
        case 'kanjidic2.xml'
            grep -m 1 '^<date_of_creation>' "$file_path" | grep -Eo "$date_pattern"
        case 'examples.utf'
            date '+%Y-%m-%d'
        case '*'
            return 1
    end
end

function _make_new_patch -a file_name
    # Exit quickly if today's patch already exists.
    begin
        set --local file_dir (_get_file_dir "$file_name")
        set --local today (date '+%Y/%m/%d')
        if test -e "$file_dir"/patches/"$today".patch.br
            echo "$file_name patch for $today already exists" >&2
            return 1
        end
    end

    set old_file_compressed (_get_latest_file "$file_name")
    or begin
        echo "Error fetching latest $file_name archive" >&2
        return 1
    end

    set tmp_dir (_make_tmp_dir)
    set old_file "$tmp_dir"/'old'
    set new_file "$tmp_dir"/"$file_name"

    brotli --decompress \
        --output="$old_file" \
        -- "$old_file_compressed"

    cp "$old_file" "$new_file"

    _rsync_ftp_file_update "$file_name" "$new_file"
    or begin
        echo "Error occurred during $file_name update" >&2
        return 1
    end

    if cmp --quiet "$old_file" "$new_file"
        echo "$file_name is already up-to-date" >&2
        return 1
    end

    set old_date (_get_latest_date "$file_name")
    set new_date (_get_file_date "$file_name" "$new_file")
    or begin
        echo "Cannot parse date from updated $file_name file" >&2
        return 1
    end

    if test "$old_date" = "$new_date"
        echo "$file_name contents are different, yet files contain the same date" >&2
        return 1
    end

    # Ensure new date is greater than old date and not greater than today.
    begin
        set -l old_timestamp (date -d "$old_date" '+%s')
        set -l new_timestamp (date -d "$new_date" '+%s')
        set -l today_timestamp (date -d (date '+%Y-%m-%d') '+%s')
        if test $old_timestamp -gt $new_timestamp
            echo "Updated $file_name date '$new_date' is older than current file date '$old_date'" >&2
            return 1
        else if test $new_timestamp -gt $today_timestamp
            echo "Updated $file_name date '$new_date' is from the future" >&2
            return 1
        end
    end

    set patch_path "$tmp_dir"/'new.patch'

    diff --unified \
        --label "$old_date" \
        --label "$new_date" \
        "$old_file" "$new_file" >"$patch_path"

    begin
        set --local file_dir (_get_file_dir "$file_name")
        set --local date_path (string split '-' "$new_date" | string join '/')
        set archived_patch_path "$file_dir"/patches/"$date_path".patch.br
    end

    mkdir -p (dirname "$archived_patch_path")

    echo "Compressing new patch to '$archived_patch_path'" >&2

    brotli --best \
        --output="$archived_patch_path" \
        -- "$patch_path"

    set cache_dir (_get_cache_dir "$new_date")
    mkdir -p "$cache_dir"

    echo "Compressing updated $file_name to cache dir '$cache_dir'" >&2

    brotli -4 \
        --output="$cache_dir"/"$file_name".br \
        -- "$new_file"

    echo "Deleting old $file_name from cache" >&2

    rm "$old_file_compressed"

    # Remove the directory if it is now empty.
    begin
        set -l old_dir (dirname "$old_file_compressed")
        set -l old_dir_files (ls -A "$old_dir")
        if test -z "$old_dir_files"
            rm -d "$old_dir"
        end
    end

    echo "$archived_patch_path"
end

function _get_git_config -a key
    git -C "$DATA_DIR" config --local "$key"
end

function _set_git_config -a key value
    git -C "$DATA_DIR" config --local "$key" "$value"
end

function _set_temporary_updater_git_config
    set name    (_get_git_config 'user.name')
    set email   (_get_git_config 'user.email')
    set gpgsign (_get_git_config 'commit.gpgsign')

    function _config_reset --on-event fish_exit -V name -V email -V gpgsign
        _set_git_config 'user.name'      "$name"
        _set_git_config 'user.email'     "$email"
        _set_git_config 'commit.gpgsign' "$gpgsign"
    end

    _set_git_config 'user.name'      'edrdg-dictionary-archive'
    _set_git_config 'user.email'     'edrdg-dictionary-archive@noreply.jitendex.org'
    _set_git_config 'commit.gpgsign' 'false'
end

function _git_add -a file_name
    if set new_patch (_make_new_patch "$file_name")
        git -C "$DATA_DIR" add "$new_patch"
    end
end

function _git_list_added_files
    git -C "$DATA_DIR" diff --name-only --cached
end

function _added_files_are_valid
    set half_mebibyte (math 2 ^ 19)
    for added_file in (_git_list_added_files)
        set filepath "$DATA_DIR"/"$added_file"
        set filesize (stat -c %s -- "$filepath")
        if test $filesize -gt $half_mebibyte
            echo "New file '$added_file' is suspiciously large; manual intervention required." >&2
            return 1
        end
    end
end

function _git_commit_and_push
    if _added_files_are_valid
        _set_temporary_updater_git_config
        git -C "$DATA_DIR" commit --message="$(date '+%B %d %Y')"
        git -C "$DATA_DIR" push "$REMOTE" "$BRANCH"
    else
        return 1
    end
end

function _update_git
    git -C "$DATA_DIR" pull "$REMOTE" "$BRANCH"
    git -C "$DATA_DIR" checkout "$BRANCH"

    for filename in $FILENAMES
        _git_add "$filename"
    end

    _git_commit_and_push
end

function _print_usage
    echo "
    Usage: edrdg_dictionary_archive [OPTIONS] command

    Commands:
      get       Build a specified file and print its path
      update    Get the latest file data from the EDRDG FTP server,
                add the patches to the archive, and commit to Git.

    Options:
      -h, --help       Print this message
      -r, --repo-dir   Path to the local edrdg-dictionary-archive Git repo
      -f, --file       Name of the specific file to `get`. Must be one of
                       $(string join ' ' $FILENAMES)
      -d, --date       Date of the specific file to `get`
                       Must be in the format 'YYYY-MM-DD'
      -l, --latest     Use the most recent date of a file for `get`
" >&2
end

function main
    argparse \
        'h/help' \
        'r/repo-dir=!test -d "$_flag_value"' \
        'f/file=!string match -rq \'^'(string join '|' $FILENAMES)'$\' "$_flag_value"' \
        'd/date=!string match -rq \'^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$\' "$_flag_value"' \
        'l/latest' \
        -- $argv
    or begin
        echo 'Error parsing arguments' >&2
        _print_usage
        return 1
    end

    if set -q _flag_help
        _print_usage
        return
    end

    if test (count $argv) -ne 1
        echo "No command argument given" >&2
        _print_usage
        return 1
    else if not contains "$argv" $COMMANDS
        echo "Invalid command argument: `$argv`" >&2
        _print_usage
        return 1
    else
        set command "$argv"
    end

    if set -q _flag_repo_dir
        set --global DATA_DIR "$_flag_repo_dir"
    else
        set --global DATA_DIR (_get_data_dir)
    end

    if not test -e "$DATA_DIR"
        set repo "https://github.com/Jitendex/edrdg-dictionary-archive"
        echo "Data directory not found: $DATA_DIR" >&2
        echo "Cloning repo from '$repo' to '$DATA_DIR" >&2
        git clone "https://github.com/Jitendex/edrdg-dictionary-archive" "$DATA_DIR"
        or begin
            echo "Directory '$DATA_DIR' does not exist and could not be initialized" >&2
            return 1
        end
    else if not test -d "$DATA_DIR"
        echo "Directory '$DATA_DIR' could not be initialized because a file already exists" >&2
        return 1
    end

    switch "$command"
        case 'get'
            if set -q _flag_file
                set file_name "$_flag_file"
            else
                echo 'FILE must be one of '(string join ' ' $FILENAMES) >&2
                _print_usage
                return 1
            end

            if set -q _flag_date
                _get_file_by_date "$file_name" "$_flag_date"
            else if set -q _flag_latest
                _get_latest_file "$file_name"
            else
                echo 'Either --date or --latest flag must be specified' >&2
                _print_usage
                return 1
            end

        case 'update'
            _update_git

        case '*'
            echo "Invalid command `$command`" >&2
            _print_usage
            return 1
    end
end

main $argv
