#!/bin/sh

# 前回の合計試算表と新たな仕訳表から次の合計残高試算表を作るやつ
# 標準入力からそれらをくっつけたファイルをくれ

set -eu;umask 0022;export LC_ALL=C
if posixpath="$(command -p getconf PATH 2>/dev/null)"; then
	export PATH="$posixpath${PATH+:}${PATH:-}"
fi
export POSIXLY_CORRECT=1 UNIX_STD=2003

# データくれ
cat |
#
# 和字間隔を0x20にしとけ
sed 's/　/ /g' |
#
# 過去の合計試算表を仕訳表っぽいフォーマットに変換
awk '
	BEGIN {
		mode = "body";
	}
	$1=="__HEAD__" {
		mode = "head";
	}
	$1=="__BODY__" {
		mode = "body";
	}
	# 合計試算表のデータ
	mode == "head" && NF == 3 {
		borrow = $1;
		item = $2;
		lent = $3;

		print "<", item, borrow;
		print ">", item, lent;
		next;
	}
	# 仕訳表のデータはそのまま通過
	# ただし文法通りのもののみ
	mode == "body" && NF == 3 && ($1 == "<" || $1 == ">");
' |
#
# 3列なう
# 借り貸しどちらかを表す記号、借方科目または貸方科目、金額
# [<>]、借方科目または貸方科目、コンマあるっぽい金額
# "@"とそれ以降にある取引の相手はひとまずなくそうか
awk '
	{sub("@.*", "", $2);}
 	1
' |
#
# 3列なう
# 金額からコンマなくしておく
awk '
	{gsub(",", "", $1); gsub(",", "", $3);}
 	1
' |
#
# 3列なう
# そういえば金額が"*"となってる場合もあるよね、0にしとこうか
awk '
	$1 == "*" { $1 = 0; }
 	$3 == "*" { $3 = 0; }
  	1
' |
#
# 3列なう
# 借り貸しどちらかを表す記号、借方科目または貸方科目、金額
# 当初の合計試算表の順番を保つため、ひとまず同じ科目で番号を付ける
awk '
	BEGIN {
		id = 0;
		split("", item2id, "");
	}
	{
		item = $2;
		if (item in item2id) {
			# nothing
		} else {
			item2id[item] = ++id;
		}
		print item2id[item], $0;
	}
' |
#
# 4列なう
# 科目番号、貸し借りどっち、科目名、金額
# sm2(1)に通すためsortしとく
# ていうかASCIIコードの順番からして"<"が先で">"が後かと
sort -nk1 -k2 |
#
# 4列なう
# 科目番号、貸し借りどっち、科目名、金額
sm2 1 3 4 4 |
#
# 4列なう
# もう科目番号落そう
# 最初の行を1行目として奇数行目は借方、偶数行目は貸方だろ、既に
self 3 4 |
#
# 2列なう
# 2行ごとに結合しちゃえ
paste - - |
#
# 4列なう
# 科目、借方合計、科目、貸方合計
# ていうか2と4列目同じ筈なんだけど
# 違うなら警告する
awk '$2 != $4 {
	print "$2: " $2 "; $4: " $4 " on line " NR | cat "1>&2";
}
1' |
self 1 2 4 |
#
# 3列なう
# 科目、借方合計、貸方合計
# 借方残高と貸方残高も付け足す
awk '{
	$0 = $0 FS "*" FS "*";
	if ( $2 > $3 ) $4 = $2 - $3;
	if ( $2 < $3 ) $5 = $3 - $2;

	# 借方合計や貸方合計でゼロを消す
	if ( $2 == 0 ) $2 = "*";
	if ( $3 == 0 ) $3 = "*";

	print;
}' |
#
# 5列なう
# 科目、借方合計、貸方合計、借方残高、貸方残高
# 各合計と残高の合計を得る
sm5 1 1 2 5 |
#
# 順番を合計残高試算表の通りにする
self 4 2 1 3 5 |
#
# 5列なう
# 借方残高、借方合計、勘定科目、貸方合計、貸方合計
# 最後に整形して完成
comma 1 2 4 5 |
keta
