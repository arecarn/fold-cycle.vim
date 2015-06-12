""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Original Author: Ryan Carney
" License: WTFPL
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""{{{1
let s:save_cpo = &cpo
set cpo&vim
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}1

" PRIVATE FUNCTIONS DEBUG {{{1
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:d_header(text) abort "{{{2
    try
        call util#debug#print_header(a:text)
    catch
    endtry
endfunction "}}}2

function! s:d_var_msg(variable, text) abort "{{{2
    try
        call util#debug#print_var_msg(a:variable, a:text)
    catch
    endtry
endfunction "}}}2

function! s:d_msg(text) abort "{{{2
    try
        call util#debug#print_msg(a:text)
    catch
    endtry
endfunction "}}}2

function! s:d_msg(text) abort "{{{2
    try
        call util#debug#print_msg(a:text)
    catch
    endtry
endfunction "}}}2
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}1

" FOLD CYCLING {{{1
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" SYMBOLIC VARIABLES {{{2
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"TODO max_closed_fold_level/max_open_fold_level can be 0 so I don't think these
"should be 0
let s:NOT_A_FOLD = -1
let s:NO_MORE_FOLDS_FOUND = 0
let s:NO_BRANCH_END_FOUND = 0
let s:NO_NESTED_FOLDS = -2

let s:START = 1
let s:END  = 0

let s:TRUE = 1
let s:FALSE  = 0
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}2

" PRIVATE FUNCTIONS {{{2
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:open_branch() abort "{{{3
    execute s:branch_start . ',' . s:branch_end . ' foldopen!'
endfunction "}}}3

function! s:close_branch() abort "{{{3
    execute s:branch_start . ',' . s:branch_end . ' foldclose!'
endfunction "}}}3

function! s:init() abort "{{{3
    call s:d_header('init')

    let s:current_line = line('.')
    call s:d_var_msg(s:current_line, 's:current_line')

    let s:fold_level = foldlevel(s:current_line)
    call s:d_var_msg(s:fold_level, 's:fold_level')

    let s:is_a_fold = s:fold_level != 0
    call s:d_var_msg(s:is_a_fold, 's:is_a_fold')

    if !s:is_a_fold
        return 0
    endif

    let s:folded = s:folded('.')
    call s:d_var_msg(s:folded, 's:folded')

    let s:branch_start = s:find_branch_start(s:current_line)
    call s:d_var_msg(s:branch_start, 's:branch_start')

    let s:branch_end = s:find_branch_end(s:current_line)
    call s:d_var_msg(s:branch_end, 's:branch_end')

    if s:branch_end == s:NOT_A_FOLD || s:branch_start == s:NOT_A_FOLD
        return
    endif

    let s:max_closed_fold_level = s:find_max_closed_fold_level(s:branch_start, s:branch_end)
    call s:d_var_msg(s:max_closed_fold_level, 's:max_closed_fold_level')

    let s:max_open_fold_level = s:find_max_open_fold_level(s:branch_start, s:branch_end)
    call s:d_var_msg(s:max_open_fold_level, 's:max_open_fold_level')

    return 1
endfunction "}}}3

function! s:folded(line) abort "{{{3
    return foldclosed(a:line) == -1 ? 0 : 1
endfunction "}}}3

function! s:handle_line(line) abort "{{{3
    if type(a:line) == type('')
        let line = line(a:line)
    else
        let line = a:line
    endif
    return line
endfunction "}}}3

function! s:find_branch_end(line) abort "{{{3
    return s:do_find_branch(a:line, s:END)
endfunction "}}}3

function! s:find_branch_start(line) abort "{{{3
    return s:do_find_branch(a:line, s:START)
endfunction "}}}3

function! s:do_find_branch(line, type) abort "{{{3
    let line = s:handle_line(a:line)

    let view = winsaveview()
    let value = 0

    if !s:folded(line)
        let s:close_flag = s:TRUE
    else
        let s:close_flag = s:FALSE
    endif

    try
        if s:close_flag
            normal! zc
        endif

        if a:type == s:START
            let value = foldclosed(line)
        elseif a:type == s:END
            let value = foldclosedend(line)
        endif

        if s:close_flag
            normal! zo
        endif

    catch ^Vim\%((\a\+)\)\=:E490
        let value = 0 "TODO use symbolic constant

    endtry
    call winrestview(view)

    return value
endfunction "}}}3

function! s:is_a_fold(line) abort "{{{3
    let line = s:handle_line(a:line)

    let view = winsaveview()
    let value = 0

    if s:folded(line)
        let value = s:TRUE
    else
        try
            normal! zc
            let value = s:folded(line)
            normal! zo
        catch ^Vim\%((\a\+)\)\=:E490
            let value = 0 "TODO use symbolic constant
        endtry
    endif

    call winrestview(view)
    call s:d_var_msg(value, 'value')
    return value
endfunction "}}}3

function! s:do_fold_function(fold_keys, line) abort "{{{3
    let line = s:handle_line(a:line)

    let view = winsaveview()
    execute line
    execute 'normal! ' . a:fold_keys
    let line = line('.')

    while !s:is_a_fold(line)
        let line_before = line
        call s:d_var_msg(line_before, 'line_before')
        execute 'normal! ' . a:fold_keys
        let line = line('.')
        call s:d_var_msg(line, 'line')
        if line == line_before
            let line = s:NO_MORE_FOLDS_FOUND
            break
        endif
    endwhile

    call winrestview(view)

    if line == a:line
        return s:NO_MORE_FOLDS_FOUND
    else
        return line
    endif
endfunction "}}}3

function! s:find_next(line) abort "{{{3
    " call s:d_header('s:find_next()')
    return s:do_fold_function('zj', a:line)
endfunction "}}}3

function! s:find_max_open_fold_level(start, end) abort "{{{3
    call s:d_header('s:find_max_open_fold_level()')

    let max_fold_level = 0
    let line = a:start

    while line < a:end
        if (foldlevel(line) > max_fold_level) && !s:folded(line)
            let max_fold_level = foldlevel(line)
            call s:d_var_msg(max_fold_level, 'max_fold_level')
        endif

        let line = s:find_next(line)
        call s:d_var_msg(line , "line")

        if line == s:NO_MORE_FOLDS_FOUND
            call s:d_msg("return early: no more folds found")
            return max_fold_level
        endif
    endwhile

    call s:d_msg("return late")

    if a:start == line
        call s:d_msg("return late: a:start == line")
        return s:NO_NESTED_FOLDS
    else
        return max_fold_level
    endif
endfunction "}}}3

function! s:find_max_closed_fold_level(start, end) abort "{{{3
    call s:d_header('s:find_max_closed_fold_level()')

    "TODO try to make this happen
    if a:end == s:NO_BRANCH_END_FOUND
        call s:d_msg('branch end is on the same line as cursor')
        return s:NOT_A_FOLD
    endif

    let line = a:start
    let max_fold_level = foldlevel(a:start)

    while line < a:end
        call s:d_var_msg(line, "line")
        if (foldlevel(line) > max_fold_level) && s:folded(line)
            let max_fold_level = foldlevel(line)
            call s:d_var_msg(max_fold_level, 'max_fold_level')
        endif

        let line = s:find_next(line)
        call s:d_var_msg(line, "line")

        if line == s:NO_MORE_FOLDS_FOUND
            call s:d_msg("return early: no more folds found")
            return max_fold_level
        endif
    endwhile

    call s:d_msg("return late")

    return max_fold_level
endfunction "}}}3

function! s:close_all(start, end) abort "{{{3

    let level = s:max_open_fold_level
    while !s:folded(s:current_line)
        call s:close_level(a:start, a:end, level)
        let level = level - 1
    endwhile
endfunction "}}}3

function! s:close_level(start, end, level) abort "{{{3

    if a:level == s:NO_NESTED_FOLDS
        foldclose
        return
    endif

    let line = a:start

    while line <= a:end
        if foldlevel(line) == a:level && !s:folded(line)
            call s:d_msg('folding line ' . line)
            execute line . 'foldclose'
        endif

        let line = s:find_next(line)
        call s:d_var_msg(line, 'line')
        if line == s:NO_MORE_FOLDS_FOUND
            call s:d_msg('break from close_level()')
            return
        endif
    endwhile
endfunction "}}}3

function! s:open_level(start, end, level) abort "{{{3
    let line = a:start

    while line < a:end
        call s:d_var_msg(line, 'line')
        if foldlevel(line) <= a:level && s:folded(line)
            call s:d_msg("opening line " . line)
            execute line . 'foldopen'
        endif

        let line = s:find_next(line)
        if line == s:NO_MORE_FOLDS_FOUND
            call s:d_msg("no more folds" . line)
            return
        endif
    endwhile
endfunction "}}}3
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}2

" PUBLIC FUNCTIONS {{{2
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! fold_cycle#open() abort "{{{3
    if !s:init()
        call s:d_msg("init() failed")
        return
    endif

    if s:folded
        call s:d_msg("opening fold :1")
        foldopen
        return
    elseif s:max_closed_fold_level == s:fold_level
        call s:d_msg("closing all folds")
        call s:close_all(s:branch_start, s:branch_end)
        return
    else
        call s:open_level(s:branch_start, s:branch_end, s:max_closed_fold_level)
    endif
endfunction "}}}3

function! fold_cycle#close() abort "{{{3
    if !s:init()
        call s:d_msg("init() failed")
        return
    endif

    if s:folded
        call s:d_msg("opening all folds: is folded")
        call s:open_branch()
        return
    elseif s:max_open_fold_level == 0
        call s:d_msg("opening all folds: s:max_open_fold_level = 0")
        call s:open_branch()
        return
    elseif s:max_open_fold_level == s:NO_NESTED_FOLDS
        call s:d_msg("closing fold: s:max_open_fold_level = s:NO_NESTED_FOLDS")
        foldclose
        return
    elseif s:max_open_fold_level == s:fold_level
        call s:d_msg("closing fold: s:max_open_fold_level = s:fold_level")
        foldclose
        return
    endif

    call s:close_level(s:branch_start, s:branch_end, s:max_open_fold_level)
endfunction "}}}3

function! fold_cycle#open_global() abort "{{{3
    let max_closed_fold_level = s:find_max_closed_fold_level(1, line('$'))
    echomsg max_closed_fold_level

    if max_closed_fold_level == 0
        normal! zM
    else
        call s:open_level(1, line('$'), max_closed_fold_level)
        let new_max_closed_fold_level = s:find_max_closed_fold_level(1, line('$'))
        echomsg new_max_closed_fold_level
        if new_max_closed_fold_level == max_closed_fold_level
            normal! zM
        endif
    endif
endfunction "}}}3

function! fold_cycle#close_global() abort "{{{3
    let max_open_fold_level = s:find_max_open_fold_level(1, line('$'))
    call s:d_var_msg(max_open_fold_level, 'max_open_fold_level')

    if max_open_fold_level == 0
        call s:d_msg('opeing all folds')
        normal! zR
    else
        call s:close_level(1, line('$'), max_open_fold_level)
        call s:d_msg('close a level')
    endif
endfunction "}}}3
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}2
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""{{{1
let &cpo = s:save_cpo
unlet s:save_cpo
" vim:foldmethod=marker
" vim:textwidth=78
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}1
