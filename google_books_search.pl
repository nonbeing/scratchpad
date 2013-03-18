#!/usr/bin/perl

#BEGIN {
#    $|=1;
#    print "Content-type: text/html\n\n";
#    use CGI::Carp('fatalsToBrowser');
#    use CGI::Debug;
#}


# Based on the awesome Biblio-Z3950 sources by dpavlin at https://github.com/dpavlin/Biblio-Z3950

=head1 cataloguing:google_books_search.pl

    TODO

=cut


use strict;
#use warnings;

use CGI;
use MARC::Record;
use Data::Dump qw/dump/;
use JSON::XS;
use WWW::Mechanize;

use C4::Auth;
use C4::Biblio;
use C4::Breeding;
use C4::Output;
use C4::Koha;
use C4::Search;
  
my $global_json = {};
my $global_json_item_count = {};
my $pageCount_suffix = 'p.';

my $input = new CGI;
my $query   = $input->param('q');
my @value   = $input->param('value');
my $page    = $input->param('page') || 1;
my $success = $input->param('biblioitem');
my $results_per_page = 20; 

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   
        template_name   => "cataloguing/google_books_search.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { editcatalogue => '*' },
    }   
);

    # based on http://code.google.com/apis/books/docs/v1/using.html#PerformingSearch
    #
    # https://www.googleapis.com/books/v1/volumes?q=search+terms
    #
    # This request has a single required parameter:
    #
    # q - Search for volumes that contain this text string. There are special keywords you can specify in the search terms to search in particular fields, such as:
    #     intitle: Returns results where the text following this keyword is found in the title.
    #     inauthor: Returns results where the text following this keyword is found in the author.
    #     inpublisher: Returns results where the text following this keyword is found in the publisher.
    #     subject: Returns results where the text following this keyword is listed in the category list of the volume.
    #     isbn: Returns results where the text following this keyword is the ISBN number.
    #     lccn: Returns results where the text following this keyword is the Library of Congress Control Number.
    #     oclc: Returns results where the text following this keyword is the Online Computer Library Center number.
    #


sub search {
    my ($query) = @_;

    die "need query" unless defined $query;

    # NOTE: You have to specify country=?? in the URL for Google Books API to work:
    my $url = 'https://www.googleapis.com/books/v1/volumes?country=IN&q=' . $query;

    #print "[INFO] Opening URL: $url\n";

    my $mech =  WWW::Mechanize->new();

    # NOTE: You also (usually) have to specify a valid user agent for Mechanize to work with Google Books API (to prevent being blocked as a bot)
    $mech->agent('User-Agent=Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.7');

    # Finally, open the URL
    $mech->get( $url );

    my $json = decode_json $mech->content;
    #warn "[DEBUG] json dump: ", dump($json) if $debug;

    my $hits = 0;

    if ( exists $json->{items} ) {
        $hits = $#{ $json->{items} } + 1;
    } else {
        #warn "[WARN] Investigate anomalous API results in: ", $mech->content;
        return;
    }

    #print "[INFO] Got $hits results, extracting info...";

    $global_json = $json;
    $global_json_item_count = 0;

    return $hits;
}



sub save_marc_file {
    my ( $id, $isbn, $marc ) = @_;

    mkdir 'marc_files' unless -e 'marc';

    my $path = "marc_files/$isbn-"."$id".".marc";

    open(my $out, '>:utf8', $path) || die "$path: $!";
    #print $out $marc;
    close($out);

    #print "\n\n[INFO] Saved marc file at: $path ", -s $path, " bytes\n\n";
}


sub next_marc {
    #my ($format) = @_;

    my $isbn;

    #$format ||= 'marc';

    my $item = $global_json->{items}->[ $global_json_item_count++ ];

    #warn "[DEBUG] item = ",dump($item) if $debug;

    my $id = $item->{id} || die "no id";

    my $marc = MARC::Record->new;
    $marc->encoding('utf-8');

    if ( my $vi = $item->{volumeInfo} ) {

        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

        $marc->add_fields('008',sprintf("%02d%02d%02ds%04d%25s%-3s",
                $year % 100, $mon + 1, $mday, substr($vi->{publishedDate},0,4), ' ', $vi->{language}));

        if ( ref $vi->{industryIdentifiers} eq 'ARRAY' ) {
            foreach my $i ( @{ $vi->{industryIdentifiers} } ) {
                if ( $i->{type} =~ m/ISBN/i ) {
                    $marc->add_fields('020',' ',' ','a' => $i->{identifier} );
                    $isbn = $i->{identifier};
                } else {
                    $marc->add_fields('035',' ',' ','a' => $i->{identifier} );
                }
            }
        }

        my $first_author;
        if ( ref $vi->{authors} eq 'ARRAY' ) {
            $first_author = shift @{ $vi->{authors} };
            $marc->add_fields(100,'0',' ','a' => $first_author );
            $marc->add_fields(700,'0',' ','a' => $_ ) foreach @{ $vi->{authors} };
        }

        $marc->add_fields(245, ($first_author ? '1':'0') ,' ',
            'a' => $vi->{title},
            $vi->{subtitle} ? ( 'b' => $vi->{subtitle} ) : (),
        );

        if ( exists $vi->{publisher} or exists $vi->{publishedDate} ) {
            $marc->add_fields(260,' ',' ',
                $vi->{publisher} ? ( 'b' => $vi->{publisher} ) : (),
                $vi->{publishedDate} ? ( 'c' => $vi->{publishedDate} ) : ()
            );
        }

        $marc->add_fields(300,' ',' ','a' => $vi->{pageCount} . $pageCount_suffix ) if $vi->{pageCount};
        
        $marc->add_fields(520,' ',' ','a' => $vi->{description} ) if $vi->{description};

        if ( ref $vi->{categories} eq 'ARRAY' ) {
            $marc->add_fields(650,' ','4','a' => $_ ) foreach @{ $vi->{categories} };
        }

        if ( exists $vi->{imageLinks} ) {

            $marc->add_fields(856,'4','2',
                '3'=> 'Image link',
                'u' => $vi->{imageLinks}->{smallThumbnail},
                'x' => 'smallThumbnail',
            ) if exists $vi->{imageLinks}->{smallThumbnail};
            $marc->add_fields(856,'4','2',
                '3'=> 'Image link',
                'u' => $vi->{imageLinks}->{thumbnail},
                'x' => 'thumbnail',
            ) if exists $vi->{imageLinks}->{thumbnail};

        } # if imageLinks

        $marc->add_fields(856,'4','2',
            '3'=> 'Info link',
            'u' => $vi->{infoLink},
        );
        $marc->add_fields(856,'4','2',
            '3'=> 'Show reviews link',
            'u' => $vi->{showReviewsLink},
        );

        my $leader = $marc->leader;
        #print "\n[INFO] LEADER: [$leader]\n";
        $leader =~ s/^(....).../$1nam/;
        $marc->leader( $leader );

    } else {
        #warn "[ERROR] no volumeInfo in: ", dump($item);
    }

    $marc->add_fields( 856, ' ', ' ', 'u' => $item->{accessInfo}->{webReaderLink} );
#   $marc->add_fields( 520, ' ', ' ', 'a' => $item->{searchInfo}->{textSnippet} ); # duplicate of description

#   #warn "# hash ",dump($hash);
    #binmode STDOUT, ':utf8'; # prevent the "Wide character in print" warning on STDOUT: http://stackoverflow.com/a/2468550/376240

    #print "\n[INFO] FORMATTED MARC RECORD: \n", $marc->as_formatted;

    $template->param (
        marc_record => $marc->as_formatted
    );
    #save_marc_file( $id, $isbn, $marc->as_usmarc );

    #print "MARC RECORD: ", $marc->as_formatted;
    #print "[INFO] DONE!\n\n\n";
    return $id;
}









if ($query) {

    my $hits = search( $query );
    
    $template->param (
        hits => $hits
    );
    
    foreach ( my $count = 1; $count <= 1; $count++ ) { 
        #print "\n\n\n[INFO] HIT NUMBER: $count";
        my $marc = next_marc;
    }
}

output_html_with_http_headers $input, $cookie, $template->output;
