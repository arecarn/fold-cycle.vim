""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Original Author: Ryan Carney
" License: WTFPL
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" BOILER PLATE {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:save_cpo = &cpo
set cpo&vim
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}


" PUBLIC FUNCTIONS {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" when current cursor is at the start of a fold
"
" on each of the lowest fold levels make sure they are closed
"
" find the start of each fold
"
" if all the lowest fold levels are closed consider the next up and close
" those
"
" states
"
" 1 all closed
" 2 all 1 level folds open
" 3 all 2 level folds open
" n all n level folds open
"
" if not one of these states return to state 1


function! s:d_header(text) abort
    try
        call util#debug#print_header(a:text)
    catch
    endtry
endfunction

function! s:d_var_msg(variable, text) abort
    try
        call util#debug#print_var_msg(a:variable, a:text)
    catch
    endtry
endfunction

function! s:d_msg(text) abort
    try
        call util#debug#print_msg(a:text)
    catch
    endtry
endfunction

function! s:d_msg(text) abort
    try
        call util#debug#print_msg(a:text)
    catch
    endtry
endfunction

function! s:folded(line)
    return foldclosed(a:line) == -1 ? 0 : 1
endfunction

function! s:init() "{{{2
    let s:current_line = line('.')
    let s:folded = s:folded('.')
    let s:fold_level = foldlevel(s:current_line)
    let s:branch_end = s:find_branch_end(s:current_line)

    let s:is_last = s:is_last(s:current_line)
    let s:max_folded_level = s:find_max_folded()
    let s:max_unfolded_level = s:find_max_unfolded()

    call s:d_header('init')
    call s:d_var_msg(s:current_line, 's:current_line')
    call s:d_var_msg(s:folded, 's:folded')
    call s:d_var_msg(s:fold_level, 's:fold_level')
    call s:d_var_msg(s:branch_end, 's:branch_end')

    call s:d_var_msg(s:is_last, 's:is_last')
    call s:d_var_msg(s:max_folded_level, 's:max_folded_level')
    call s:d_var_msg(s:max_unfolded_level, 's:max_unfolded_level')
endfunction "}}}2

function! fold#open() abort "{{{2
    " call s:d_header('fold#open()')
    call s:init()

    if s:folded
        call s:d_msg("opening fold 1")
        foldopen
        return
    endif

    let level_to_open = s:max_folded_level

    if level_to_open == -1
        "s:branch_end is on the same line as the same line as cursor
        call s:d_msg("opening fold")
        foldopen
    endif

    if level_to_open == -1 || level_to_open == 0
        call s:d_msg("closing all folds")
        call s:fold_bottom_up(s:current_line)
        return
    endif

    let line = s:current_line
    while line < s:branch_end
        if foldlevel(line) == level_to_open
            call s:d_msg("opening line " . line)
            execute line . 'foldopen'
        endif

        let line = s:find_next(line)
        if line == 0
            return
        endif
    endwhile
endfunction "}}}2


function! fold#close() abort "{{{2
    " call s:d_header('fold#close()')

    call s:init()

    let to_fold = s:max_unfolded_level

    if to_fold == s:fold_level && s:folded
        foldopen!
        return
    elseif to_fold == s:fold_level
        foldclose
        return
    endif


    if ((to_fold == 'no_nested_folds') || (to_fold == -1))  && s:folded == 1
        foldopen!
        return
    endif


    if to_fold == 0
        call s:d_msg("opening all folds")
        foldopen!
        return
    endif

    let line = line('.')
    while line < s:branch_end
        if foldlevel(line) == to_fold
            call s:d_msg('folding line ' . line)
            execute line . 'foldclose'
        endif
        let line = s:find_next(line)
        if line == 0
            return
        endif
    endwhile

endfunction "}}}2


function! fold#clean_fold(foldchar) "{{{2
    " call s:d_header('fold#clean_fold()')
    "TODO handle wide chars with visual col
    let line = getline(v:foldstart)

    if &foldmethod == 'marker'
        let foldmarker = substitute(&foldmarker, '\zs,.*', '', '')
        let cmt = substitute(&commentstring, '\zs%s.*', '', '')
        let line = substitute(line, '\s*'. '\('.cmt.'\)\?'. '\s*'.foldmarker.'\d*\s*', '', 'g')
    endif

    let lines_count = v:foldend - v:foldstart + 1
    let lines_count_text = '| ' . printf("%10s", lines_count . ' lines') . ' |'
    let foldtextstart = strpart(line, 0, (winwidth(0)*2)/3)
    let foldtextend = lines_count_text . repeat(a:foldchar, 8)
    let foldtextlength = strlen(substitute(foldtextstart . foldtextend, '.', 'x', 'g')) + &foldcolumn

    return foldtextstart . repeat(a:foldchar, winwidth(0)-foldtextlength) . foldtextend
endfunction "}}}2


function! fold#fold_text() "{{{2
    " call s:d_header('fold#fold_text()')
    let line = getline(v:foldstart)
    " Foldtext ignores tabstop and shows tabs as one space,
    " so convert tabs to 'tabstop' spaces so text lines up
    let ts = repeat(' ',&tabstop)
    let line = substitute(line, '\t', ts, 'g')
    let numLines = v:foldend - v:foldstart + 1
    return line.' ['.numLines.' lines]'
endfunction "}}}2


function! fold#get_potion_fold(lnum) "{{{2
    " call s:d_header('fold#get_potion_fold()')
    if getline(a:lnum) =~? '\v^\s*$'
        return '-1'
    endif

    let this_indent = s:indent_level(a:lnum)
    let next_indent = s:indent_level(s:next_non_blank_line(a:lnum))

    if next_indent == this_indent
        return this_indent
    elseif next_indent < this_indent
        return this_indent
    elseif next_indent > this_indent
        return '>' . next_indent
    endif
endfunction "}}}2
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}


" PRIVATE FUNCTIONS {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:do_fold_function(fold_keys, line) abort "{{{2

    if type(a:line) == type('')
        let current_line = line(a:line)
    else
        let current_line = a:line
    endif

    let view = winsaveview()
    execute current_line
    execute 'normal! ' . a:fold_keys
    let line = line('.')
    call winrestview(view)

    if  line == current_line
        return 0
    else
        return line
    endif
endfunction "}}}2


function! s:is_last(line) abort "{{{2
    " call s:d_header('s:is_last()')
    if type(a:line) == type('')
        let current_line = line(a:line)
    else
        let current_line = a:line
    endif

    let view = winsaveview()
    normal! zj
    normal! zk
    let line = line('.')
    call winrestview(view)

    if  line == current_line
        return 1
    else
        return 0
    endif
endfunction "}}}2


function! s:find_branch_end(line) abort "{{{2
    " call s:d_header('s:find_branch_end()')
    return s:do_fold_function(']z', a:line)
endfunction "}}}2


function! s:find_next(line) abort "{{{2
    " call s:d_header('s:find_next()')
    return s:do_fold_function('zj', a:line)
endfunction "}}}2


function! s:find_max_unfolded() abort "{{{2
    call s:d_header('s:find_max_unfolded()')

    let max_fold_level = s:fold_level
    let line = s:current_line

    while line < s:branch_end
        call s:d_var_msg(line, "line")

        let new_line = s:find_next(line) "if this return 0 wat do?

        if new_line == 0
            call s:d_var_msg(new_line, "new_line")
            call s:d_msg("return early")
            return max_fold_level

        else
            let line = new_line
        endif

        if (foldlevel(line) > max_fold_level) && !s:folded(line)
            let max_fold_level = foldlevel(line)
        endif
    endwhile

    call s:d_msg("return late")

    if s:current_line == line "no nested folds
        return 'no nested folds'
    else
        return max_fold_level
    endif
endfunction "}}}2

function! s:fold_bottom_up(line) abort
    if type(a:line) == type('')
        let current_line = line(a:line)
    else
        let current_line = a:line
    endif

    let view = winsaveview()
    execute current_line

    normal! ]z
    let line = line('.')

    while line('.') > current_line
        normal! zck
    endwhile

    call winrestview(view)
endfunction


function! s:find_max_folded() abort "{{{2
    call s:d_header('s:find_max_folded()')

    if s:branch_end == 0
        call s:d_msg("branch end is on the same line as cursor")
        return 'banch end same as cursor line'
    endif

    let line = s:current_line
    let max_fold_level = -1

    while line < s:branch_end
        call s:d_var_msg(line, "line")

        let new_line = s:find_next(line)
        call s:d_var_msg(new_line, "new_line")

        if new_line == 0 "need to check here if it's folded
            call s:d_msg("found the last line")
            return max_fold_level
        else
            let line = new_line
        endif

        if (foldlevel(line) > max_fold_level) && s:folded(line)
            let max_fold_level = foldlevel(line)
            call s:d_var_msg(max_fold_level, 'max_fold_level')
        endif
    endwhile

    if s:current_line == line
        call s:d_msg("return late")
        return 'did not move'
    else
        call s:d_msg("return late")
        return max_fold_level
    endif
endfunction "}}}2


function! s:indent_level(lnum) "{{{2
    return indent(a:lnum) / &shiftwidth
endfunction "}}}2


function! s:next_non_blank_line(lnum) "{{{2
    let numlines = line('$')
    let current = a:lnum + 1

    while current <= numlines
        if getline(current) =~? '\v\S'
            return current
        endif

        let current += 1
    endwhile

    return -2
endfunction "}}}2
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}


" BOILER PLATE {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let &cpo = s:save_cpo
unlet s:save_cpo
" vim:foldmethod=marker
" vim: textwidth=78
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}
