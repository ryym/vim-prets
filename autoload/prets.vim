let s:initialized = 0
let s:ch = -1
let s:connected = 0
let s:is_auto_save = 0

let s:plugin_root = expand('<sfile>:p:h:h')

function! prets#enable_auto_save() abort
  if !s:initialized
    call prets#start_server()
    let s:initialized = 1
  endif
endfunction

function! prets#start_server() abort
  call system("npm run start --prefix " . s:plugin_root . "&")
  " sleep 200m
endfunction

function! prets#connect() abort
  let s:ch = ch_open('localhost:4242', {'mode': 'json'})
  let s:connected = 1
endfunction

function! prets#request_format() abort
  let s:target_buf = bufnr('%')
  let s:win_state = winsaveview()
  let filepath = expand('%:p')
  let src = join(getline(1, '$'), "\n")
  call ch_sendexpr(s:ch, {
    \   'source': src,
    \   'path':filepath,
    \ }, {
    \   'callback': funcref('prets#_on_response'),
    \ })
endfunction

function prets#_on_response(_ch, res)
  let lines = split(a:res.source, "\n")
  let cur_buf = bufnr('%')
  if bufexists(s:target_buf)
    execute 'keepalt buffer' s:target_buf

    " XXX: Sometime internal error occurs.
    silent! execute '1,$delete'

    call setbufline(s:target_buf, 1, lines)

    if cur_buf == s:target_buf
      call winrestview(s:win_state)
    else
      execute 'keepalt buffer' cur_buf
    endif
  endif

  let s:is_auto_save = 1
  execute 'write'
  let s:is_auto_save = 0
endfunction

function prets#format_on_save() abort
  if !s:connected
    call prets#connect()
  endif

  if !s:is_auto_save
    call prets#request_format()
  endif
endfunction
