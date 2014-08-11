# Colors

set -Ux monokai_black     272822
set -Ux monokai_darkgray  49483e
set -Ux monokai_lightgray 75715e
set -Ux monokai_white     f8f8f2
set -Ux monokai_lime      a6e22e
set -Ux monokai_yellow    e6db74
set -Ux monokai_purple    ae81ff
set -Ux monokai_cyan      66d9ef
set -Ux monokai_orange    fd971f
set -Ux monokai_magenta   f92672

# the default color
set fish_color_normal                    $monokai_white

# the color for commands
set fish_color_command                   $monokai_lime

# the color for quoted blocks of text
set fish_color_quote                     $monokai_yellow

# the color for IO redirections
set fish_color_redirection               $monokai_orange

# the color for process separators like
# ';' and '&'
set fish_color_end                       $monokai_magenta

# the color used to highlight potential
# errors
set fish_color_error                     $monokai_magenta

# the color for regular command
# parameters
set fish_color_param                     $monokai_cyan

# the color used for code comments
set fish_color_comment                   $monokai_lightgray

# the color used to highlight matching
# parenthesis
set fish_color_match                     $monokai_cyan

# the color used to highlight history
# search matches
set fish_color_search_match --background=$monokai_darkgray $monokai_white -o

# the color for parameter expansion
# operators like '*' and '~'
set fish_color_operator                  $monokai_cyan

# the color used to highlight character
# escapes like '\n' and '\x70'
set fish_color_escape                    $monokai_orange

# the color used for the current
# working directory in the default
# prompt
set fish_color_cwd                       $monokai_purple

# Additionally, the following variables
# are available to change the
# highlighting in the completion pager:

# the color of the prefix string, i.e.
# the string that is to be completed
set fish_pager_color_prefix              $monokai_cyan

# the color of the completion itself
set fish_pager_color_completion          $monokai_white

# the color of the completion
# description
set fish_pager_color_description         $monokai_lightgray

# the color of the progress bar at the
# bottom left corner
set fish_pager_color_progress            $monokai_cyan
