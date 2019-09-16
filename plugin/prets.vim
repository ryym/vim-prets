" command PretsStart call prets#connect()

augroup prets
  autocmd!

  autocmd BufWritePre *.prets.js call prets#format_on_save()
augroup END
