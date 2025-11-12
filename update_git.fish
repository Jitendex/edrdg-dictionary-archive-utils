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
set LOCAL_REPO_DIR (dirname "$THIS_SCRIPT_DIR")
set COMMIT_MESSAGE (date '+%B %d %Y')
set REMOTE 'origin'
set BRANCH 'main'

source "$THIS_SCRIPT_DIR"/'shared_functions.fish'

function _get_git_config -a key
    git -C "$LOCAL_REPO_DIR" config --local "$key"
end

function _set_git_config -a key value
    git -C "$LOCAL_REPO_DIR" config --local "$key" "$value"
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
    set update_script "$THIS_SCRIPT_DIR"/'update_file.fish'
    if set new_patch (fish "$update_script" --file="$file_name")
        git -C "$LOCAL_REPO_DIR" add "$new_patch"
    end
end

function _git_list_added_files
    git -C "$LOCAL_REPO_DIR" diff --name-only --cached
end

function _added_files_are_valid
    set half_mebibyte (math 2 ^ 19)
    for added_file in (_git_list_added_files)
        set filepath "$LOCAL_REPO_DIR"/"$added_file"
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
        git -C "$LOCAL_REPO_DIR" commit -m "$COMMIT_MESSAGE"
        git -C "$LOCAL_REPO_DIR" push "$REMOTE" "$BRANCH"
    else
        return 1
    end
end

function main
    if dependencies_are_missing
        return 1
    end

    git -C "$LOCAL_REPO_DIR" pull "$REMOTE" "$BRANCH"
    git -C "$LOCAL_REPO_DIR" checkout "$BRANCH"

    set files 'JMdict' 'JMdict_e' 'JMdict_e_examp' 'JMnedict.xml' 'kanjidic2.xml' 'examples.utf'
    for file in $files
        _git_add $file
    end

    _git_commit_and_push
end

main
