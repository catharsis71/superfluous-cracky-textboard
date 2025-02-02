#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;

use CGI;
use Data::Dumper;
use Fcntl ':flock';

use lib '.';
BEGIN { require 'config.pl'; }
BEGIN { require 'config_defaults.pl'; }
BEGIN { require 'templates.pl'; }
BEGIN { require 'captcha.pl'; }
BEGIN { require 'wakautils.pl'; }



#
# Global init
#

my $replyrange_re=qr/(?:[0-9\-,lrq]|&#44;)*[0-9\-lrq]/; # regexp to match reply ranges for >> links
my $protocol_re=qr/(?:http|https|ftp|mailto|nntp)/;

no strict;
$stylesheets=get_stylesheets(); # make stylesheets visible to the templates
use strict;

my $query=new CGI;
my $task=$query->param("task");

# Rebuild main page if it doesn't exist
unless(-e HTML_SELF)
{
	build_pages();
	upgrade_threads();
}

if(!$task)
{
	if($ENV{PATH_INFO}) { show_thread($ENV{PATH_INFO}) }
	else { make_http_forward(HTML_SELF,ALTERNATE_REDIRECT) }
	exit 0;
}

my $log=lock_log();

if($task eq "post")
{
	my $thread=$query->param("thread");
	my $name=$query->param("name");
	my $link=$query->param("link");
	my $title=$query->param("title");
	my $comment=$query->param("comment");
	my $captcha=$query->param("captcha");
	my $password=$query->param("password");
	my $file=$query->param("file");
	my $key=$query->cookie("captchakey");

	post_stuff($thread,$name,$link,$title,$comment,$captcha,$key,$password,$file,$file);
}
elsif($task eq "delete")
{
	my $password=$query->param("password");
	my $fileonly=$query->param("fileonly");
	my @posts=$query->param("delete");

	delete_stuff($password,$fileonly,@posts);
}
elsif($task eq "deletethread")
{
	make_error(S_BADDELPASS) unless($query->param("admin") eq ADMIN_PASS);

	my $thread=$query->param("thread");
	delete_thread($thread);
}
elsif($task eq "permasagethread")
{
	make_error(S_BADDELPASS) unless($query->param("admin") eq ADMIN_PASS);

	my $thread=$query->param("thread");
	permasage_thread($thread);
}
elsif($task eq "rebuild")
{
	make_error(S_BADDELPASS) unless($query->param("admin") eq ADMIN_PASS);

	build_pages();
	upgrade_threads();
}
else
{
	make_error(S_NOTASK);
}

release_log($log);

make_http_forward(HTML_SELF,ALTERNATE_REDIRECT);

#
# End of main code
#


sub show_thread($)
{
	my ($path)=@_;
	my ($thread,$ranges)=$path=~m!/([0-9]+)/?(.*)!;
	my $filename=RES_DIR.$thread.PAGE_EXT;
	my $modified=(stat $filename)[9];

	if($ENV{HTTP_IF_MODIFIED_SINCE})
	{
		my $ifmod=parse_http_date($ENV{HTTP_IF_MODIFIED_SINCE});
		if($modified<=$ifmod)
		{
			print "Status: 304 Not modified\n\n";
			return;
		}
	}

	my @page=read_array($filename);
	make_error(S_NOTHREADERR) unless(@page);

	my @posts;
	my $total=@page-3;

	foreach my $range (split /,/,$ranges)
	{
		if($range=~/^([0-9]*)-([0-9]*)$/)
		{
			my $start=($1 or 1);
			my $end=($2 or $total);

			$start=$total if($start>$total);
			$end=$total if($end>$total);

			if($start<$end) { push @posts,($start..$end) }
			else { push @posts,reverse ($end..$start) }
		}
		elsif($range=~/^([0-9]+)$/)
		{
			my $post=$1;
			push @posts,$post if($post>0 and $post<=$total);
		}
		elsif($range=~/^l([0-9]+)$/i)
		{
			my $start=$total-$1+1;
			$start=1 if($start<1);
			push @posts,($start..$total);
		}
		elsif($range=~/^r([0-9]*)$/i)
		{
			my $num=($1 or 1);
			push @posts,int (rand $total)+1 for(1..$num);
		}
		elsif($range=~/^q([0-9]+)$/i)
		{
			my $num=$1;

			push @posts,$num;
			OUTER: foreach my $post (1..$total)
			{
				next if($post eq $num);
				while($page[$post+1]=~/&gt;&gt;($replyrange_re)/g)
				{
					if(in_range($num,$1)) { push @posts,$post; next OUTER; }
				}
			}
		}
	}

	@posts=(1..$total) unless(@posts);

	print "Content-Type: ".get_xhtml_content_type(CHARSET,USE_XHTML)."\n";
	print "Date: ".make_date(time(),"http")."\n";
	print "Last-Modified: ".make_date($modified,"http")."\n";
	print "\n";

	print join "\n",($page[1],(map { $page[$_+1] } @posts),$page[$#page]);
}

sub in_range($$)
{
	my ($num,$ranges)=@_;

	foreach my $range (split /(,|&#44;)/,$ranges)
	{
		if($range=~/^([0-9]*)-([0-9]*)$/)
		{
			my $start=($1 or 1);
			my $end=($2 or 1000000); # arbitary large number

			($start,$end)=($end,$start) if($start>$end);

			return 1 if($num>=$start and $num<=$end);
		}
		elsif($range=~/^([0-9]+)$/)
		{
			return 1 if($num==$1);
		}
		#elsif($range=~/^l([0-9]+)$/i) {} # l ranges never match
		#elsif($range=~/^r([0-9]*)$/i) {} # r ranges never match
		#elsif($range=~/^q([0-9]+)$/i) {} # q ranges never match
	}
	return 0;
}

sub build_pages()
{
	my @allthreads=get_threads(1);
	my @copy=@allthreads;
	my @pages;

	# generate page subdivisions
	if(PAGE_GENERATION eq "paged")
	{
		$pages[0]{threads}=[splice @copy,0,THREADS_DISPLAYED];
		$pages[0]{filename}=HTML_SELF;
		$pages[0]{page}="0";

		my @threads;
		while(@threads=splice @copy,0,THREADS_DISPLAYED)
		{
			push @pages,{ threads=>[@threads],filename=>@pages.PAGE_EXT,page=>scalar @pages };
		}
	}
	elsif(PAGE_GENERATION eq "monthly")
	{
		$pages[0]{threads}=[splice @copy,0,THREADS_DISPLAYED];
		$pages[0]{filename}=HTML_SELF;
		$pages[0]{page}=S_FRONT;

		my @unbumped=sort { $$b{thread}<=>$$a{thread} } @allthreads;
		foreach my $thread (@unbumped) { $$thread{month}=make_date($$thread{thread},"month") }

		while(@unbumped)
		{
			my @month=(shift @unbumped);
			while(@unbumped and $unbumped[0]{month} eq $month[0]{month}) { push @month,shift @unbumped }

			my $monthname=$month[0]{month};
			my $filename=lc($monthname).PAGE_EXT;
			$filename=~tr/ /_/;

			push @pages,{ threads=>\@month,filename=>$filename,page=>$monthname };
		}
	}
	else
	{
		$pages[0]{threads}=[splice @copy,0,THREADS_DISPLAYED];
		$pages[0]{filename}=HTML_SELF;
		$pages[0]{page}=S_FRONT;
	}

	# figure out next/prev links
	for(1..$#pages-1)
	{
		$pages[$_]{nextpage}=$pages[$_+1]{filename};
		$pages[$_]{prevpage}=$pages[$_-1]{filename};
	}
	if(@pages>1)
	{
		$pages[0]{nextpage}=$pages[1]{filename};
		$pages[$#pages]{prevpage}=$pages[$#pages-1]{filename};
	}

	# process and generate pages
	foreach my $page (@pages)
	{
		# fix up each thread
		foreach my $thread (@{$$page{threads}})
		{
			my @threadpage=read_array($$thread{filename});
			shift @threadpage; # drop the metadata

			my $posts=$$thread{postcount};
			my $images=grep { get_images($_) } @threadpage[2..$posts];
			my $curr_replies=$posts-1;
			my $curr_images=$images;
			my $max_replies=REPLIES_PER_THREAD;
			my $max_images=(IMAGE_REPLIES_PER_THREAD or $images);
			my $start=2;

			# drop replies until we have few enough replies and images
			while($curr_replies>$max_replies or $curr_images>$max_images)
			{
				$curr_images-- if(get_images($threadpage[$start]));
				$curr_replies--;
				$start++;
			}

			# fix up and abbreviate posts
			my @posts=map {
				my %post;
				my $reply=$threadpage[$_];
				my $abbrev=abbreviate_reply($reply);

				$post{postnum}=$_;
				$post{first}=($_==1);
				$post{abbrev}=$abbrev?1:0;
				$post{reply}=$abbrev?$abbrev:$reply;

				\%post;
			} (1,$start..$posts);

			$$thread{posts}=\@posts;
			$$thread{omit}=$start-2;
			$$thread{omitimages}=$images-$curr_images;

			$$thread{next}=$$thread{num}%(THREADS_DISPLAYED)+1;
			$$thread{prev}=($$thread{num}+(THREADS_DISPLAYED)-2)%(THREADS_DISPLAYED)+1;
		}

		write_array($$page{filename},MAIN_PAGE_TEMPLATE->(
			%$page,
			pages=>\@pages,
			allthreads=>\@allthreads,
			current=>$$page{page},
		));
	}

	write_array(HTML_BACKLOG,BACKLOG_PAGE_TEMPLATE->(threads=>\@allthreads)) if(HTML_BACKLOG);
	write_array(RSS_FILE,RSS_TEMPLATE->(threads=>\@allthreads)) if(RSS_FILE);

	# delete extra pages
	# BUG: no deletion in monthly mode
	if(PAGE_GENERATION eq "paged")
	{
		my $page=@pages;
		while(-e $page.PAGE_EXT)
		{
			unlink $page.PAGE_EXT;
			$page++;
		}
	}
}

sub abbreviate_reply($)
{
	my ($reply)=@_;

	if($reply=~m!^(.*?<div class="replytext">)(.*?)(</div>.*$)!s)
	{
		my ($prefix,$comment,$postfix)=($1,$2,$3);

		my $abbrev=abbreviate_html($comment,MAX_LINES_SHOWN,APPROX_LINE_LENGTH);
		return $prefix.$abbrev.$postfix if($abbrev);
	}
	else
	{
		my $abbrev=abbreviate_html($reply,MAX_LINES_SHOWN,APPROX_LINE_LENGTH);
		return $abbrev if($abbrev);
	}

	return undef;
}

sub upgrade_threads()
{
	my @threads=get_threads(1);

	foreach my $thread (@threads)
	{
		my @threadpage=read_array($$thread{filename});

		my $num=$$thread{postcount};

		$threadpage[1]=THREAD_HEAD_TEMPLATE->(%{$thread});
		$threadpage[$num+2]=THREAD_FOOT_TEMPLATE->(%{$thread});

		write_array($$thread{filename},@threadpage);
	}
}



#
# Posting
#

sub post_stuff($$$$$$$$$$)
{
	my ($thread,$name,$link,$title,$comment,$captcha,$key,$password,$file,$uploadname)=@_;

	# get a timestamp for future use
	my $time=time();

	# check that the request came in as a POST, or from the command line
	make_error(S_UNJUST) if($ENV{REQUEST_METHOD} and $ENV{REQUEST_METHOD} ne "POST");

	# check for weird characters
	make_error(S_UNUSUAL) if($thread=~/[^0-9]/);
	make_error(S_UNUSUAL) if(length($thread)>10);
	make_error(S_UNUSUAL) if($name=~/[\n\r]/);
	make_error(S_UNUSUAL) if($link=~/[\n\r]/);
	make_error(S_UNUSUAL) if($title=~/[\n\r]/);

	# check for excessive amounts of text
	make_error(S_TOOLONG) if(length($name)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($link)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($title)>MAX_FIELD_LENGTH);
	make_error(S_TOOLONG) if(length($comment)>MAX_COMMENT_LENGTH);

	# check for empty post
	make_error(S_NOTEXT) if($comment=~/^\s*$/ and !$file);
	make_error(S_NOTITLE) if(REQUIRE_THREAD_TITLE and $title=~/^\s*$/ and !$thread);

	# find hostname
	my $ip=$ENV{REMOTE_ADDR};
	#$host = gethostbyaddr($ip);

	# check captcha
	if(ENABLE_CAPTCHA)
	{
		make_error(S_BADCAPTCHA) if(find_key($log,$key));
		make_error(S_BADCAPTCHA) if(!check_captcha($key,$captcha));
	}

	# proxy check - not implemented yet, and might not ever be
	#proxy_check($ip) unless($whitelisted);

	# spam check
	make_error(S_SPAM) if(spam_check($comment,SPAM_FILE));
	make_error(S_SPAM) if(spam_check($title,SPAM_FILE));
	make_error(S_SPAM) if(spam_check($name,SPAM_FILE));
	make_error(S_SPAM) if(spam_check($link,SPAM_FILE));

	# check if thread exists
	make_error(S_NOTHREADERR) if($thread and !-e RES_DIR.$thread.PAGE_EXT);

	# remember cookies
	my $c_name=$name;
	my $c_link=$link;
	my $c_password=$password;

	# kill the name if anonymous posting is being enforced
	if(FORCED_ANON)
	{
		$name='';
		if($link=~/sage/i) { $link='sage'; }
		else { $link=''; }
	}

	# clean up the inputs
	$link=clean_string($link);
	$title=clean_string($title);
	$comment=clean_string($comment);

	# fix up the link
	$link="mailto:$link" if($link and $link!~/^$protocol_re:/);

	# process the tripcode
	my ($trip,$capped);
	($name,$trip)=process_tripcode($name,TRIPKEY,SECRET,CHARSET);
	$capped=1 if(grep { $trip eq $_ } ADMIN_TRIPS);

	# insert default values for empty fields
	$name=make_anonymous($ip,$time,($thread or $time)) unless($name or $trip);

	# check for posting limitations
	unless($capped)
	{
		if($thread)
		{
			make_error(S_NOTALLOWED) if($file and !ALLOW_IMAGE_REPLIES);
			make_error(S_NOTALLOWED) if(!$file and !ALLOW_TEXT_REPLIES);
		}
		else
		{
			make_error(S_NOTALLOWED) if($file and !ALLOW_IMAGE_THREADS);
			make_error(S_NOTALLOWED) if(!$file and !ALLOW_TEXT_THREADS);
		}
	}

	# copy file, do checksums, make thumbnail, etc
	my ($filename,$ext,$size,$md5,$width,$height,$thumbnail,$tn_width,$tn_height)=process_file($file,$uploadname,$time) if($file);

	# create the thread if we are starting a new one
	$thread=make_thread($title,$time,$name.$trip) unless($thread);

	# format the comment
	$comment=format_comment($comment,$thread);

	# generate date
	my $date=make_date($time,DATE_STYLE);

	# generate ID code if enabled
	$date.=' ID:'.make_id_code($ip,$time,$link,$thread) if(DISPLAY_ID);

	# add the reply to the thread
	my $num=make_reply(
		ip=>$ip,thread=>$thread,name=>$name,trip=>$trip,link=>$link,capped=>($capped and VISIBLE_ADMINS),
		time=>$time,date=>$date,title=>$title,comment=>$comment,
		image=>$filename,ext=>$ext,size=>$size,md5=>$md5,width=>$width,height=>$height,
		thumbnail=>$thumbnail,tn_width=>$tn_width,tn_height=>$tn_height,
	);

	# make entry in the log
	add_log($log,$thread,$num,$password,$ip,$key,$md5,$filename);

	# remove old threads from the database
	trim_threads();

	build_pages();

	# set the name, email and password cookies, plus a new captcha key
	make_cookies(name=>$c_name,link=>$c_link,password=>$c_password,
	captchakey=>make_random_string(8),-charset=>CHARSET,-autopath=>COOKIE_PATH); # yum!
}

sub proxy_check($)
{
	my ($ip)=@_;

	for my $port (PROXY_CHECK)
	{
		# needs to be implemented
		# die sprintf S_PROXY,$port);
	}
}

sub format_comment($$)
{
	my ($comment,$thread)=@_;

	# hide >>1 references from the quoting code
	$comment=~s/&gt;&gt;((?:[0-9\-,lr]|&#44;)+)/&gtgt;$1/g;

	my $handler=sub # fix up >>1 references
	{
		my $line=shift;
		$line=~s!&gtgt;($replyrange_re)!\<a href="$ENV{SCRIPT_NAME}/$thread/$1"\>&gt;&gt;$1\</a\>!gm;
		return $line;
	};

	if(ENABLE_WAKABAMARK) { $comment=do_wakabamark($comment,$handler) }
	else { $comment="<p>".simple_format($comment,$handler)."</p>" }

	# fix <blockquote> styles for old stylesheets
	$comment=~s/<blockquote>/<blockquote class="unkfunc">/g if(FUDGE_BLOCKQUOTES);

	# restore >>1 references hidden in code blocks
	$comment=~s/&gtgt;/&gt;&gt;/g;

	return $comment;
}

sub simple_format($@)
{
	my ($text,$handler)=@_;
	return join "<br />",map
	{
		my $line=$_;

		# make URLs into links
		$line=~s{($protocol_re://[^\s<>"]*?)((?:\s|<|>|"|\.|\)|\]|!|\?|,|&#44;|&quot;)*(?:[\s<>"]|$))}{\<a href="$1"\>$1\</a\>$2}sgi;

		$line=$handler->($line) if($handler);

		$line;
	} split /\n/,$text;
}

sub make_anonymous($$$)
{
	my ($ip,$time,$thread)=@_;

	return S_ANONAME unless(SILLY_ANONYMOUS);

	my $string=$ip;
	$string.=",".int($time/86400) if(SILLY_ANONYMOUS=~/day/i);
	$string.=",".$ENV{SCRIPT_NAME} if(SILLY_ANONYMOUS=~/board/i);
	$string.=",".$thread if(SILLY_ANONYMOUS=~/thread/i);

	srand unpack "N",rc4(null_string(4),"s".$string.SECRET);

	return cfg_expand("%G% %W%",
		W => ["%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%","%O%%E%","%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%","%O%%E%","%B%%V%%M%%I%%V%%F%","%B%%V%%M%%E%"],
		B => ["B","B","C","D","D","F","F","G","G","H","H","M","N","P","P","S","S","W","Ch","Br","Cr","Dr","Bl","Cl","S"],
		I => ["b","d","f","h","k","l","m","n","p","s","t","w","ch","st"],
		V => ["a","e","i","o","u"],
		M => ["ving","zzle","ndle","ddle","ller","rring","tting","nning","ssle","mmer","bber","bble","nger","nner","sh","ffing","nder","pper","mmle","lly","bling","nkin","dge","ckle","ggle","mble","ckle","rry"],
		F => ["t","ck","tch","d","g","n","t","t","ck","tch","dge","re","rk","dge","re","ne","dging"],
		O => ["Small","Snod","Bard","Billing","Black","Shake","Tilling","Good","Worthing","Blythe","Green","Duck","Pitt","Grand","Brook","Blather","Bun","Buzz","Clay","Fan","Dart","Grim","Honey","Light","Murd","Nickle","Pick","Pock","Trot","Toot","Turvey"],
		E => ["shaw","man","stone","son","ham","gold","banks","foot","worth","way","hall","dock","ford","well","bury","stock","field","lock","dale","water","hood","ridge","ville","spear","forth","will"],
		G => ["Albert","Alice","Angus","Archie","Augustus","Barnaby","Basil","Beatrice","Betsy","Caroline","Cedric","Charles","Charlotte","Clara","Cornelius","Cyril","David","Doris","Ebenezer","Edward","Edwin","Eliza","Emma","Ernest","Esther","Eugene","Fanny","Frederick","George","Graham","Hamilton","Hannah","Hedda","Henry","Hugh","Ian","Isabella","Jack","James","Jarvis","Jenny","John","Lillian","Lydia","Martha","Martin","Matilda","Molly","Nathaniel","Nell","Nicholas","Nigel","Oliver","Phineas","Phoebe","Phyllis","Polly","Priscilla","Rebecca","Reuben","Samuel","Sidney","Simon","Sophie","Thomas","Walter","Wesley","William"],
	);
}

sub make_id_code($$$$)
{
	my ($ip,$time,$link,$thread)=@_;

	return EMAIL_ID if($link and EMAIL_ID);

	my $string=$ip;
	$string.=",".int($time/86400) if(DISPLAY_ID=~/day/i);
	$string.=",".$ENV{SCRIPT_NAME} if(DISPLAY_ID=~/board/i);
	$string.=",".$thread if(DISPLAY_ID=~/thread/i);
	return encode_base64(rc4(null_string(6),"i".$string.SECRET),"");
}

sub make_reply(%)
{
	my (%vars)=@_;

	my $filename=RES_DIR.$vars{thread}.PAGE_EXT;
	my @page=read_array($filename);
	my %meta=parse_meta_header($page[0]);
	my $size=-s $filename;

	my $num=$meta{postcount}+1;

	$meta{postcount}++;
	$meta{lasthit}=$vars{time} unless($vars{link}=~/sage/i or $meta{postcount}>=MAX_RES or $meta{permasage}); # bump unless sage, too many replies, or permasage

	$page[0]=make_meta_header(%meta);
	$page[1]=THREAD_HEAD_TEMPLATE->(%meta,thread=>$vars{thread},size=>$size);
	$page[$num+1]=REPLY_TEMPLATE->(%vars,num=>$num);
	$page[$num+2]=THREAD_FOOT_TEMPLATE->(%meta,thread=>$vars{thread},size=>$size);

	write_array($filename,@page);

	return $num;
}

sub make_thread($$$)
{
	my ($title,$time,$author)=@_;
	my $filename=RES_DIR.$time.PAGE_EXT;

	make_error(S_THREADCOLL) if(-e $filename);

	write_array($filename,make_meta_header(title=>$title,postcount=>0,lasthit=>$time,permasage=>0,author=>$author),"","");

	return $time;
}




#
# Deleting
#

sub delete_stuff($@)
{
	my ($password,$fileonly,@posts)=@_;

	foreach my $post (@posts)
	{
		my ($thread,$num)=$post=~/([0-9]+),([0-9]+)/;

		delete_post($thread,$num,$password,$fileonly);
	}

	build_pages();
}

sub trim_threads()
{
	my @threads=get_threads(TRIM_METHOD);

	my ($posts,$size);
	$posts+=$$_{postcount} for(@threads);
	$size+=-s $_ for(glob(IMG_DIR."*"));

	my $max_threads=(MAX_THREADS or @threads);
	my $max_posts=(MAX_POSTS or $posts);
	my $max_size=(MAX_MEGABYTES*1024*1024 or $size);

	while(@threads>$max_threads or $posts>$max_posts or $size>$max_size)
	{
		my $thread=pop @threads;
		my @page=read_array($$thread{filename});
		foreach my $reply (@page[2..$#page-1])
		{
			my ($image,$thumb)=get_images($reply);
			$size-=-s $image;
		}
		$posts-=$$thread{postcount};

		delete_thread($$thread{thread});
	}
}

sub delete_post($$$$)
{
	my ($thread,$post,$password,$fileonly)=@_;

	make_error(S_BADDELPASS) unless($password);
	make_error(S_BADDELPASS) unless($password eq ADMIN_PASS or match_password($log,$thread,$post,$password));

	my $reason;
	if($password eq ADMIN_PASS) { $reason="mod"; }
	else { $reason="user"; }

	my $filename=RES_DIR.$thread.PAGE_EXT;
	my @page=read_array($filename);
	return unless(@page);

	my %meta=parse_meta_header($page[0]);
	if($post==1 and !$fileonly)
	{
		if(DELETE_FIRST eq 'remove' or (DELETE_FIRST eq 'single' and $meta{postcount}==1))
		{ delete_thread($thread); return }
	}

	# remove images
	unlink get_images($page[$post+1]);

	# remove post
	unless($fileonly)
	{
		$page[$post+1]=DELETED_TEMPLATE->(num=>$post,reason=>$reason);
		write_array($filename,@page);
	}
}

sub delete_thread($)
{
	my ($thread)=@_;

	make_error(S_UNUSUAL) if($thread=~/[^0-9]/); # check to make sure the thread argument is safe

	my $filename=RES_DIR.$thread.PAGE_EXT;
	my @page=read_array($filename);

	# remove images
	foreach my $reply (@page[2..$#page-1]) { unlink get_images($reply) }

	unlink RES_DIR.$thread.PAGE_EXT;

	build_pages();
}

sub permasage_thread($)
{
	my ($thread)=@_;

	make_error(S_UNUSUAL) if($thread=~/[^0-9]/); # check to make sure the thread argument is safe

	my $filename=RES_DIR.$thread.PAGE_EXT;
	my @page=read_array($filename);
	my %meta=parse_meta_header($page[0]);

	$meta{permasage}=1;

	$page[0]=make_meta_header(%meta);
	write_array($filename,@page);

	build_pages();
}



#
# Utility funtions
#

sub get_stylesheets()
{
	my $found=0;
	my @stylesheets=map
	{
		my %sheet;

		$sheet{filename}=$_;

		($sheet{title})=m!([^/]+)\.css$!i;
		$sheet{title}=ucfirst $sheet{title};
		$sheet{title}=~s/_/ /g;
		$sheet{title}=~s/ ([a-z])/ \u$1/g;
		$sheet{title}=~s/([a-z])([A-Z])/$1 $2/g;

		if($sheet{title} eq DEFAULT_STYLE) { $sheet{default}=1; $found=1; }
		else { $sheet{default}=0; }

		\%sheet;
	} glob(CSS_DIR."*.css");

	$stylesheets[0]{default}=1 if(@stylesheets and !$found);

	return \@stylesheets;
}



#
# Metadata access utils
#

sub get_threads($)
{
	my ($bumped)=@_;

	my @pages=map {
		open PAGE,$_ or return undef;
		my $head=<PAGE>;
		close PAGE;
		my %meta=parse_meta_header($head);

		my $re=RES_DIR.'([0-9]+)'.PAGE_EXT;
		my ($thread)=$_=~/$re/;

		my $hash={ %meta,thread=>$thread,filename=>$_,size=>-s $_ };
		$hash;
	} glob(RES_DIR."*".PAGE_EXT);

	if($bumped) { @pages=sort { $$b{lasthit}<=>$$a{lasthit} } @pages; }
	else { @pages=sort { $$b{thread}<=>$$a{thread} } @pages; }

	my $num=1;
	$$_{num}=$num++ for(@pages);

	return @pages;
}

sub parse_meta_header($)
{
	my ($header)=@_;
	my ($code)=$header=~/\<!--(.*)--\>/;
	return () unless $code;
	return %{eval $code};
}

sub make_meta_header(%)
{
	my (%meta)=@_;
	$Data::Dumper::Terse=1;
	$Data::Dumper::Indent=0;
	return '<!-- '.Dumper(\%meta).' -->';
}

sub match_password($$$$)
{
	my ($log,$thread,$post,$password)=@_;
	my $encpass=encode_password($password);

	return 0 unless(ENABLE_DELETION);

	foreach(@{$log})
	{
		my @data=split /\s*,\s*/;
		return 1 if($data[0]==$thread and $data[1]==$post and $data[2] eq $encpass);
	}
	return 0;
}

sub find_key($$)
{
	my ($log,$key)=@_;

	foreach(@{$log})
	{
		my @data=split /\s*,\s*/;
		return 1 if($data[4] eq $key);
	}
	return 0;
}

sub find_md5($$)
{
	my ($log,$md5)=@_;

	foreach(@{$log})
	{
		my @data=split /\s*,\s*/;
		return ($data[0],$data[1]) if($data[5] eq $md5 and -e $data[6]);
	}
	return ();
}

sub lock_log()
{
	open LOGFILE,"+>>log.txt" or make_error(S_NOLOG);
	eval "flock LOGFILE,LOCK_EX"; # may not work on some platforms - ignore it if it does not.
	seek LOGFILE,0,0;

	my @log=grep { /^([0-9]+)/; -e RES_DIR.$1.PAGE_EXT } read_array(\*LOGFILE);

	# should remove MD5 for deleted files somehow
	return \@log;
}

sub release_log(;$)
{
	my ($log)=@_;

	if($log)
	{
		seek LOGFILE,0,0;
		truncate LOGFILE,0;
		write_array(\*LOGFILE,@$log);
	}

	close LOGFILE;
}

sub add_log($$$$$$$)
{
	my ($log,$thread,$post,$password,$ip,$key,$md5,$file)=@_;

	$password=encode_password($password);
	$ip=encode_ip($ip);

	unshift @$log,"$thread,$post,$password,$ip,$key,$md5,$file";
}

sub encode_password($) { return encode_base64(rc4(null_string(6),"p".(shift).SECRET),""); }
sub encode_ip($) { my $iv=make_random_string(8); return $iv.':'.encode_base64(rc4($_[0],"l".$iv.SECRET),""); }

#
# Error handling
#

sub make_error($)
{
	my ($error)=@_;

	print "Content-Type: ".get_xhtml_content_type(CHARSET,USE_XHTML)."\n";
	print "\n";
	print ERROR_TEMPLATE->(error=>$error);
	exit 0;
}



#
# Image handling
#

sub get_filetypes()
{
	my %filetypes=FILETYPES;
	$filetypes{gif}=$filetypes{jpg}=$filetypes{png}=1;
	return join ", ",map { uc } sort keys %filetypes;
}

sub get_images($)
{
	my ($post)=@_;
	my @images;
	my $img_dir=quotemeta IMG_DIR;
	my $thumb_dir=quotemeta THUMB_DIR;

	push @images,$1 if($post=~m!<a [^>]*href="/[^>"]*($img_dir[^>"/]+)"!);
	push @images,$1 if($post=~m!<img [^>]*src="/[^>"]*($thumb_dir[^>"/]+)"!);

	return @images;
}

sub process_file($$$)
{
	my ($file,$uploadname,$time)=@_;
	my %filetypes=FILETYPES;

	# find out the file size
	my $size=-s $file;

	make_error(S_TOOBIG) if($size>MAX_KB*1024);
	make_error(S_EMPTY) if($size==0);

	# make sure to read file in binary mode on platforms that care about such things
	binmode $file;

	# analyze file and check that it's in a supported format
	my ($ext,$width,$height)=analyze_image($file,$uploadname);

	my $known=$width or $filetypes{$ext};

	make_error(S_BADFORMAT) unless(ALLOW_UNKNOWN or $known);
	make_error(S_BADFORMAT) if(grep { $_ eq $ext } FORBIDDEN_EXTENSIONS);
	make_error(S_TOOBIG) if(MAX_IMAGE_WIDTH and $width>MAX_IMAGE_WIDTH);
	make_error(S_TOOBIG) if(MAX_IMAGE_HEIGHT and $height>MAX_IMAGE_HEIGHT);
	make_error(S_TOOBIG) if(MAX_IMAGE_PIXELS and $width*$height>MAX_IMAGE_PIXELS);

	# generate random filename - fudges the microseconds
	my $filebase=$time.sprintf("%03d",int(rand(1000)));
	my $filename=IMG_DIR.$filebase.'.'.$ext;
	my $thumbnail=THUMB_DIR.$filebase."s.jpg";
	$filename.=MUNGE_UNKNOWN unless($known);

	# do copying and MD5 checksum
	my ($md5,$md5ctx,$buffer);

	# prepare MD5 checksum if the Digest::MD5 module is available
	eval 'use Digest::MD5 qw(md5_hex)';
	$md5ctx=Digest::MD5->new unless($@);

	# copy file
	open (OUTFILE,">>$filename") or make_error(S_NOTWRITE);
	binmode OUTFILE;
	while (read($file,$buffer,1024)) # should the buffer be larger?
	{
		print OUTFILE $buffer;
		$md5ctx->add($buffer) if($md5ctx);
	}
	close $file;
	close OUTFILE;

	if($md5ctx) # if we have Digest::MD5, get the checksum
	{
		$md5=$md5ctx->hexdigest();
	}
	else # otherwise, try using the md5sum command
	{
		my $md5sum=`md5sum $filename`; # filename is always the timestamp name, and thus safe
		($md5)=$md5sum=~/^([0-9a-f]+)/ unless($?);
	}

	if($md5) # if we managed to generate an md5 checksum, check for duplicate files
	{
		my ($thread,$post)=find_md5($log,$md5);
		if($thread)
		{
			unlink $filename; # make sure to remove the file
			make_error(sprintf S_DUPE,"$ENV{SCRIPT_NAME}/$thread/$post");
		}
	}

	# do thumbnail
	my ($tn_width,$tn_height,$tn_ext);

	if(!$width) # unsupported file
	{
		if($filetypes{$ext}) # externally defined filetype
		{
			open THUMBNAIL,$filetypes{$ext};
			binmode THUMBNAIL;
			($tn_ext,$tn_width,$tn_height)=analyze_image(\*THUMBNAIL,$filetypes{$ext});
			close THUMBNAIL;

			# was that icon file really there?
			if(!$tn_width) { $thumbnail=undef }
			else { $thumbnail=$filetypes{$ext} }
		}
		else
		{
			$thumbnail=undef;
		}
	}
	elsif($width>MAX_W or $height>MAX_H or THUMBNAIL_SMALL)
	{
		if($width<=MAX_W and $height<=MAX_H)
		{
			$tn_width=$width;
			$tn_height=$height;
		}
		else
		{
			$tn_width=MAX_W;
			$tn_height=int(($height*(MAX_W))/$width);

			if($tn_height>MAX_H)
			{
				$tn_width=int(($width*(MAX_H))/$height);
				$tn_height=MAX_H;
			}
		}

		if(STUPID_THUMBNAILING) { $thumbnail=$filename }
		else
		{
			$thumbnail=undef unless(make_thumbnail($filename,$thumbnail,$tn_width,$tn_height,THUMBNAIL_QUALITY,CONVERT_COMMAND));
		}
	}
	else
	{
		$tn_width=$width;
		$tn_height=$height;
		$thumbnail=$filename;
	}

	if($filetypes{$ext}) # externally defined filetype - restore the name
	{
		my $newfilename=$uploadname;
		$newfilename=~s!^.*[\\/]!!; # cut off any directory in filename
		$newfilename=~s/[#<>"']/_/g; # remove special characters from filename
		$newfilename=IMG_DIR.$newfilename;

		unless(-e $newfilename) # verify no name clash
		{
			rename $filename,$newfilename;
			$filename=$newfilename;
		}
		else
		{
			unlink $filename;
			make_error(S_DUPENAME);
		}
	}

	return ($filename,$ext,$size,$md5,$width,$height,$thumbnail,$tn_width,$tn_height);
}
