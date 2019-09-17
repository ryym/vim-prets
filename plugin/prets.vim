augroup prets
  autocmd!

  autocmd FileType javascript,javascript.jsx,typescript,typescript.tsx,scss,html call prets#enable_auto_save()

  " XXX: Should be defined by users.
  autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.scss,*.graphql,*.vue,*.html call prets#format_on_save()
augroup END
