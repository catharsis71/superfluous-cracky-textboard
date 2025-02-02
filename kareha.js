function get_cookie(name)
{
	with(document.cookie)
	{
		var regexp=new RegExp("(^|;\\s+)"+name+"=(.*?)(;|$)");
		var hit=regexp.exec(document.cookie);
		if(hit&&hit.length>2) return unescape(hit[2]);
		else return '';
	}
};

function set_cookie(name,value,days)
{
	if(days)
	{
		var date=new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		var expires="; expires="+date.toGMTString();
	}
	else expires="";
	document.cookie=name+"="+value+expires+"; path=/";
}



function make_password()
{
	var chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	var pass='';

	for(var i=0;i<8;i++)
	{
		var rnd=Math.floor(Math.random()*chars.length);
		pass+=chars.substring(rnd,rnd+1);
	}

	return(pass);
}

function get_password(name)
{
	var pass=get_cookie(name);
	if(pass) return pass;
	return make_password();
}



function show(id)
{
	var style=document.getElementById(id).style;
	if(style.display) style.display="";
	else style.display="none";
}

function insert(text,thread)
{
	var textarea=document.getElementById("postform"+thread).comment;
	if(textarea)
	{
		if(textarea.createTextRange && textarea.caretPos) // IE
		{
			var caretPos=textarea.caretPos;
			caretPos.text=caretPos.text.charAt(caretPos.text.length-1)==" "?text+" ":text;
		}
		else if(textarea.setSelectionRange) // Firefox
		{
			var start=textarea.selectionStart;
			var end=textarea.selectionEnd;
			textarea.value=textarea.value.substr(0,start)+text+textarea.value.substr(end);
			textarea.setSelectionRange(start+text.length,start+text.length);
		}
		else
		{
			textarea.value+=text+" ";
		}
		textarea.focus();
	}
}

function w_insert(text,link)
{
	if(document.body.className=="mainpage") document.location=link+"#i"+text;
	else insert(text,"");
}

function size_field(id,rows) { document.getElementById(id).comment.setAttribute("rows",rows); }



function delete_post(thread,post,file)
{
	if(confirm("Are you sure you want to delete reply "+post+"?"))
	{
		var fileonly=false;
		var script=document.forms[0].action;
		var password=document.forms[0].password.value;

		if(file) fileonly=confirm("Leave the reply text and delete the only file?");

		document.location=script
		+"?task=delete"
		+"&delete="+thread+","+post
		+"&password="+password
		+"&fileonly="+(fileonly?"1":"0");
	}
}



function set_stylesheet(styletitle)
{
	var links=document.getElementsByTagName("link");
	var found=false;
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&title)
		{
			links[i].disabled=true; // IE needs this to work. IE needs to die.
			if(styletitle==title) { links[i].disabled=false; found=true; }
		}
	}
	if(!found) set_preferred_stylesheet();
}

function set_preferred_stylesheet()
{
	var links=document.getElementsByTagName("link");
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&title) links[i].disabled=(rel.indexOf("alt")!=-1);
	}
}

function get_active_stylesheet()
{
	var links=document.getElementsByTagName("link");
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&title&&!links[i].disabled) return title;
	}
}

function get_preferred_stylesheet()
{
	var links=document.getElementsByTagName("link");
	for(var i=0;i<links.length;i++)
	{
		var rel=links[i].getAttribute("rel");
		var title=links[i].getAttribute("title");
		if(rel.indexOf("style")!=-1&&rel.indexOf("alt")==-1&&title) return title;
	}
	return null;
}

function set_inputs(id)
{
	var el=document.getElementById(id);

	if(!el||!el.link) return;

	if(!el.name.value) el.name.value=get_cookie("name");
	if(!el.link.value) el.link.value=get_cookie("link");
	if(!el.password.value) el.password.value=get_password("password");
	if(el.markup&&!el.comment.value) el.markup.value=get_cookie("markup");
	select_markup(el.markup);
}

function set_delpass(id)
{
	with(document.getElementById(id)) password.value=get_cookie("password");
}

function select_markup(sel)
{
	if(!window.markup_descriptions) return;

	var el=sel;
	while(el=el.nextSibling) if(el.nodeName.toLowerCase()=="small") break;

	if(el) el.innerHTML=markup_descriptions[sel.value];
}

window.onunload=function(e)
{
	if(style_cookie)
	{
		var title=get_active_stylesheet();
		set_cookie(style_cookie,title,365);
	}
}

window.onload=function(e)
{
	if(match=/#i(.+)/.exec(document.location.toString()))
	if(!document.getElementById("postform").comment.value)
	insert(unescape(match[1]),"");
}

if(style_cookie)
{
	var cookie=get_cookie(style_cookie);
	var title=cookie?cookie:get_preferred_stylesheet();
	set_stylesheet(title);
}

var captcha_key=make_password();
