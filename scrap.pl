use Mojo::UserAgent;
use 5.16.0;
use strict;
use warnings;
use File::Copy;
#use File::Slurp;
use EBook::EPUB;
use File::Path qw(make_path);
use Encode qw(decode encode);
use autodie;
use Mojo::DOM;
use File::Slurp;
no warnings qw{qw};

my $filter = join ',', qw(
                           script
                           meta
                           style
                           iframe
                           link
                           div.navbar
                           div.widget-content
                           div.post-footer
                           div.comments
                           div.blog-pager
                           #footer
                           span.widget-item-control
                           #widget-sidebar
                           #search-placement
                           #header
                           #skiplinks
                           #sidebar-wrapper
                           #horiz-menu
);

my $ua = Mojo::UserAgent->new;
my $url = 'http://greenhornfinancefootnote.blogspot.tw/2009/05/blog-post_10.html';
say $filter;
my $dom = $ua->get($url)->res->dom;
$dom->find($filter)->pluck('remove');
$dom->find('img')
say $dom->to_xml;
