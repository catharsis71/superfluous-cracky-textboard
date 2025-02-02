#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;

use CGI;

use lib '.';
BEGIN { require 'config.pl'; }
BEGIN { require 'config_defaults.pl'; }
BEGIN { require 'wakautils.pl'; }
BEGIN { require 'kareha.pl'; }

use constant KAREHA_SCRIPT => 'kareha.pl';
use constant SHOWN_LINES => 5;
use constant SHOWN_POSTS => 10;

use constant ADMIN_HEAD_INCLUDE => q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html;charset=<const CHARSET>" />
<title>Admin interface for <const TITLE></title>
<style type="text/css">
html, body { background: #eeeeff; }
a { color: #770022; }
a:hover { background: #aa1133; color: #eeeeff; }

#threadlist a { display: block; }
th { text-align: left; }

h2 { font-size: 1.2em; margin: 2em 0 0.5em 0; padding: 0; font-family: sans-serif; }
h2 a { text-decoration: none; color: #000000; }
h2 a:hover { text-decoration: underline; }

.post { border: 1px solid #7799cc; background: #e7e7ff; padding: 0; margin-bottom: 0.3em; clear: both; }
.postcommands { margin: 0; padding: 3px; background: #ccddff; font-family: sans-serif; }
h3 { font-size: 1em; margin: 0; padding: 0px; font-family: sans-serif; }
.posttext { padding: 0.5em 2em; }
.posttext a { text-decoration: none; color: #000000; }
.posttext a:hover { text-decoration: underline; }

.deletebutton { display:none; }
</style>
</head>
<body>
<h1>Admin interface for <const TITLE></h1>
};

use constant THREAD_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<div class="navi">
Pages: <loop template_for("page",0,(scalar(@$threads)-1)/THREADS_DISPLAYED)>
	<if $page eq $currpage><var $page></if>
	<if $page ne $currpage><a href="<var $self>/p<var $page>"><var $page></a></if>
</loop>
<a href="<var $self>/list">Thread list</a>
</div>

<div id="maincommands">
<if ALLOW_ADMIN_EDIT>
Edit: <loop $includes>
	<a href="<var $self>/edit?filename=<var urlenc($filename)>"><var $filename></a>
</loop>
<br />
</if>
<a href="<var $path><const KAREHA_SCRIPT>?task=rebuild&amp;admin=<var $adminpass>">Rebuild caches</a>
<a href="<var $self>/logout">Log out</a>
</div>

<div id="threads">
<loop $shownthreads>
	<h2><a href="<var $self>/<var $thread>/"><var $title or "Thread $thread"> (<var $postcount>)</a></h2>

	<div class="threadcommands">
	<if !$permasage><a href="<var $path><const KAREHA_SCRIPT>?task=permasagethread&amp;thread=<var $thread>&amp;state=1&amp;&amp;admin=<var $adminpass>&amp;r=1">permasage</a></if>
	<if $permasage><a href="<var $path><const KAREHA_SCRIPT>?task=permasagethread&amp;thread=<var $thread>&amp;state=0&amp;&amp;admin=<var $adminpass>&amp;r=1">unpermasage</a></if>
	-
	<if !$closed><a href="<var $path><const KAREHA_SCRIPT>?task=closethread&amp;thread=<var $thread>&amp;state=1&amp;&amp;admin=<var $adminpass>&amp;r=1">close</a></if>
	<if $closed><a href="<var $path><const KAREHA_SCRIPT>?task=closethread&amp;thread=<var $thread>&amp;state=0&amp;&amp;admin=<var $adminpass>&amp;r=1">open</a></if>
	</div>

	<loop $posts>
		<div class="post">
		<div class="postcommands">
		Posted by: <var $masked_ip>
		- Password: <var $password>
		- <a href="<var $path><const KAREHA_SCRIPT>?task=delete&amp;delete=<var $thread>,<var $num>&amp;password=<var $adminpass>&amp;r=1">delete</a>
		<if $filename>- <a href="<var $path><const KAREHA_SCRIPT>?task=delete&amp;delete=<var $thread>,<var $num>&amp;fileonly=1&amp;password=<var $adminpass>&amp;r=1">delete file</a></if>
		</div>
		<div class="posttext"><var $abbreviation or $text></div>
		</div>
	</loop>
</loop>
</div>

<div class="navi">
Pages: <loop template_for("page",0,(scalar(@$threads)-1)/THREADS_DISPLAYED)>
	<if $page eq $currpage><var $page></if>
	<if $page ne $currpage><a href="<var $self>/p<var $page>"><var $page></a></if>
</loop>
<a href="<var $self>/list">Thread list</a>
</div>

</body></html>
});



use constant EDIT_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<div id="navi">
<a href="<var $self>">Return</a>
</div>

<if $filename eq SPAM_FILE><p>
This is the list of domain names Kareha considers to be spam.<br />
You can find an up-to-date version
<a href="http://wakaba.c3.cx/antispam/antispam.pl?action=view&amp;format=wakaba">here</a>,
or you can get the <code>spam.txt</code> file directly <a href="http://wakaba.c3.cx/antispam/spam.txt">here</a>.
</p></if>

<form action="<var $self>/edit" method="post">
<textarea name="contents" cols="80" rows="45"><var clean_string($contents)></textarea>
<br />
<input type="hidden" name="filename" value="<var clean_string($filename)>" />
<input type="submit" value="Save" />
</form>

</body></html>
});


use constant LIST_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<div id="navi">
<a href="<var $self>">Return</a>
</div>

<table id="threadlist">
<thead><tr>
<th>Num</th><th>Title</th><th>Posts</th><th>Last post</th><th>File size</th>
</tr></thead>

<tbody>
<loop $threads>
	<tr class="line<var $num&1>">
	<td align="right"><var $num>:</td>
	<td><a href="<var $self>/<var $thread>/"><var $title or "Thread $thread"><if $closed or $permasage> <small>(<if $closed>closed</if><if !$closed and $permasage>permasaged</if>)</small></if></a></td>
	<td align="right"><a href="<var $self>/<var $thread>/"><var $postcount></a></td>
	<td><var make_date($lastmod,DATE_STYLE)></td>
	<td align="right"><var int($size/1024)> kb</td>

	<td>
	<if !$permasage><a href="<var $path><const KAREHA_SCRIPT>?task=permasagethread&amp;thread=<var $thread>&amp;state=1&amp;&amp;admin=<var $adminpass>&amp;r=1">permasage</a></if>
	<if $permasage><a href="<var $path><const KAREHA_SCRIPT>?task=permasagethread&amp;thread=<var $thread>&amp;state=0&amp;&amp;admin=<var $adminpass>&amp;r=1">unpermasage</a></if>
	</td>

	<td>
	<if !$closed><a href="<var $path><const KAREHA_SCRIPT>?task=closethread&amp;thread=<var $thread>&amp;state=1&amp;&amp;admin=<var $adminpass>&amp;r=1">close</a></if>
	<if $closed><a href="<var $path><const KAREHA_SCRIPT>?task=closethread&amp;thread=<var $thread>&amp;state=0&amp;&amp;admin=<var $adminpass>&amp;r=1">open</a></if>
	</td>

	</tr>
</loop>
</tbody></table>

</body></html>
});

use constant LOGIN_TEMPLATE => compile_template(ADMIN_HEAD_INCLUDE.q{
<form action="<var $ENV{SCRIPT_NAME}.$ENV{PATH_INFO}>" method="post">
<if $failed><div align="center"><strong>Password incorrect</strong></div></if>
<div align="center">
Admin password:
<input type="password" name="berra" />
<input type="submit" value="Login" />
</div>
</form>

</body></html>
});




use constant MASK_PASSWD => make_key("mask",SECRET,16);
use constant IP_PASSWD => rc4(null_string(32),"ip".SECRET);
use constant PASS_PASSWD => rc4(null_string(32),"cryptpass".SECRET);
use constant ENCODED_PASS => encode_admin_pass(ADMIN_PASS);




my @threads=get_threads(1);
my %log=read_log();

my $query=new CGI;
my $pass=$query->cookie("adminpass");

if($pass ne ENCODED_PASS)
{
	my $password=$query->param("berra");
	my $failed;

	if($password ne ADMIN_PASS)
	{
		print_http_header();

		print LOGIN_TEMPLATE->(
			failed=>defined $password,
		);

		exit;
	}
	else
	{
		make_cookies(adminpass=>ENCODED_PASS,-autopath=>"current");
	}
}

my @shownthreads;
my $showlist;
my ($threadnum,$ranges,$list,$edit,$logout,$page)=$ENV{PATH_INFO}=~m!/(?:([0-9]+)(?:/(.*)|)|(list)|(edit)|(logout)|p([0-9]+))!i;

if($threadnum)
{
	show_threads(filter_post_ranges($threadnum,$ranges));
}
elsif($list)
{
	show_list();
}
elsif($edit)
{
	die "Editing not allowed" unless(ALLOW_ADMIN_EDIT);

	my $filename=$query->param("filename");
	my $contents=$query->param("contents");

	if(defined $contents) { do_save($filename,$contents) }
	else { show_edit($filename) }
}
elsif($logout)
{
	make_cookies(adminpass=>"",-autopath=>"current");
	make_http_forward($ENV{SCRIPT_NAME},ALTERNATE_REDIRECT);
}
else
{
	$page=0 unless $page;
	my $start=$page*THREADS_DISPLAYED;
	my $end=$start+THREADS_DISPLAYED-1;
	$end=$#threads if $end>$#threads;

	show_threads(
		map { filter_post_ranges($threads[$_],"l".SHOWN_POSTS,SHOWN_LINES) } ($start..$end)
	);
}

sub show_threads(@)
{
	my @shownthreads=@_;

	foreach my $thread (@shownthreads)
	{
		foreach my $post (@{$$thread{posts}})
		{
			$$post{encrypted_password}=$log{$$thread{thread}}{$$post{num}}{password};
			$$post{encrypted_ip}=$log{$$thread{thread}}{$$post{num}}{ip};
			$$post{md5}=$log{$$thread{thread}}{$$post{num}}{md5};
			$$post{filename}=$log{$$thread{thread}}{$$post{num}}{filename};

			$$post{ip}=decrypt_ip($$post{encrypted_ip});
			$$post{password}=decrypt_password($$post{encrypted_password});
			$$post{masked_ip}=mask_ip($$post{ip},make_key("mask",SECRET,32));
		}
	}

	print_http_header();

	print THREAD_TEMPLATE->(
		threads=>\@threads,
		shownthreads=>\@shownthreads,
		currpage=>$page,
		adminpass=>ENCODED_PASS,
		includes=>[map +{ filename=>$_ },(glob(INCLUDE_DIR."*"),SPAM_FILE)],
	);
}

sub show_list()
{
	print_http_header();

	print LIST_TEMPLATE->(
		threads=>\@threads,
		adminpass=>ENCODED_PASS,
	);
}

sub show_edit($)
{
	my ($filename)=@_;

	my $include=quotemeta INCLUDE_DIR;
	die unless $filename=~m!^$include[^/\\]+$! || $filename eq SPAM_FILE;

	my $contents=join "\n",read_array($filename);

	print_http_header();

	print EDIT_TEMPLATE->(
		filename=>$filename,
		contents=>$contents,
	);
}

sub do_save($$)
{
	my ($filename,$contents)=@_;

	my $include=quotemeta INCLUDE_DIR;
	die unless $filename=~m!^$include[^/\\]+$! || $filename eq SPAM_FILE;

	write_array($filename,$contents);

	make_http_forward($ENV{SCRIPT_NAME},ALTERNATE_REDIRECT);
}

sub print_http_header()
{
	print "Content-Type: ".get_xhtml_content_type(CHARSET,USE_XHTML)."\n";
	print "Expires: Mon, 26 Jul 1997 05:00:00 GMT\n";
	print "Cache-Control: max-age=0; must-revalidate; no-cache\n";
	print "Pragma: no-cache\n";
	print "\n";
}




sub read_log()
{
	my %posts;

	for(read_array(LOG_FILE))
	{
		my ($thread,$num,%post);
		($thread,$num,@post{"password","ip","key","md5","filename"})=split /\s*,\s*/;

		$posts{$thread}{$num}=\%post;
	}

	return %posts;
}

sub decrypt_ip($)
{
	my ($str)=@_;
	my ($iv,$cipher);

	if(($iv,$cipher)=$str=~/^(.*?)!(.*)$/)
	{
		eval "use Digest::MD5 qw(md5)";
		return rc4_old(decode_base64($cipher),md5(SECRET.$iv));
	}
	elsif(($iv,$cipher)=$str=~/^(.*?):(.*)$/)
	{
		return rc4(decode_base64($cipher),"l".$iv.SECRET);
	}
	elsif(($iv,$cipher)=$str=~/^(.*?);(.*)$/)
	{
		return rc4(decode_base64($cipher),IP_PASSWD.$iv);
	}
}

sub decrypt_password($)
{
	my ($str)=@_;
	my ($iv,$cipher);

	if(($iv,$cipher)=$str=~/^(.*?);(.*)$/)
	{
		return rc4(decode_base64($cipher),PASS_PASSWD.$iv);
	}
	else
	{
		return $str;
	}
}

sub rc4_old($$)
{
	my ($message,$key)=@_;

    my @k=unpack 'C*',$key;
    my @s=0..255;
    my $y=0;
    for my $x (0..255)
    {
		$y=($k[$x%@k]+$s[$x]+$y)%256;
		@s[$x,$y]=@s[$y,$x];
    }

	my $x,$y;

	my @message=unpack 'C*',$message;
	for(@message)
	{
		$x=($x+1)%256;
		$y=($y+$s[$x])%256;
		@s[$x,$y]=@s[$y,$x];
		$_^=$s[($s[$x]+$s[$y])%256];
	}
	return pack 'C*',@message;
}
