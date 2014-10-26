"######################################################################
"# VimOutliner Tables Enhancements
"# Copyright (C) 2014 by Noel Henson noelwhenson@gmail.com
"# The file is currently an experimental part of Vim Outliner.
"#
"# This program is free software; you can redistribute it and/or modify
"# it under the terms of the GNU General Public License as published by
"# the Free Software Foundation; either version 2 of the License, or
"# (at your option) any later version.
"#
"# This program is distributed in the hope that it will be useful,
"# but WITHOUT ANY WARRANTY; without even the implied warranty of
"# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"# GNU General Public License for more details.
"######################################################################

"NOTES:
" 1. This plugin is in TEST SCRIPT mode and has not been integrated into
" VO yet. It will become a VO plugin once testing is done. This script should
" be sourced ':so tables.vim' until the integration has been completed.
" 2. There are no keyboard mappings needed to use this plugin. Reformatting
" takes place upon escape from Insert mode and when the cursor hold event 
" is triggered.
" 3. These formatting methods are currently incompatible with the "||" VO 
" header marker. They are converted to a single "|". This does not affect 
" VO itself but may affect post-procesors like otl2html.py.

"GetBlockStartEnd(lnum,delim) {{{1
"return a list of the start and end lines of a block, -1,-1 if not a block
"a block is a group of lines at the same indent starting with the same
"non-whitespace character.
"this is a generic routine that may want to be added to votl.vim.
function! GetBlockStartEnd(lnum,delim)
	let ts = a:lnum
	let mstring = "\s*".a:delim
	if match(getline(ts),mstring) == -1
		return [-1,-1]
	endif
	let ind = Ind(ts)
	let te = ts
	" search up
	while ind == Ind(ts)
		let ts -= 1
		if match(getline(ts),mstring) == -1
			break
		endif
	endwhile
	let ts += 1
	while ind == Ind(te)
		let te += 1
		if match(getline(te),mstring) == -1
			break
		endif
	endwhile
	let te -= 1
	return [ts,te]
endfunction

"GetTableStartEnd(lnum) {{{1
"return the start and end line number of the table that contains lnum
"return -1,-1 if not a table
function! GetTableStartEnd(lnum)
	return GetBlockStartEnd(a:lnum,"\|")
endfunction

"Lstrip(string) {{{1
"return a string with the left-side (leading) whitespace removed
function! Lstrip(string)
	return substitute(a:string,"\^\\s*","","")
endfunction

"Rstrip(string) {{{1
"return a string with the right-side (trailing) whitespace removed
function! Rstrip(string)
	return substitute(a:string,"\\s*\$","","")
endfunction

"Strip(string) {{{1
"return a string with the leading and trailing whitespace removed
function! Strip(string)
	return Lstrip(Rstrip(a:string))
endfunction

"GetColWidths(lnum) {{{1
"return a list of the widths of each column from line number lnum
"header markers '||' are converted to normal markers first
function! GetColWidths(lnum)
	let widths = []
	"strip leading whitespace and replace header delimiters
	let line = substitute(Lstrip(getline(a:lnum)),"||","|","")
	let cols = split(line,"|")
	"collect the widths of the data in the columns
	for col in cols
		let widths += [len(Strip(col))]
	endfor
	return widths
endfunction

"ListAppendZeros(list,len) {{{1
"return the list with the specified number of items
"zeros apended for new items
"will not truncate the list if it is longer than len
function! ListAppendZeros(list,len)
	let list = a:list
	let i = a:len-len(list)
	while i>0
		let list += [0]
		let i -= 1
	endwhile
	return list
endfunction

"ColMax(lista,listb) {{{1
"return a list that contains the maximum values from the lists
"substitute 0 for nonexistent list entries
"i.e. if lista[i] > listb[i] return val[i] = lista[i]
"e.g. lista=[1,3,4], listb[2,2,3] return [2,3,4]
"e.g. lista=[1,3], listb[2,2,3] return [2,3,4]
function! ColMax(lista,listb)
	let maxwidths = []
	let lista = a:lista
	let listb = a:listb
	let lena = len(lista)
	let lenb = len(listb)
	let maxcols = max([lena,lenb])
	if lena > lenb
		let listb = ListAppendZeros(listb,lena)
	elseif lena < lenb
		let lista = ListAppendZeros(lista,lenb)
	endif
	let col = 0
	while col < maxcols
		let maxwidths +=[max([a:lista[col],a:listb[col]])]
		let col += 1
	endwhile
	return maxwidths
endfunction

"GetMaxColWidths(lnumstart,lnumend) {{{1
"return a list of the maximum width of each column in a range of lines
function! GetMaxColWidths(lnumstart,lnumend)
	let lnum = a:lnumstart + 1
	let widths = GetColWidths(a:lnumstart)
	while lnum <= a:lnumend
		let newwidths = GetColWidths(lnum)
		let widths = ColMax(widths,newwidths)
		let lnum += 1
	endwhile
	return widths
endfunction

"these two functions are computationally intensive {{{1
"
"function! Spaces(n)
"	let spaces = ""
"	let n = a:n
"	if a:n > 0
"		while n > 0
"			let spaces = spaces." "
"			let n -= 1
"		endwhile
"	endif
"	return spaces
"endfunction
"
"function! Justify(string,len,just)
"	let slen = len(a:string)
"	let splen = a:len - slen
"	let halfspaces = Spaces(splen/2)
"	if and(splen,1)
"		let extraspace = " "
"	else
"		let extraspace = ""
"	endif
"	if splen
"		if a:just == 0 " right
"			return halfspaces.halfspaces.extraspace.a:string
"		elseif a:just == 1 " left
"			return a:string.halfspaces.halfspaces.extraspace
"		elseif a:just == 2 " center, but lean left on odd number of spaces
"			return halfspaces.a:string.halfspaces.extraspace
"		else
"			return a:string
"		endif
"	else
"		return a:string
"	endif
"endfunction
"
"better solution for spaces and justification, faster and less math {{{1
"80 spaces used for justification - influences maximum column width 
"11 tabs used for indentation - influences maximum table indentation 
"probably large enough for now
let s:spaces = "                                                                                "
let s:tabs = "											"
"pseudo-constant codes to represent justification
let s:right = 0
let s:left = 1
let s:center = 2

"IsHeader(string) {{{1
"return non-zero if a header line, starts with ||
function! IsHeader(string)
	return 1+match(a:string,"||")
endfunction

"Justify(string,len,just) {{{1
"return a string justified within a field of the specifiec length
"unknown justification types return just the string
"if string is larger than len, return just the string
function! Justify(string,len,just)
	let slen = len(a:string)
	let splen = a:len - slen
	if splen > 0
		if a:just == s:right
			return s:spaces[1:splen].a:string
		elseif a:just == s:left
			return a:string.s:spaces[1:splen]
		elseif a:just == s:center "but lean left on odd number of spaces
			return s:spaces[1:splen/2].a:string.s:spaces[1:(splen+1)/2]
		else
			return a:string
		endif
	else
		return a:string
	endif
endfunction

"IsNumber(string) {{{1
"return true if the string is a number
"it may be surrounded by whitespace
"formats supported: integers, floats, scientific notation
function! IsNumber(string)
	let isnum = match(a:string,'^\s*[-+]\?[0-9]\+\(.[0-9]\+\)\?\([eE][-+]\?[0-9]\+\)\?\s*$')
	return isnum != -1
endfunction

" Justification(string) {{{1
" determine the justification of the string
" return one of the flag variables to indicate type: s:left, s:right or s:center
" currently justification is determined by data in the string and its whitespace
" 	left:     | words  |      more spaces on the right
" 	right:    |   1234 |      numbers, including floating point and scientific notation
" 	right:    |  words |      more spaces on the left
" 	center:   |  words  |     same spaces (perhaps one more on the right)
" 	left:     | 1234    |     numbers can be left-justified as well
" TODO: add other methods, flags and or dashline
function! Justification(string)
	let lpad = match(a:string,"\\S")
	let rpad = len(a:string) - match(a:string,"\\s*$")
	if lpad <= 1 && rpad > 1
		return s:left
	endif
	if lpad > 1 && rpad <= 1
		return s:right
	endif
	if IsNumber(a:string)
		return s:right
	endif
	return s:center
endfunction

"JustifyColumns(string,widths) {{{1
"return an array of justified columns
function! JustifyColumns(string,widths)
	let cols = split(substitute(Lstrip(a:string),"||","|",""),"|")
	let justifications = []
	for col in cols
		let justifications += [Justification(col)]
	endfor
	let newcols = []
	let i = 0
	let colcnt = len(cols)
	while i < colcnt
		let newcols += [Justify(Strip(cols[i]),a:widths[i],justifications[i])]
		let i += 1
	endwhile
	return newcols
endfunction

"FormatTable(lnum) {{{1
"format the table containing line number lnum
function! FormatTable(lnum)
	"find the table extents
	let [ts,te] = GetTableStartEnd(a:lnum)
	if ts == -1
		return
	endif
	let ti = Ind(ts)
	let indent = s:tabs[1:ti]."|"
	"measure their widths
	let widths = GetMaxColWidths(ts,te)
	"justify the columns for each row and replace them
	while ts <= te
		"justify the column data
		let cols = JustifyColumns(getline(ts),widths)
		"create the replacement row
		let row = indent
		for col in cols
			"let row = row.col."|"
			let row = row." ".col." |"
		endfor
		call setline(ts,row)
		let ts += 1
	endwhile
endfunction

"auto commands for automatic reformatting {{{1
autocmd InsertLeave *.otl call FormatTable(line("."))
autocmd CursorHold *.otl call FormatTable(line("."))
set updatetime=1000
