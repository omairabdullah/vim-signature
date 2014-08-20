" vim-signature is a plugin to toggle, display and navigate marks.
"
" Maintainer:
" Kartik Shenoy
"
" vim: fdm=marker:et:ts=4:sw=2:sts=2
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Exit if the signs feature is not available or if the app has already been loaded (or "compatible" mode set)
if !has('signs') || &cp
  finish
endif
if exists("g:loaded_Signature")
  finish
endif
let g:loaded_Signature = "3"


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" Global variables                                                                                                 {{{1
"
function! s:Set(var, default)
  if !exists(a:var)
    if type(a:default)
      execute 'let' a:var '=' string(a:default)
    else
      execute 'let' a:var '=' a:default
    endif
  endif
endfunction
call s:Set( 'g:SignatureIncludeMarks'               , 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ' )
call s:Set( 'g:SignatureIncludeMarkers'             , ')!@#$%^&*('                                           )
call s:Set( 'g:SignatureMarkTextHL'                 , 'Exception'                                            )
call s:Set( 'g:SignatureMarkerTextHL'               , 'WarningMsg'                                           )
call s:Set( 'g:SignatureEnableDefaultMaps'          , 1                                                      )
call s:Set( 'g:SignatureWrapJumps'                  , 1                                                      )
call s:Set( 'g:SignatureMarkOrder'                  , "\p\m"                                                 )
call s:Set( 'g:SignaturePrioritizeMarks'            , 1                                                      )
call s:Set( 'g:SignatureDeleteConfirmation'         , 0                                                      )
call s:Set( 'g:SignaturePurgeConfirmation'          , 0                                                      )
call s:Set( 'g:SignaturePeriodicRefresh'            , 1                                                      )
call s:Set( 'g:SignatureEnabledAtStartup'           , 1                                                      )
call s:Set( 'g:SignatureDeferPlacement'             , 1                                                      )
call s:Set( 'g:SignatureUnconditionallyRecycleMarks', 0                                                      )
call s:Set( 'g:SignatureErrorIfNoAvailableMarks'    , 1                                                      )
call s:Set( 'g:SignatureForceRemoveGlobal'          , 1                                                      )


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" Commands and autocmds                                                                                            {{{1
"
if has('autocmd')
  augroup sig_autocmds
    autocmd!
    autocmd BufEnter,CmdwinEnter * call signature#SignRefresh()
    autocmd CursorHold * if g:SignaturePeriodicRefresh | call signature#SignRefresh() | endif
  augroup END
endif

command! -nargs=0 SignatureToggleSigns call signature#Toggle()
command! -nargs=0 SignatureRefresh     call signature#SignRefresh( "force" )
command! -nargs=0 SignatureList        call signature#ListLocalMarks()


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"" Misc                                              {{{1
"
function! signature#Init()                                                                                        " {{{2
  " Description: Initialize variables

  " b:sig_marks = { lnum => signs_str }
  call s:Set( 'b:sig_marks'               , {} )
  " b:sig_markers = { lnum => marker }
  call s:Set( 'b:sig_markers'             , {} )
  call s:Set( 'b:sig_enabled'             , g:SignatureEnabledAtStartup )
  call s:Set( 'b:SignatureIncludeMarks'   , g:SignatureIncludeMarks    )
  call s:Set( 'b:SignatureIncludeMarkers' , g:SignatureIncludeMarkers  )
  call s:Set( 'b:SignatureMarkOrder'      , g:SignatureMarkOrder       )
  call s:Set( 'b:SignaturePrioritizeMarks', g:SignaturePrioritizeMarks )
  call s:Set( 'b:SignatureDeferPlacement' , g:SignatureDeferPlacement  )
  call s:Set( 'b:SignatureWrapJumps'      , g:SignatureWrapJumps       )
endfunction


function! signature#MarksList(...)                                                                                " {{{2
  " Description: Takes two optional arguments - mode/line no. and scope
  "              If no arguments are specified, returns a list of [mark, line no.] pairs that are in use in the buffer
  "              or are free to be placed in which case, line no. is 0
  "
  " Arguments: a:1 (mode)  = 'used' : Returns list of [ [used marks, line no., buf no.] ]
  "                          'free' : Returns list of [ free marks ]
  "                          <lnum> : Returns list of used marks on current line.
  "            a:2 (scope) = 'b'    : Limits scope to current buffer i.e used/free marks in current buffer
  "                          'g'    : Set scope to global i.e used/free marks from all buffers

  let l:marks_list = []

  " Add local marks first
  for i in filter( split( b:SignatureIncludeMarks, '\zs' ), 'v:val =~# "[a-z]"' )
    let l:marks_list = add(l:marks_list, [i, line("'" . i), bufnr('%')])
  endfor

  " Add global (uppercase) marks to list
  for i in filter( split( b:SignatureIncludeMarks, '\zs' ), 'v:val =~# "[A-Z]"' )
    let [ l:buf, l:line, l:col, l:off ] = getpos( "'" . i )
    if ( a:0 > 1) && ( a:2 ==? "b" )
      " If it is not in use in the current buffer treat it as free
      if l:buf != bufnr('%')
        let l:line = 0
      endif
    endif
    let l:marks_list = add(l:marks_list, [i, l:line, l:buf])
  endfor

  if ( a:0 == 0 )
    return l:marks_list
  elseif ( a:1 ==? "used" )
    return filter( l:marks_list, 'v:val[1] > 0' )
  elseif ( a:1 ==? "free" )
    return map( filter( l:marks_list, 'v:val[1] == 0' ), 'v:val[0]' )
  elseif ( a:1 > 0 ) && ( a:1 < line('$'))
    return map( filter( l:marks_list, 'v:val[1] == ' . a:1 ), 'v:val[0]' )
  endif
endfunction


function! signature#ToggleSign( sign, mode, lnum )        " {{{2
  " Description: Enable/Disable/Toggle signs for marks/markers on the specified line number, depending on value of mode
  " Arguments:
  "   sign : The mark/marker whose sign is to be placed/removed/toggled
  "   mode : 'remove'
  "        : 'place'
  "   lnum : Line number on/from which the sign is to be placed/removed
  "          If mode = "remove" and line number is 0, the 'sign' is removed from all lines

  "echom "DEBUG: sign = " . a:sign . ",  mode = " . a:mode . ",  lnum = " . a:lnum

  " If Signature is not enabled, return
  if !b:sig_enabled | return | endif

  " FIXME: Highly inefficient. Needs work
  " Place sign only if there are no signs from other plugins (eg. syntastic)
  "let l:present_signs = signature#SignInfo(1)
  "if b:SignatureDeferPlacement && has_key( l:present_signs, a:lnum ) && l:present_signs[a:lnum]['name'] !~# '^sig_Sign_'
    "return
  "endif

  let l:lnum = a:lnum
  let l:id   = ( winbufnr(0) + 1 ) * l:lnum

  " Toggle sign for markers                         {{{3
  if stridx( b:SignatureIncludeMarkers, a:sign ) >= 0

    if a:mode ==? "place"
      let b:sig_markers[l:lnum] = a:sign . get( b:sig_markers, l:lnum, "" )
    else
      let b:sig_markers[l:lnum] = substitute( b:sig_markers[l:lnum], "\\C" . escape( a:sign, '$^' ), "", "" )

      " If there are no markers on the line, delete signs on that line
      if b:sig_markers[l:lnum] == ""
        call remove( b:sig_markers, l:lnum )
      endif
    endif

  " Toggle sign for marks                           {{{3
  else
    if a:mode ==? "place"
      let b:sig_marks[l:lnum] = a:sign . get( b:sig_marks, l:lnum, "" )
    else
      " If l:lnum == 0, remove from all lines
      if l:lnum == 0
        let l:arr = keys( filter( copy(b:sig_marks), 'v:val =~# a:sign' ))
        if empty(l:arr) | return | endif
      else
        let l:arr = [l:lnum]
      endif

      for l:lnum in l:arr
        let l:id   = ( winbufnr(0) + 1 ) * l:lnum
        let b:sig_marks[l:lnum] = substitute( b:sig_marks[l:lnum], "\\C" . a:sign, "", "" )

        " If there are no marks on the line, delete signs on that line
        if b:sig_marks[l:lnum] == ""
          call remove( b:sig_marks, l:lnum )
        endif
      endfor
    endif
  endif
  "}}}3

  " Place the sign
  if ( has_key( b:sig_marks, l:lnum ) && ( b:SignaturePrioritizeMarks || !has_key( b:sig_markers, l:lnum )))
    let l:str = substitute( b:SignatureMarkOrder, "\m", strpart( b:sig_marks[l:lnum], 0, 1 ), "" )
    let l:str = substitute( l:str,                "\p", strpart( b:sig_marks[l:lnum], 1, 1 ), "" )

    " If g:SignatureMarkTextHL points to a function then call it and use its output as the highlight group.
    " If it is a string, use it directly
    if g:SignatureMarkTextHL =~ ')$'
      exec 'let l:SignatureMarkTextHL = ' . g:SignatureMarkTextHL
    else
      let l:SignatureMarkTextHL = g:SignatureMarkTextHL
    endif
    execute 'sign define sig_Sign_' . l:id . ' text=' . l:str . ' texthl=' . l:SignatureMarkTextHL

  elseif has_key( b:sig_markers, l:lnum )
    let l:str = strpart( b:sig_markers[l:lnum], 0, 1 )

    " If g:SignatureMarkerTextHL points to a function then call it and use its output as the highlight group.
    " If it is a string, use it directly
    if g:SignatureMarkerTextHL =~ ')$'
      exec 'let l:SignatureMarkerTextHL = ' . g:SignatureMarkerTextHL
    else
      let l:SignatureMarkerTextHL = g:SignatureMarkerTextHL
    endif
    execute 'sign define sig_Sign_' . l:id . ' text=' . l:str . ' texthl=' . l:SignatureMarkerTextHL

  else
    execute 'sign unplace ' . l:id
    return
  endif
  execute 'sign place ' . l:id . ' line=' . l:lnum . ' name=sig_Sign_' . l:id . ' buffer=' . winbufnr(0)
endfunction


function! signature#SignRefresh(...)              " {{{2
  " Description: Add signs for new marks/markers and remove signs for deleted marks/markers
  " Arguments: '1' to force a sign refresh

  call signature#Init()
  " If Signature is not enabled, return
  if !b:sig_enabled | return | endif

  for i in signature#MarksList( 'free', 'b' )
    " ... remove it
    call signature#ToggleSign( i, "remove", 0 )
  endfor

  " Add signs for marks ...
  for j in signature#MarksList( 'used', 'b' )
    " ... if mark is not present in our b:sig_marks list or if it is present but at the wrong line,
    " remove the old sign and add a new one
    if !has_key( b:sig_marks, j[1] ) || b:sig_marks[j[1]] !~# j[0] || a:0
      call signature#ToggleSign( j[0], "remove", 0    )
      call signature#ToggleSign( j[0], "place" , j[1] )
    endif
  endfor

  " We do not add signs for markers as SignRefresh is executed periodically and we don't have a way to determine if the
  " marker already has a sign or not
endfunction


function! s:CreateMap( map, cmd, ... )
  let l:plug = '<Plug>(Signature' . a:map .')'
  execute 'nnoremap <silent> <unique> ' . l:plug . ' :<C-U> call ' . escape(a:cmd, "'") . '<CR>'
  if g:SignatureEnableDefaultMaps && a:0
    execute 'nmap <silent> <unique> ' . a:1 . ' ' . l:plug
  endif
endfunction
call s:CreateMap( 'Leader'           , 'signature#Input()'                            , "m"        )
call s:CreateMap( 'PlaceNextMark'    , 'signature#ToggleMark("next")'                 , 'm,'       )
call s:CreateMap( 'ToggleMarkAtLine' , 'signature#ToggleMarkAtLine()'                 , 'm.'       )
call s:CreateMap( 'PurgeMarks'       , 'signature#PurgeMarks()'                       , 'm<Space>' )
call s:CreateMap( 'PurgeMarksAtLine' , 'signature#PurgeMarksAtLine()'                 , 'm-'       )
call s:CreateMap( 'GotoPrevSpotByPos', 'signature#GotoMark( "prev", "spot", "pos" )'  , '[`'       )
call s:CreateMap( 'GotoNextSpotByPos', 'signature#GotoMark( "next", "spot", "pos" )'  , ']`'       )
call s:CreateMap( 'GotoPrevLineByPos', 'signature#GotoMark( "prev", "line", "pos" )'  , "['"       )
call s:CreateMap( 'GotoNextLineByPos', 'signature#GotoMark( "next", "line", "pos" )'  , "]'"       )
call s:CreateMap( 'GotoPrevSpotAlpha', 'signature#GotoMark( "prev", "spot", "alpha" )', '`['       )
call s:CreateMap( 'GotoNextSpotAlpha', 'signature#GotoMark( "next", "spot", "alpha" )', '`]'       )
call s:CreateMap( 'GotoPrevLineAlpha', 'signature#GotoMark( "prev", "line", "alpha" )', "'["       )
call s:CreateMap( 'GotoNextLineAlpha', 'signature#GotoMark( "next", "line", "alpha" )', "']"       )
call s:CreateMap( 'ListLocalMarks'   , 'signature#ListLocalMarks()'                   , "'?"       )
call s:CreateMap( 'GotoPrevMarker'   , 'signature#GotoMarker( "prev", "same" )'       , '[-'       )
call s:CreateMap( 'GotoNextMarker'   , 'signature#GotoMarker( "next", "same" )'       , ']-'       )
call s:CreateMap( 'GotoPrevMarkerAny', 'signature#GotoMarker( "prev", "any" )'        , '[='       )
call s:CreateMap( 'GotoNextMarkerAny', 'signature#GotoMarker( "next", "any" )'        , ']='       )
call s:CreateMap( 'PurgeMarkers'     , 'signature#PurgeMarkers()'                     , 'm<BS>'    )
" }}}1
