use strict;

BEGIN { require 'wakautils.pl'; }



#
# Interface strings
#

use constant S_NAVIGATION => 'ナビ';
use constant S_RETURN => '掲示板に戻る';
use constant S_ENTIRE => 'レスを全部読む';
use constant S_LAST50 => '最新レス５０';
use constant S_FIRST100 => 'レス１－１００';
use constant S_BOARDLOOK => 'デザイン';
use constant S_ADMIN => '管理人';
use constant S_MANAGE => '管理用';
use constant S_REBUILD => 'キャッシュの再構築';
use constant S_ALLTHREADS => '過去ログはこちら';
use constant S_NAME => '名前：';
use constant S_EMAIL => 'E-mail:';
use constant S_FORCEDANON => '(強制的に名無しになります)';
use constant S_CAPTCHA => '検証:';
use constant S_TITLE => 'タイトル：';
use constant S_NEWTHREAD => '新規スレッド作成';
use constant S_IMAGE => '添付File:';
use constant S_IMAGEDIM => '添付File:';
use constant S_NOTHUMBNAIL => 'No<br />thumbnail';
use constant S_REPLY => '書き込む';
use constant S_LISTEXPL => 'スレッドリストへ';
use constant S_PREVEXPL => '前のスレッド';
use constant S_NEXTEXPL => '次のスレッド';
use constant S_LISTBUTTON => '&#9632;';
use constant S_PREVBUTTON => '&#9650;';
use constant S_NEXTBUTTON => '&#9660;';
use constant S_TRUNC => '省略されました・・全てを読むには<a href="%s">ここ</a>を押してください';
use constant S_PERMASAGED => '、永久sage';
use constant S_POSTERNAME => '名前：';
use constant S_CAPPED => ' (Admin)';
use constant S_DELETE => '削除';
use constant S_USERDELETE => '投稿者が削除しました。';
use constant S_MODDELETE => 'あぼーん';
use constant S_PERMASAGETHREAD => '永久sage';
use constant S_DELETETHREAD => '削除';

use constant S_FRONT => '掲示板に戻る';

#
# Error strings
#

use constant S_BADCAPTCHA => '不正な検証コードが入力されました';
use constant S_UNJUST => '不正な投稿をしないで下さい';
use constant S_NOTEXT => '何か書いて下さい';
use constant S_NOTITLE => 'タイトルを書いてください';
use constant S_NOTALLOWED => '管理人以外は投稿できません';
use constant S_TOOLONG => '本文が長すぎますっ！';
use constant S_TOOMANYLINES => '改行が大すぎですっ！';
use constant S_UNUSUAL => '何か変です';
use constant S_SPAM => 'スパムを投稿しないで下さい';
use constant S_THREADCOLL => '誰かが同時に投稿しようとしました。もう一度投稿してください';
use constant S_NOTHREADERR => 'スレッドがありません';
use constant S_BADDELPASS => '該当記事が見つからないかパスワードが間違っています';
use constant S_NOTWRITE => 'ディレクトリに書き込み権限がありません';
use constant S_NOTASK => 'スクリプトエラー：処理がありません';
use constant S_NOLOG => 'log.txtに書き込めません';
use constant S_TOOBIG => 'アップロードに失敗しました<br />サイズが大きすぎます<br />'.MAX_KB.'Kバイトまで';
use constant S_EMPTY => 'The file you tried to upload is empty.';
use constant S_BADFORMAT => 'File format not allowed.';			# Returns error when the file is not in a supported format.
use constant S_DUPE => 'アップロードに失敗しました<br />同じ画像があります (<a href="%s">link</a>)';
use constant S_DUPENAME => 'Error: A file with the same name already exists.';

#use constant S_NOADMIN => 'ADMIN_PASS は空にできません';
#use constant S_NOSECRET => 'SECRET は空にできません';

#
# Templates
#

use constant GLOBAL_HEAD_INCLUDE => q{

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
<title><if $title><var $title> - </if><const TITLE></title>
<meta http-equiv="Content-Type" content="text/html;charset=<const CHARSET>" />
<link rel="shortcut icon" href="<const expand_filename(FAVICON)>" />

<if RSS_FILE>
<link rel="alternate" title="RSS feed" href="<const expand_filename(RSS_FILE)>" type="application/rss+xml" />
</if>

<loop $stylesheets>
<link rel="<if !$default>alternate </if>stylesheet" type="text/css" href="<var expand_filename($filename)>" title="<var $title>" />
</loop>

<script type="text/javascript">var style_cookie="<const STYLE_COOKIE>";</script>
<script type="text/javascript" src="<const expand_filename(JS_FILE)>"></script>
</head>
};



use constant GLOBAL_FOOT_INCLUDE => include("include/footer.html").q{
</body></html>
};




use constant MAIN_PAGE_TEMPLATE => compile_template( GLOBAL_HEAD_INCLUDE.q{
<body class="mainpage">

}.include("include/header.html").q{

<div id="topbar">

<div id="stylebar">
<strong><const S_BOARDLOOK></strong>
<loop $stylesheets>
	<a href="javascript:set_stylesheet('<var $title>')"><var $title></a>
</loop>
</div>

<div id="managerbar">
<strong><const S_ADMIN></strong>
<a href="javascript:set_manager()"><const S_MANAGE></a>
<span class="manage" style="display:none;">
<a href="<var $self>?task=rebuild"><const S_REBUILD></a>
</span>
</div>

</div>

<div id="threads">

<h1>
<if SHOWTITLEIMG==1><img src="<var expand_filename(TITLEIMG)>" alt="<const TITLE>" /></if>
<if SHOWTITLEIMG==2><img src="<var expand_filename(TITLEIMG)>" onclick="this.src=this.src;" alt="<const TITLE>" /></if>
<if SHOWTITLEIMG and SHOWTITLETXT><br /></if>
<if SHOWTITLETXT><const TITLE></if>
</h1>

<a name="menu"></a>
<div id="threadlist">
<loop $allthreads><if $num<=THREADS_LISTED>
	<span class="threadlink">
	<a href="<var $self>/<var $thread>"><var $num>. 
	<if $num<=THREADS_DISPLAYED></a><a href="#<var $num>"></if>
	<var $title> (<var $postcount>)</a>
	</span>
</if></loop>

<strong><a href="<const expand_filename(HTML_BACKLOG)>"><const S_ALLTHREADS></a></strong>

</div>

<form id="threadform" action="<var $self>" method="post" enctype="multipart/form-data">
<input type="hidden" name="task" value="post" />
<input type="hidden" name="password" value="" />
<table><col /><col /><col width="100%" /><tbody><tr valign="top">
	<td style="white-space:nowrap"><nobr><const S_NAME></nobr></td>
	<td style="white-space:nowrap"><nobr>
		<if !FORCED_ANON><input type="text" name="name" size="19" /></if>
		<if FORCED_ANON><input type="text" size="19" disabled="disabled" /><input type="hidden" name="name" /></if>
		<const S_LINK> <input type="text" name="link" size="19" /></nobr>
	</td>
	<td>
		<if FORCED_ANON><small><const S_FORCEDANON></small></if>
	</td>
<if ENABLE_CAPTCHA>
</tr><tr>
	<td style="white-space:nowrap"><nobr><const S_CAPTCHA></nobr></td>
	<td><input type="text" name="captcha" size="19" />
	<img class="threadcaptcha" src="<const expand_filename('captcha.pl')>?selector=.threadcaptcha" />
	</td><td></td>
</if>
</tr><tr>
	<td style="white-space:nowrap"><nobr><const S_TITLE></nobr></td>
	<td><input type="text" name="title" style="width:100%" /></td>
	<td><input type="submit" value="<const S_NEWTHREAD>" /></td>
</tr><tr>
	<td></td>
	<td colspan="2">
	<textarea name="comment" cols="64" rows="5" onfocus="size_field('threadform',15)" onblur="size_field('threadform',5)"></textarea>
	</td>
<if ALLOW_IMAGE_THREADS>
</tr><tr>
	<td style="white-space:nowrap"><nobr><const S_IMAGE></nobr></td>
	<td colspan="2"><input name="file" size="49" type="file" /></td>
</if>
</tr></tbody></table>
</form>
<script type="text/javascript">set_inputs("threadform");</script>

</div>

}.include("include/mid.html").q{

<div id="posts">

<loop $threads><if $posts>
	<a name="<var $num>"></a>
	<if $permasage><div class="sagethread"></if>
	<if !$permasage><div class="thread"></if>
	<h2><var $title> <small>(<var $postcount><if $permasage>, permasaged</if>)</small></h2>

	<div class="threadnavigation">
	<a href="#menu" title="<const S_LISTEXPL>"><const S_LISTBUTTON></a>
	<a href="#<var $prev>" title="<const S_PREVEXPL>"><const S_PREVBUTTON></a>
	<a href="#<var $next>" title="<const S_NEXTEXPL>"><const S_NEXTBUTTON></a>
	</div>

	<div class="replies">

	<if $omit><div class="firstreply"></if>
	<if !$omit><div class="allreplies"></if>

	<loop $posts>
		<var $reply>

		<if $abbrev>
		<div class="replyabbrev">
		<var sprintf(S_TRUNC,"$self/$thread/$postnum","$self/$thread/")>
		</div>
		</if>

		<if $omit and $first>
		</div><div class="repliesomitted"></div><div class="finalreplies">
		</if>
	</loop>

	</div>
	</div>

	<form id="postform<var $thread>" action="<var $self>" method="post" enctype="multipart/form-data">
	<input type="hidden" name="task" value="post" />
	<input type="hidden" name="thread" value="<var $thread>" />
	<input type="hidden" name="password" value="" />
	<table><tbody><tr valign="top">
		<td style="white-space:nowrap"><nobr><const S_NAME></nobr></td>
		<td>
			<if !FORCED_ANON><input type="text" name="name" size="19" /></if>
			<if FORCED_ANON><input type="text" size="19" disabled="disabled" /><input type="hidden" name="name" /></if>
			<const S_LINK> <input type="text" name="link" size="19" />
			<input type="submit" value="<const S_REPLY>" />
			<if FORCED_ANON><small><const S_FORCEDANON></small></if>
		</td>
	<if ENABLE_CAPTCHA>
	</tr><tr>
		<td style="white-space:nowrap"><nobr><const S_CAPTCHA></nobr></td>
		<td><input type="text" name="captcha" size="19" />
		<img class="postcaptcha" src="<const expand_filename('captcha.pl')>?selector=.postcaptcha" />
		</td>
	</if>
	</tr><tr>
		<td></td>
		<td><textarea name="comment" cols="64" rows="5" onfocus="size_field('postform<var $thread>',15)" onblur="size_field('postform<var $thread>',5)"></textarea></td>
	<if ALLOW_IMAGE_REPLIES>
	</tr><tr>
		<td style="white-space:nowrap"><nobr><const S_IMAGE></nobr></td>
		<td colspan="2"><input name="file" size="49" type="file" /></td>
	</if>
	</tr><tr>
		<td></td>
		<td><div class="threadlinks">
		<a href="<var $self>/<var $thread>/"><const S_ENTIRE></a>
		<a href="<var $self>/<var $thread>/l50"><const S_LAST50></a>
		<a href="<var $self>/<var $thread>/-100"><const S_FIRST100></a>
		</div></td>
	</tr></tbody></table>
	</form>
	<script type="text/javascript">set_inputs("postform<var $thread>");</script>

	</div>
</if></loop>

</div>

}.GLOBAL_FOOT_INCLUDE);



use constant THREAD_HEAD_TEMPLATE => compile_template( GLOBAL_HEAD_INCLUDE.q{
<body class="threadpage">

}.include("include/header.html").q{

<div id="topbar">

<div id="navbar">
<strong><const S_NAVIGATION></strong>
<a href="<const expand_filename(HTML_SELF)>"><const S_RETURN></a>
<a href="<var $self>/<var $thread>"><const S_ENTIRE></a>
<a href="<var $self>/<var $thread>/l50"><const S_LAST50></a>
<a href="<var $self>/<var $thread>/-100"><const S_FIRST100></a>
<!-- hundred links go here -->
</div>

<div id="stylebar">
<strong><const S_BOARDLOOK></strong>
<loop $stylesheets>
	<a href="javascript:set_stylesheet('<var $title>')"><var $title></a>
</loop>
</div>

<div id="managerbar">
<strong><const S_ADMIN></strong>
<a href="javascript:set_manager()"><const S_MANAGE></a>
<span class="manage" style="display:none;">
<a href="<var $self>?task=permasagethread&amp;thread=<var $thread>"><const S_PERMASAGETHREAD></a>
<a href="<var $self>?task=deletethread&amp;thread=<var $thread>"><const S_DELETETHREAD></a>
</span>
</div>

</div>

<div id="posts">

<if $permasage><div class="sagethread"></if>
<if !$permasage><div class="thread"></if>
<h2><var $title> <small>(<var $postcount><if $permasage><const S_PERMASAGED></if>)</small></h2>

<div class="replies">
<div class="allreplies">
});



use constant THREAD_FOOT_TEMPLATE => compile_template( q{

</div>
</div>

<form id="postform<var $thread>" action="<var $self>" method="post"  enctype="multipart/form-data">
<input type="hidden" name="task" value="post" />
<input type="hidden" name="thread" value="<var $thread>" />
<input type="hidden" name="password" value="" />
<table><tbody><tr>
	<td style="white-space:nowrap"><nobr><const S_NAME></nobr></td>
	<td>
		<if !FORCED_ANON><input type="text" name="name" size="19" /></if>
		<if FORCED_ANON><input type="text" size="19" disabled="disabled" /><input type="hidden" name="name" /></if>
		<const S_LINK> <input type="text" name="link" size="19" />
		<input type="submit" value="<const S_REPLY>" />
		<if FORCED_ANON><small><const S_FORCEDANON></small></if>
	</td>
<if ENABLE_CAPTCHA>
</tr><tr>
	<td style="white-space:nowrap"><nobr><const S_CAPTCHA></nobr></td>
	<td><input type="text" name="captcha" size="19" />
		<img class="postcaptcha" src="<const expand_filename('captcha.pl')>?selector=.postcaptcha" />
	</td>
</if>
</tr><tr>
	<td></td>
	<td><textarea name="comment" cols="64" rows="5" onfocus="size_field('postform<var $thread>',15)" onblur="size_field('postform<var $thread>',5)"></textarea><br /></td>
<if ALLOW_IMAGE_REPLIES>
</tr><tr>
	<td style="white-space:nowrap"><nobr><const S_IMAGE></nobr></td>
	<td colspan="2"><input name="file" size="49" type="file" /></td>
</if>
</tr></tbody></table>
</form>
<script type="text/javascript">set_inputs("postform<var $thread>");</script>

</div>
</div>

}.GLOBAL_FOOT_INCLUDE);



use constant REPLY_TEMPLATE => compile_template( q{

<div class="reply">

<h3>
<span class="replynum"><a title="Quote post number in reply" href="javascript:insert('&gt;&gt;<var $num>',<var $thread>)"><var $num></a></span>
<const S_POSTERNAME>
<if $capped><em></if>
<if $link><span class="postername"><a href="<var $link>"><var $name></a></span><span class="postertrip"><a href="<var $link>"><var $trip><if $capped><const S_CAPPED></if></a></span></if>
<if !$link><span class="postername"><var $name></span><span class="postertrip"><var $trip><if $capped><const S_CAPPED></if></span></if>
<if $capped></em></if>
<var $date>
<if $image><span class="filesize">(<const S_IMAGEDIM><em><var $width>x<var $height> <var $ext>, <var int($size/1024)> kb</em>)</span></if>
<span class="deletebutton">
<if ENABLE_DELETION>[<a href="javascript:delete_post(<var $thread>,<var $num><if $image>,true</if>)"><const S_DELETE></a>]</if>
<if !ENABLE_DELETION><span class="manage" style="display:none;">[<a href="javascript:delete_post(<var $thread>,<var $num><if $image>,true</if>)"><const S_DELETE></a>]</span></if>
</span>
</h3>

<if $image>
	<if $thumbnail>
		<a href="<var expand_filename($image)>">
		<img src="<var expand_filename($thumbnail)>" width="<var $tn_width>" height="<var $tn_height>" 
		alt="<var $image>: <var $width>x<var $height>, <var int($size/1024)> kb"
		title="<var $image>: <var $width>x<var $height>, <var int($size/1024)> kb"
		/></a>
	</if><if !$thumbnail>
		<div class="nothumbnail">
		<a href="<var expand_filename($image)>"><const S_NOTHUMBNAIL></a>
		</div>
	</if>
</if>

<div class="replytext"><var $comment></div>

</div>
});



use constant DELETED_TEMPLATE => compile_template( q{
<div class="deletedreply">
<h3>
<span class="replynum"><var $num></span>
<if $reason eq 'user'><const S_USERDELETE></if>
<if $reason eq 'mod'><const S_MODDELETE></if>
</h3>
</div>
});



use constant BACKLOG_PAGE_TEMPLATE => compile_template( GLOBAL_HEAD_INCLUDE.q{
<body class="backlogpage">

}.include("include/header.html").q{

<div id="topbar">

<div id="navbar">
<strong><const S_NAVIGATION></strong>
<a href="<const expand_filename(HTML_SELF)>"><const S_RETURN></a>
</div>

<div id="stylebar">
<strong><const S_BOARDLOOK></strong>
<loop $stylesheets>
	<a href="javascript:set_stylesheet('<var $title>')"><var $title></a>
</loop>
</div>

<div id="managerbar">
<strong><const S_ADMIN></strong>
<a href="javascript:set_manager()"><const S_MANAGE></a>
<span class="manage" style="display:none;">
<a href="<var $self>?task=rebuild"><const S_REBUILD></a>
</span>
</div>

</div>

<div id="threads">

<h1><const TITLE></h1>

<div id="oldthreadlist">
<loop $threads>
	<span class="threadlink">
	<a href="<var $self>/<var $thread>"><var $num>. <var $title> (<var $postcount>)</a>
	<span class="manage" style="display:none;">
	( <a href="<var $self>?task=permasagethread&amp;thread=<var $thread>"><const S_PERMASAGETHREAD></a>
	| <a href="<var $self>?task=deletethread&amp;thread=<var $thread>"><const S_DELETETHREAD></a>
	)</span>
	</span>
</loop>
</div>

</div>

}.GLOBAL_FOOT_INCLUDE);



use constant RSS_TEMPLATE => compile_template( q{
<?xml version="1.0" encoding="<const CHARSET>"?>
<rss version="2.0">

<channel>
<title><const TITLE></title>
<link><var $absolute_path><const HTML_SELF></link>
<description>Posts on <const TITLE> at <var $ENV{SERVER_NAME}>.</description>

<loop $threads><if $posts>
	<item>
	<title><var $title> (<var $postcount>)</title>
	<link><var $absolute_self>/<var $thread>/</link>
	<guid><var $absolute_self>/<var $thread>/</guid>
	<comments><var $absolute_self>/<var $thread>/</comments>
	<author><var $author></author>
	<description><![CDATA[
		<var $$posts[0]{reply}=~m!<div class="replytext".(.*?)</div!; $1 >
		<if $abbrev><p><small>Post too long, full version <a href="<var $absolute_self>/<var $thread>/">here</a>.</small></p>
		</if>
	]]></description>
	</item>
</if></loop>

</channel>
</rss>
});



use constant ERROR_TEMPLATE => compile_template( GLOBAL_HEAD_INCLUDE.q{
<body class="errorpage">

}.include("include/header.html").q{

<div id="topbar">

<div id="navbar">
<strong><const S_NAVIGATION></strong>
<a href="<var escamp($ENV{HTTP_REFERER})>"><const S_RETURN></a>
</div>

<div id="stylebar">
<strong><const S_BOARDLOOK></strong>
<loop $stylesheets>
	<a href="javascript:set_stylesheet('<var $title>')"><var $title></a>
</loop>
</div>

</div>

<h1><var $error></h1>

<h2><a href="<var escamp($ENV{HTTP_REFERER})>"><const S_RETURN></a></h2>

}.GLOBAL_FOOT_INCLUDE);


1;
