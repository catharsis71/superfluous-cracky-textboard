use strict;

BEGIN { require 'wakautils.pl' }



#
# Interface strings
#

use constant S_NAVIGATION => 'Navigation';
use constant S_RETURN => 'Return';
use constant S_ENTIRE => 'Entire thread';
use constant S_LAST50 => 'Last 50 replies';
use constant S_FIRST100 => 'First 100 replies';
use constant S_BOARDLOOK => 'Board look';
use constant S_ADMIN => 'Admin';
use constant S_MANAGE => 'Manage';
use constant S_REBUILD => 'Rebuild caches';
use constant S_ALLTHREADS => 'All threads';
use constant S_NAME => 'Name:';
use constant S_LINK => 'Link:';
use constant S_FORCEDANON => '(Anonymous posting is being enforced)';
use constant S_CAPTCHA => 'Verification:';
use constant S_TITLE => 'Title:';
use constant S_NEWTHREAD => 'Create new thread';
use constant S_IMAGE => 'Image:';
use constant S_IMAGEDIM => 'Image: ';
use constant S_NOTHUMBNAIL => 'No<br />thumbnail';
use constant S_REPLY => 'Reply';
use constant S_LISTEXPL => 'Jump to thread list';
use constant S_PREVEXPL => 'Jump to previous thread';
use constant S_NEXTEXPL => 'Jump to next thread';
use constant S_LISTBUTTON => '&#9632;';
use constant S_PREVBUTTON => '&#9650;';
use constant S_NEXTBUTTON => '&#9660;';
use constant S_TRUNC => 'Post too long. Click to view the <a href="%s">whole post</a> or the <a href="%s">entire thread</a>.';
use constant S_PERMASAGED => ', permasaged';
use constant S_POSTERNAME => 'Name:';
use constant S_CAPPED => ' (Admin)';
use constant S_DELETE => 'Del';
use constant S_USERDELETE => 'Post deleted by user.';
use constant S_MODDELETE => 'Post deleted by moderator.';
use constant S_PERMASAGETHREAD => 'Permasage';
use constant S_DELETETHREAD => 'Delete';

use constant S_FRONT => 'Front page';								# Title of the front page in page list

#
# Error strings
#

use constant S_BADCAPTCHA => 'Wrong verification code entered.';			# Error message when the captcha is wrong
use constant S_UNJUST => 'Unjust POST.';									# Error message on an unjust POST - prevents floodbots or ways not using POST method?
use constant S_NOTEXT => 'No text entered.';								# Error message for no text entered in to title/comment
use constant S_NOTITLE => 'No title entered.';								# Error message for no title entered
use constant S_NOTALLOWED => 'Posting not allowed for non-admins.';			# Error message when the posting type is forbidden for non-admins
use constant S_TOOLONG => 'Text field too long.';							# Error message for too many characters in a given field
use constant S_TOOMANYLINES => 'Too many lines in post.';					# Error message for too many characters in a given field
use constant S_UNUSUAL => 'Abnormal reply.';								# Error message for abnormal reply? (this is a mystery!)
use constant S_SPAM => 'Spammers are not welcome here!';					# Error message when detecting spam
use constant S_THREADCOLL => 'Somebody else tried to post a thread at the same time. Please try again.';		# If two people create threads during the same second
use constant S_NOTHREADERR => 'Thread specified does not exist.';			# Error message when a non-existant thread is accessed
use constant S_BADDELPASS => 'Password incorrect.';							# Error message for wrong password (when user tries to delete file)
use constant S_NOTWRITE => 'Cannot write to directory.';					# Error message when the script cannot write to the directory, the chmod (777) is wrong
use constant S_NOTASK => 'Script error; no task speficied.';				# Error message when calling the script incorrectly
use constant S_NOLOG => 'Couldn\'t write to log.txt.';						# Error message when log.txt is not writeable or similar
use constant S_TOOBIG => 'The file you tried to upload is too large.';		# Error message when the image file is larger than MAX_KB
use constant S_EMPTY => 'The file you tried to upload is empty.';	# Error message when the image file is 0 bytes
use constant S_BADFORMAT => 'File format not allowed.';			# Returns error when the file is not in a supported format.
use constant S_DUPE => 'This file has already been posted <a href="%s">here</a>.';	# Error message when an md5 checksum already exists.
use constant S_DUPENAME => 'A file with the same name already exists.';	# Error message when an filename already exists.



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
