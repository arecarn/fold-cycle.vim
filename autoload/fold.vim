""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Original Author: Ryan Carney
" License: WTFPL
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" BOILER PLATE {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:save_cpo = &cpo
set cpo&vim
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}

" SYMBOLIC VARIABLES {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"TODO max_folded_level/max_unfolded_level can be 0 so I don't think these
"should be 0
let s:NOT_A_FOLD = -1
let s:NO_MORE_FOLDS_FOUND = 0
let s:NO_BRANCH_END_FOUND = 0
let s:NO_NESTED_FOLDS = 0
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}

" PRIVATE FUNCTIONS DEBUG {{{
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
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}

" PRIVATE FUNCTIONS {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:folded(line) abort "{{{2
    return foldclosed(a:line) == -1 ? 0 : 1
endfunction "}}}2

function! s:find_branch_end(line) abort "{{{2

    if type(a:line) == type('')
        let current_line = line(a:line)
    else
        let current_line = a:line
    endif

    let view = winsaveview()
    let last = 0
    if !s:folded(s:current_line)
        try
            normal! zc
            let last = foldclosedend('.')
            normal! zo
        catch ^Vim\%((\a\+)\)\=:E490
            let last = 0 "TODO use symbolic constant
        endtry
    endif
    call winrestview(view)

    return last
endfunction "}}}2

function! s:init() abort "{{{2
    call s:d_header('init')

    let s:current_line = line('.')
    call s:d_var_msg(s:current_line, 's:current_line')

    let s:folded = s:folded('.')
    call s:d_var_msg(s:folded, 's:folded')

    let s:fold_level = foldlevel(s:current_line)
    call s:d_var_msg(s:fold_level, 's:fold_level')

    let s:is_a_fold = s:fold_level != 0
    call s:d_var_msg(s:fold_level, 's:fold_level')

    let s:branch_end = s:find_branch_end(s:current_line)
    call s:d_var_msg(s:branch_end, 's:branch_end')

endfunction "}}}2

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

function! s:find_next(line) abort "{{{2
    " call s:d_header('s:find_next()')
    return s:do_fold_function('zj', a:line)
endfunction "}}}2

function! s:find_max_unfolded() abort "{{{2
    call s:init()
    call s:d_header('s:find_max_unfolded()')

    let max_fold_level = s:fold_level
    let line = s:current_line

    while line < s:branch_end
        if (foldlevel(line) > max_fold_level) && !s:folded(line)
            let max_fold_level = foldlevel(line)
            call s:d_var_msg(max_fold_level, 'max_fold_level')
        endif

        let line  = s:find_next(line)
        call s:d_var_msg(line , "line")

        if line  == s:NO_MORE_FOLDS_FOUND
            call s:d_msg("return early: no more folds found")
            return max_fold_level
        endif
    endwhile

    call s:d_msg("return late")

    if s:current_line == line
        "TODO we do get here but should we?
        call s:d_msg("return late: current_line == line")
        return s:NO_NESTED_FOLDS
    else
        return max_fold_level
    endif
endfunction "}}}2

function! s:find_max_folded() abort "{{{2
    call s:init()
    call s:d_header('s:find_max_folded()')

    "TODO try to make this happen
    if s:branch_end == s:NO_BRANCH_END_FOUND
        call s:d_msg('branch end is on the same line as cursor')
        return s:NOT_A_FOLD
    endif

    let line = s:current_line
    let max_fold_level = s:fold_level

    while line < s:branch_end
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
endfunction "}}}2

function! s:branch_close() abort "{{{2
    let max_unfolded_level = s:find_max_unfolded()

    while !s:folded(s:current_line)
        let line = s:current_line


        while line <= s:branch_end
            if foldlevel(line) == max_unfolded_level
                call s:d_msg('folding line ' . line)
                execute line . 'foldclose'
            endif

            if max_unfolded_level == s:NO_NESTED_FOLDS
                foldclose
                return
            endif

            let line = s:find_next(line)
            call s:d_var_msg(line, 'line')
            if line == s:NO_MORE_FOLDS_FOUND
                call s:d_msg('break from branch_close()')
                break
            endif
        endwhile
        let max_unfolded_level = max_unfolded_level - 1
    endwhile
endfunction "}}}2
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}

" PUBLIC FUNCTIONS MAPPINGS {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! fold#open() abort "{{{2
    " call s:d_header('fold#open()')
    let max_folded_level = s:find_max_folded()
    call s:d_var_msg(max_folded_level, 'max_folded_level')

    if s:folded
        call s:d_msg("opening fold :1")
        foldopen
        return
    elseif max_folded_level == s:NOT_A_FOLD
        call s:d_msg("do nothing no branch end found")
        return
    elseif max_folded_level == s:fold_level
        call s:d_msg("closing all folds")
        call s:branch_close()
        return
    endif

    let line = s:current_line
    while line < s:branch_end
        call s:d_var_msg(line, 'line')
        if foldlevel(line) == max_folded_level
            call s:d_msg("opening line " . line)
            execute line . 'foldopen'
        endif

        let line = s:find_next(line)
        if line == s:NO_MORE_FOLDS_FOUND
            return
        endif
    endwhile
endfunction "}}}2

function! fold#close() abort "{{{2

    let max_unfolded_level = s:find_max_unfolded()
    call s:d_var_msg(max_unfolded_level, 'max_unfolded_level')

    if s:folded
        call s:d_msg("opening all folds: is folded")
        foldopen!
        return
    elseif max_unfolded_level == s:NOT_A_FOLD
        call s:d_msg("do nothing no branch end found")
        return
    elseif max_unfolded_level == s:NO_NESTED_FOLDS
        call s:d_msg("opening all folds: max_unfolded_level = s:NO_NESTED_FOLDS")
        foldclose
        return
    elseif max_unfolded_level == s:fold_level
        call s:d_msg("opening all folds: max_unfolded_level = s:fold_level")
        foldclose
        return
    elseif max_unfolded_level == 0
        call s:d_msg("opening all folds: max_unfolded_level = 0")
        foldopen!
        return
    endif


    let line = line('.')
    while line < s:branch_end
        if foldlevel(line) == max_unfolded_level
            call s:d_msg('folding line ' . line)
            execute line . 'foldclose'
        endif
        let line = s:find_next(line)
        if line == s:NO_MORE_FOLDS_FOUND
            return
        endif
    endwhile

endfunction "}}}2
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}

" PUBLIC FUNCTIONS VISUALS {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! fold#clean_fold_text(foldchar) "{{{2
    " call so:d_header('fold#clean_fold()')
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

function! fold#cleanest_fold_text() "{{{2
    " call so:d_header('fold#clean_fold()')
    "TODO handle wide chars with visual col
    let line = getline(v:foldstart)

    " don't include fold markers in fold text it's ugly :)
    if &foldmethod == 'marker'
        let foldmarker = substitute(&foldmarker, '\zs,.*', '', '')
        let cmt = substitute(&commentstring, '\zs%s.*', '', '')
        let line = substitute(line, '\s*'. '\('.cmt.'\)\?'. '\s*'.foldmarker.'\d*\s*', '', 'g')
    endif

    " Foldtext ignores tabstop and shows tabs as one space,
    " so convert tabs to 'tabstop' spaces so text lines up
    let ts = repeat(' ',&tabstop)
    let line = substitute(line, '\t', ts, 'g')

    return line . repeat(' ', winwidth(0)-len(line))
endfunction "}}}2

function! fold#get_clean_fold_expr(lnum) "{{{2
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

" PRIVATE FUNCTIONS VISUALS {{{
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
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
" vim:textwidth=78
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""}}}
