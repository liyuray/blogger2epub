use strict;
use warnings;
use File::Copy;
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
                           #fb-root
                           like
                           div.comments-template
                        );
my %titleh;

my $root = shift @ARGV or die;
my $dir = shift @ARGV or die;
my $author = shift @ARGV || $dir;
my $title = shift @ARGV || $author;

preprocess($dir);
genepub($dir, $title);


sub preprocess {
  my $dir = shift;

  my $tail = "</body></html>";

  make_path("$dir/epub");

  chdir("$dir/raw");
  my %jpgh;
  my %b5jpgh;
  my %inhjpgh;
  my @b5jpgs = (
                <*.jpg>,
                <*.jpg.[0-9]*>,
                <*.bmp>,
                <*.bmp.[0-9]*>,
                <*.png>,
                <*.png.[0-9]*>,
                <*.gif>,
                <*.gif.[0-9]*>,
               );
  my @ucjpgs = map {decode('big5',$_)} @b5jpgs;
  @b5jpgh{@ucjpgs} = @b5jpgs;

  chdir("../..");
  my $i=0;
  for my $jpg (@ucjpgs){
    my $njpg = $jpg;
    my $inhjpg = $jpg;
    $inhjpg =~ s/\%/%25/g;
#    $inhjpg =~ s/\&/&amp;/g;
#    $inhjpg =~ s/\'/&#39;/g;
    $njpg =~ tr/a-zA-Z0-9.//cd;
    $njpg =~ s/\.(jpg|bmp|png|gif)\.(\d+)/__$2\.$1/i;
    if ($jpg ne $njpg) {
        $jpgh{$jpg} = sprintf("%04d",$i++)."_".$njpg;
        $inhjpgh{$inhjpg} = $jpgh{$jpg};
    } else {
        $jpgh{$jpg} = $jpg;
        $inhjpgh{$inhjpg} = $jpgh{$jpg};
    }
  }
  chdir("$dir");
  copy("raw/".$b5jpgh{$_}, "epub/".$jpgh{$_}) for @ucjpgs;
  chdir("..");

  chdir("$dir/raw");
  my @files = (<*.html>,<*.htm>);

  for my $file (@files) {
      say STDERR $file;
    my $fnoo = $file;
    my $html = read_file($file, binmode => ':utf8');

    my $dom = Mojo::DOM->new($html);
    next unless $dom->at("div.$root");
    open my $fho, ">:utf8", "../epub/$fnoo" or die "cannot open > $!";
    $titleh{$fnoo} = $dom->at('title')->text;
    my $odom = Mojo::DOM->new;
    $odom->tree(['root',
                 ['tag', 'html', {'xmlns' => 'http://www.w3.org/1999/xhtml'}, {},
                  ['tag', 'head', {}, {},
                   ['tag', 'title',{}, {},
                    ['text', $titleh{$fnoo},
                    ],
                   ],
                  ],
                  ['tag', 'body', {}, {},
#                   $dom->at('div.post.hentry')->tree,
                   $dom->at("div.$root")->tree,
                  ],
                 ],
                ]);
    $odom->find($filter)->pluck('remove');
    $odom->find('a[onblur]')->each(sub {delete shift->attrs->{onblur}});
    $odom->find('a[target]')->each(sub {delete shift->attrs->{target}});
    $odom->find('img[src]')->each(sub {
                                   my $key = $_[0]->attrs('src');
                                   $_[0]->attrs( src => $inhjpgh{$key} ) if exists $inhjpgh{$key};
                                 });
    my $output = $odom->root->to_xml;
    say $fho q(<?xml version="1.0" encoding="utf-8"?>);
    say $fho $output;
    close $fho;
  }
  chdir("../..");
}

sub genepub {
  my $dir = shift;
  my $title = shift;

  chdir("$dir/epub");
  # Create EPUB object
  my $epub = EBook::EPUB->new;
  # Set metadata: title/author/language/id
  $epub->add_title($title);
  $epub->add_author($author);
  $epub->add_language('zh');
#  $epub->add_identifier('1440465908', 'ISBN');

  # Add package content: stylesheet, font, xhtml and cover
  #    $epub->copy_stylesheet('/path/to/style.css', 'style.css');
  $epub->copy_file($_, $_, 'image/jpeg') for (<*.jpg>);
  $epub->copy_file($_, $_, 'image/bmp') for (<*.bmp>);
  $epub->copy_file($_, $_, 'image/png') for (<*.png>);
  $epub->copy_file($_, $_, 'image/gif') for (<*.gif>);

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
  $epub->pack_zip("$dir.epub");

  chdir("../..");
}
