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
my %titleh;
my @titles = qw(all);

for my $title (@titles) {
  preprocess($title);
  genepub($title);
}

sub get_head {
  my $title = shift;
  my $head = << "AAAA";
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:xml="http://www.w3.org/XML/1998/namespace" xml:lang="zh" lang="zh">
<head>
	<title>$title</title>
</head>
<body>
AAAA
  return $head;
}

sub preprocess {
  my $title = shift;

  my $tail = "</body></html>";

  make_path("$title/epub");

  chdir("$title/raw");
  my %jpgh;
  my %b5jpgh;
  my %inhjpgh;
  my @b5jpgs = (
                <*.jpg>,
                <*.jpg.[0-9]>,
                <*.bmp>,
                <*.bmp.[0-9]>,
                <*.png>,
                <*.png.[0-9]>,
                <*.gif>,
                <*.gif.[0-9]>,
               );
  my @ucjpgs = map {decode('big5',$_)} @b5jpgs;
  @b5jpgh{@ucjpgs} = @b5jpgs;

  chdir("../..");
  my $i=0;
  for my $jpg (@ucjpgs){
    my $njpg = $jpg;
    my $inhjpg = $jpg;
    $inhjpg =~ s/\%/%25/g;
    $inhjpg =~ s/\&/&amp;/g;
    $inhjpg =~ s/\'/&#39;/g;
    $njpg =~ tr/a-zA-Z0-9.//cd;
    $njpg =~ s/\.(jpg|bmp|png|gif)\.(\d)/__$2\.$1/i;
    #print $njpg,$/;
    if ($jpg ne $njpg) {
        $jpgh{$jpg} = sprintf("%04d",$i++)."_".$njpg;
        $inhjpgh{$inhjpg} = $jpgh{$jpg};
    } else {
        $jpgh{$jpg} = $jpg;
        $inhjpgh{$inhjpg} = $jpgh{$jpg};
    }
  }
#  die;
#  $jpgh{"Global+Bond+Fund+Holding%25E7%259B%25A7.jpg"} = "93GlobalBondFundHoldingE79BA7.jpg";
#  $jpgh{"Global+Bond+Fund+Holding%25E7%25BE%258E%25E5%259C%258B.jpg"} = "94GlobalBondFundHoldingE7BE8EE59C8B.jpg";
#  $jpgh{"%25E7%25BE%258E%25E5%259C%258Bvs%25E7%259B%25A7%25E6%25A3%25AE%25E5%25A0%25A1%25E7%25B8%25BE%25E6%2595%2588.jpg"} = "53E7BE8EE59C8BvsE79BA7E6A3AEE5A0A1E7B8BEE69588.jpg";

  my $pattern = '(' . join('|', map {quotemeta} grep {$inhjpgh{$_} ne $_} keys %inhjpgh). ')';
  my $match   = qr/"$pattern"/;
#  print $match;
  chdir("$title");
  #my $i;
  copy("raw/".$b5jpgh{$_}, "epub/".$jpgh{$_}) for @ucjpgs;
  chdir("..");

  chdir("$title/raw");
  my @files = <*.html>;

  for my $file (@files) {
    my $fnoo = $file;
#    $fnoo =~ s/\.html$/-2.html/;
    my $fno = "../epub/$fnoo";
#    $fno =~ s/\/raw\//\/epub\//;
#    open my $fh, "<:utf8", $file or die "cannot open < $!";
    my $html = read_file($file, binmode => ':utf8');
    open my $fho, ">:utf8", $fno or die "cannot open > $!";

    my $dom = Mojo::DOM->new($html);
    $titleh{$fnoo} = $dom->at('title')->text;
    $dom->find($filter)->pluck('remove');
    my $output = $dom->to_xml;
    #    while (<$fh>) {
#      $titleh{$fnoo} = $1 if /<title>(.*)<\/title>/;
#      last if /<h3 class='post-title entry-title'>/;
#    }
#    print $fho get_head($titleh{$fnoo});
#    print $fho "<h3>";
#    for (@lines) {
      #      last if /<div class='post-footer'>/;
      #    s/$match/'"'.sprintf("%2d",$i++).$jpgh{$1}.'"'/ge;
    $output =~ s/$match/'"'.$inhjpgh{$1}.'"'/ge;
    print $fho $output;
    #    }
#    print $fho $tail;
    close $fho;
#    close $fh;
  }
  chdir("../..");
}

sub genepub {
  my $title = shift;

  chdir("$title/epub");
#  my @htmls= <*-2.html>;
  # Create EPUB object
  my $epub = EBook::EPUB->new;
  # Set metadata: title/author/language/id
  $epub->add_title($title);
  $epub->add_author('Green Horn');
  $epub->add_language('en');
  $epub->add_identifier('1440465908', 'ISBN');

  # Add package content: stylesheet, font, xhtml and cover
  #    $epub->copy_stylesheet('/path/to/style.css', 'style.css');
  $epub->copy_file($_, $_, 'image/jpeg') for (<*.jpg>,<*.jpg.[0-9]>);
  $epub->copy_file($_, $_, 'image/bmp') for (<*.bmp>,<*.bmp.[0-9]>);
  $epub->copy_file($_, $_, 'image/png') for (<*.png>,<*.png.[0-9]>);
  $epub->copy_file($_, $_, 'image/gif') for (<*.gif>,<*.gif.[0-9]>);

  my $po = 1;

  my @htmls = sort {$titleh{$a} cmp $titleh{$b}} keys %titleh;
  for my $html (@htmls) {
      my $chapter_id = $epub->copy_xhtml($html, $html);
      my $navp = $epub->add_navpoint(
          label       => $titleh{$html},
          id          => $chapter_id,
          content     => $html,
          play_order  => $po++,
          );
  }

  # Generate resulting ebook
  $epub->pack_zip('a.epub');

  chdir("../..");
}

#system("perl ../03-gen-toc.pl cover.htm > toc.htm");
#system("perl ../04-gen-epub.pl $title");

