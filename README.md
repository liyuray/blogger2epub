# blogger2epub #

## get blogger pages ##
wget --content-disposition -P cache -A html,jpg,png,bmp -U "Mozilla/5.0 (Linux; U; Android 2.3.3; zh-tw; HTC_Pyramid Build/GRI40) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1" --restrict-file-names=nocontrol -D greenhornfinancefootnote.blogspot.tw,greenhornfinancefootnote.blogspot.com,bp.blogspot.com -nd -r -l1 -p -E -H -k -K http://greenhornfinancefootnote.blogspot.tw/2009/05/blog-post_10.html

wget --content-disposition -P cache --restrict-file-names=nocontrol -D masterhsiao.com.tw -nd -r -l2 -p -E -H -k -K http://www.masterhsiao.com.tw


## produce epub ##
perl blogger2epub.pl post.hentry all "green horn"
perl blogger2epub.pl RightWrapper all1 "master hsiao"
