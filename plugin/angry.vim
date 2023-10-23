" Author:  Bjorn Winckler
" Version: 0.1
" License: (c) 2012 Bjorn Winckler.  Licensed under the same terms as Vim.
"
" Summary:
"
" Text objects for function arguments ('arg' means 'angry' in Swedish) and
" other items surrounded by brackets and separated by commas.
"
" TODO:
"
" - Growing selection in visual mode does not work
" - Comments are not handled properly (difficult to accomodate all styles,
"   e.g. comment after argument, comment on line above argument, ...)
" - Support empty object (e.g. ',,' and ',/* comment */,')

" 使用 g:loaded_angry 全局变量判断插件是否已加载
" &cp 是 'compatible' 的缩写，布尔值，true 表示兼容 vi，& 是对 vim option 特有
" 的取值语法
" v:version 是 vim 的预定义变量，主版本 * 100 
" |，bar，h :bar，用于分割命令
if exists("g:loaded_angry") || &cp || v:version < 700 | finish | endif
let g:loaded_angry = 1

"
" Map to text objects aa (An Argument) and ia (Inner Argument) unless
" disabled.
"
" The objects aA and iA are similar to aa and ia, except aA and iA match at
" closing brackets, whereas aa and ia match at opening brackets and commas.
" Generally, the lowercase versions match to the right and the uppercase
" versions match to the left of the cursor.
"
if !exists("g:angry_disable_maps")
  vmap <silent> aa <Plug>AngryOuterPrefix
  omap <silent> aa <Plug>AngryOuterPrefix
  vmap <silent> ia <Plug>AngryInnerPrefix
  omap <silent> ia <Plug>AngryInnerPrefix

  vmap <silent> aA <Plug>AngryOuterSuffix
  omap <silent> aA <Plug>AngryOuterSuffix
  vmap <silent> iA <Plug>AngryInnerSuffix
  omap <silent> iA <Plug>AngryInnerSuffix
endif

"
" Specify which separator to use.
"
" TODO: This should probably be determined on a per-buffer (or filetype) basis.
"
if !exists('g:angry_separator')
  let g:angry_separator = ','
endif
vnoremap <silent> <script> <Plug>AngryOuterPrefix :<C-U>call
      \ <SID>List(g:angry_separator, 1, 1, v:count1, visualmode())<CR>
vnoremap <silent> <script> <Plug>AngryOuterSuffix :<C-U>call
      \ <SID>List(g:angry_separator, 0, 1, v:count1, visualmode())<CR>
vnoremap <silent> <script> <Plug>AngryInnerPrefix :<C-U>call
      \ <SID>List(g:angry_separator, 1, 0, v:count1, visualmode())<CR>
vnoremap <silent> <script> <Plug>AngryInnerSuffix :<C-U>call
      \ <SID>List(g:angry_separator, 0, 0, v:count1, visualmode())<CR>

onoremap <silent> <script> <Plug>AngryOuterPrefix :call
      \ <SID>List(g:angry_separator, 1, 1, v:count1)<CR>
onoremap <silent> <script> <Plug>AngryOuterSuffix :call
      \ <SID>List(g:angry_separator, 0, 1, v:count1)<CR>
onoremap <silent> <script> <Plug>AngryInnerPrefix :call
      \ <SID>List(g:angry_separator, 1, 0, v:count1)<CR>
onoremap <silent> <script> <Plug>AngryInnerSuffix :call
      \ <SID>List(g:angry_separator, 0, 0, v:count1)<CR>


"
" Select item in a list.
"
" The list is enclosed by brackets (i.e. '()', '[]', or '{}').  Items are
" separated by a:sep (e.g. ',').
"
" If a:prefix is set, then outer selections include the leftmost separator but
" not the rightmost, and vice versa if a:prefix is not set.
"
" If a:outer is set an outer selection is made (which includes separators).
" If a:outer is not set an inner selection is made (which does not include
" separators on the boundary).  Outer selections are useful for deleting
" items, inner selection are useful for changing items.
"
function! s:List(sep, prefix, outer, times, ...)
  let lbracket = '[[({]'
  let rbracket = '[])}]'
  let save_mb = getpos("'b")
  let save_me = getpos("'e")
  let save_unnamed = @"
  let save_ic = &ic
  let &ic = 0

  try
    " Backward search for separator or unmatched left bracket.
    " 向后搜索且到不使用文件环绕，
    " 如果 prefix 为 true 多了个 flag c，差别：
    " 1. 如果停留在{start}上，那当前光标会作为结果，没有flag会返回0
    " 2. 如果停留在 {end} 上，那会被认为是嵌套组，返回 0，没有flag会跳到分割符
    " 3. 如果停留在分割符上，那当前光标会作为结果，没有flag会返回上个分割符
    " 4. 如果停留在分割符右边，那上个分割会作为结果，没有flag也一样
    " 总结意图：向后搜索匹配的分割符或左括号
    " 开启prefix则接受光标下的左括号或分割符
    let flags = a:prefix ? 'bcW' : 'bW'
    if searchpair(lbracket, a:sep, rbracket, flags,
          \ 's:IsCursorOnStringOrComment()') <= 0
      return
    endif
    " 经过 searchpair 此时光标会移动到左括号或分割符上
    " 复制当前光标字符且设置一个标记，b 记录了左括号或分割符位置
    exe "normal! ylmb"
    " 从无名寄存器获取刚刚复制的左括号或分割符
    let first = @"

    " Forward search for separator or unmatched right bracket as many times as
    " specified by the command count.
    " 正向搜索分割符或右括号
    " 因为没有 flag c，所以即使当前光标为分割符也会跳过当前的
    if searchpair(lbracket, a:sep, rbracket, 'W',
          \ 's:IsCursorOnStringOrComment()') <= 0
      return
    endif
    " 经过 searchpair 此时光标会移动到下个分割符或右括号上
    " 复制当前光标字符到无名寄存器上
    exe "normal! yl"
    " times 支持多跳，因为已经跳过一次了，所以减一
    let times = a:times - 1
    " 如果当前不为右括号，则继续跳转到下个分割符直到 times 次
    while times > 0 && @" =~ a:sep && searchpair(lbracket, a:sep, rbracket,
          \ 'W', 's:IsCursorOnStringOrComment()') > 0
      let times -= 1
      exe "normal! yl"
    endwhile
    " 记录最后一跳后，当前光标下的字符，可能是右括号或分割符
    let last = @"

    " TODO: The below code is incorrect if the selection is too small.
    "
    " NOTE: The calls to searchpair() with pattern '\%0l' is used only for its
    " 'skip' argument that is employed to search outside comments (the '\%0l'
    " pattern never matches).
    let cmd = "v`e"
    " !outer 表示参数本身，不包括分割符
    if !a:outer
      " 将光标从分割符或右括号向左移动，直到遇到非空字符
      " 此时光标要么在参数的最右边，要么在左括号上
      call search('\S', 'bW')
      " 使用标记 e 记录当前光标位置，同时跳转到标记 b
      " e 位置记录n跳后参数的右边界，或左括号
      " b 记录了左括号或当时发现的第一个分割符位置，
      exe "keepjumps normal! me`b"
      " 将光标向右移动直到遇到非空字符
      " 此时光标要么在右括号上，要么在当时发现的第一个参数的最左边,也就是参数的左边界
      call search('\S', 'W')
    elseif a:prefix " 处理prefix 场景
      " 在 outer 下，左右两边都是分割符的情况
      if a:sep =~ first && a:sep =~ last
        " Separators on both sides
        " 针对注释，边界需要调整，比如：
        " a, b /**/, c /* */, d
        "          ↑        ↑
        " 最右边的箭头位置会被调整到 c，因为这注释认为是 d 参数的
        " \S 正则表达式，表示非空字符
        " \%0l 是一个模式，表示光标当前行
        " 所以含义是在光标当前行查找非空白字符，如果是注释内容则跳过
        call searchpair('\S', '', '\%0l', 'bW', 's:IsCursorOnComment()')
        " e 位置记录最右边边界调整后的位置，并跳转到 b 位置
        " b 记录了左括号或当时发现的第一个分割符位置，
        exe "keepjumps normal! me`b"
        " 从左边界向左遍历，查找非空白符，如果是注释内容则跳过
        call searchpair('\S', '', '\%0l', 'bW', 's:IsCursorOnComment()')
        " 最终调整完位置：
        " a, b /**/, c /* */, d
        "    ↑       ↑
        " 最终命令为 v`eo o
        " 开启 visualmode，区域为当前光标到 e 位置，也就是 2 个箭头区域
        " o 在 visual 模式下可以将光标位置跳转到高亮文本的另一端，此时跳动前面
        " <Space> 在 visual 模式下相当于 l，向右移动光标
        " 最终调整完位置：
        " a, b /**/, c /* */, d
        "     ↑      ↑
        let cmd .= "o\<Space>o"
      elseif a:sep =~ first
        " 左边为分割符，右边为括号
        " Separator on the left, bracket on the right
        " 针对注释，边界需要调整，比如
        " a, b /**/, c , d/* */)
        "          ↑           ↑
        " 命令和上面的一模一样
        call searchpair('\S', '', '\%0l', 'bW', 's:IsCursorOnComment()')
        exe "keepjumps normal! me`b"
        call searchpair('\S', '', '\%0l', 'bW', 's:IsCursorOnComment()')
        " a, b /**/, c , d/* */)
        "     ↑          ↑       
        let cmd .= "o\<Space>o"
      elseif a:sep =~ last
        " 左边为括号，右边为分割符
        " (a, b , c /**/, d)
        " ↑             ↑
        " Bracket on the left, separator on the right
        " 右边界向右移动，直到遇到非空字符，也就是移动到右边参数或注释
        call search('\S', 'W')
        " e 位置记录最右边边界调整后的位置，并跳转到 b 位置
        " b 记录了左括号或当时发现的第一个分割符位置，
        exe "keepjumps normal! me`b"
        " 左边界向右移动，直到遇到非空字符，也就是移动到右边参数或注释
        call search('\S', 'W')
        " 移动后的位置：
        " (a, b , c /**/, d)
        "  ↑              ↑
        " visual 下，C-H 相当于 h 向左移动
        let cmd .= "\<C-H>"
        " 移动后的位置：
        " (a, b , c /**/, d)
        "  ↑             ↑
      else
        " 两边为括号
        " Brackets on both sides
        " (a, b , c , d)
        " ↑            ↑
        " e 位置记录最右边边界调整后的位置，并跳转到 b 位置
        " b 记录了左括号或当时发现的第一个分割符位置，
        exe "keepjumps normal! me`b"
        " (a, b , c , d)
        "  ↑          ↑
        let cmd .= "o\<Space>o\<C-H>"
      endif
    else  " !a:prefix 处理 suffix 的场景
      if a:sep =~ first && a:sep =~ last
        " 左右都指向了分割符
        " Separators on both sides
        " a, b /**/, c /* */, d
        "          ↑        ↑
        " 将右边界向右移动到下个参数，忽略注释
        call searchpair('\%0l', '', '\S', 'W', 's:IsCursorOnComment()')
        " 使用 e 标记右边界位置，同时跳转到左边界
        exe "keepjumps normal! me`b"
        " 将左边界移动到下个参数，忽略参数
        call searchpair('\%0l', '', '\S', 'W', 's:IsCursorOnComment()')
        " a, b /**/, c /* */, d
        "            ↑        ↑
        " 将右边界向左移动一个字符
        " a, b /**/, c /* */, d
        "            ↑       ↑
        let cmd .= "\<C-H>"
      elseif a:sep =~ first
        " Separator on the left, bracket on the right
        " 左边为分割符，右边为括号
        " Separator on the left, bracket on the right
        " 针对注释，边界需要调整，比如
        " a, b /**/, c , d/* */)
        "          ↑           ↑
        " 右边界向左移动，直到遇到非空字符，也就是移动到左边参数或注释
        call search('\S', 'bW')
        " a, b /**/, c , d/* */)
        "          ↑          ↑
        " e 位置记录最右边边界调整后的位置，并跳转到 b 位置
        " b 记录了左括号或当时发现的第一个分割符位置，
        exe "keepjumps normal! me`b"
        " 左边界向左移动，直到遇到非空字符，也就是移动到左边参数或注释
        call search('\S', 'bW')
        " a, b /**/, c , d/* */)
        "         ↑           ↑
        let cmd .= "o\<Space>o"
        " a, b /**/, c , d/* */)
        "          ↑          ↑
      elseif a:sep =~ last
        " Bracket on the left, separator on the right
        " 左边为括号，右边为分隔符
        " 针对注释，边界需要调整，比如
        " (a, b /**/, c , d/* */)
        " ↑             ↑
        " 命令和上面的一模一样
        call searchpair('\%0l', '', '\S', 'W', 's:IsCursorOnComment()')
        exe "keepjumps normal! me`b"
        call searchpair('\%0l', '', '\S', 'W', 's:IsCursorOnComment()')
        let cmd .= "\<C-H>"
        " (a, b /**/, c , d/* */)
        "  ↑             ↑
      else
        " Brackets on both sides
        " 两边为括号
        " (a, b , c , d)
        " ↑            ↑
        exe "keepjumps normal! me`b"
        let cmd .= "o\<Space>o\<C-H>"
        " (a, b , c , d)
        "  ↑          ↑
      endif
    endif

    " selection options 的值为 exclusive/inclusive
    " exclusive 模式意味着选择区的最后一个字符不包括在操作范围内，非闭区间
    " 所以用 <Space> 将右边界向右移动一个字符
    " 请注意，如果光标位于行尾，则 <space> 可以转到下一行，而 'l' 则不能
    if &sel == "exclusive"
      " The last character is not included in the selection when 'sel' is
      " exclusive so extend selection by one character on the right to
      " compensate.  Note that <Space> can go to next line if the cursor is on
      " the end of line, whereas 'l' can't.
      let cmd .= "\<Space>"
    endif

    " 执行命令
    exe "keepjumps normal! " . cmd
  finally
    call setpos("'b", save_mb)
    call setpos("'e", save_me)
    let @" = save_unnamed
    let &ic = save_ic
  endtry
endfunction

" 判断当前光标下的文字是不是注释
function! s:IsCursorOnComment()
   " synID 返回位置文本的语法 ID，再用 syncIDattr 根据语法 ID 获取语法信息
   " 最后根据 name 是否包含 comment 关键词判断是否为注释
   " 这种方式有点取巧，这个取决于是否有语法信息以及定义的语法信息名字是否为
   " comment
   return synIDattr(synID(line("."), col("."), 0), "name") =~? "comment"
endfunction

function! s:IsCursorOnStringOrComment()
   let syn = synIDattr(synID(line("."), col("."), 0), "name")
   return syn =~? "string" || syn =~? "comment"
endfunction
