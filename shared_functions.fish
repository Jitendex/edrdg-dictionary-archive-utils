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

set THIS_SCRIPT_DIR (realpath (status dirname))

function argparse_file
    argparse --ignore-unknown \
        'f/file=!string match -rq \'^JMdict|JMdict_e|JMdict_e_examp|JMnedict.xml|kanjidic2.xml|examples.utf$\' "$_flag_value"' \
        -- $argv

    if set -q _flag_file
        echo "$_flag_file"
    else
        echo 'FILE must be one of JMdict JMdict_e JMdict_e_examp JMnedict.xml kanjidic2.xml examples.utf' >&2
        _usage
        return 1
    end
end

function get_file_dir -a file_name
    set file_dir_name (string replace -a '.' '_' "$file_name")
    echo (dirname "$THIS_SCRIPT_DIR")/"$file_dir_name"
end

function get_cache_dir -a file_date
    set cache_dir 'edrdg-dictionary-archive'
    if set -q XDG_CACHE_HOME
        echo "$XDG_CACHE_HOME"/"$cache_dir"/"$file_date"
    else
        echo "$HOME"/'.cache'/"$cache_dir"/"$file_date"
    end
end

function make_tmp_dir
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

function get_latest_date -a file_name
    set file_dir (get_file_dir "$file_name")
    set patchfiles "$file_dir"/patches/**.patch.br

    # The patches should be sorted first-to-last.
    # The latest should be the last in the array.
    set latest_patchfile $patchfiles[-1]

    if test -n "$latest_patchfile"
        set latest_date (patchfile_to_date "$latest_patchfile")
        echo "$latest_date"
    else
        echo "No patches found in directory '$file_dir/patches/'" >&2
        return 1
    end
end

function patchfile_to_date -a patchfile
    string match --regex --groups-only \
        '(\d{4}/\d{2}/\d{2}).patch.br$' "$patchfile" | tr '/' '-'
end

function dependencies_are_missing
    set dependencies 'git' 'rsync' 'brotli' 'patch' 'diff' 'cmp' 'grep'
    for dependency in $dependencies
        if not command -q "$dependency"
            echo "Command `$dependency` not found" >&2
            set --function missing_dependencies
        end
    end
    if set --function --query missing_dependencies
        echo "Script cannot run with missing dependencies" >&2
        return 0
    else
        return 1
    end
end
