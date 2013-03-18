#!/usr/bin/perl

# Based on the awesome Biblio-Z3950 sources by dpavlin at https://github.com/dpavlin/Biblio-Z3950

use strict;
use warnings;

use MARC::Record;
use Data::Dump qw/dump/;
use JSON::XS;
use WWW::Mechanize;


my $debug = $ENV{DEBUG} || 0;

my $global_json = {};
my $global_json_item_count = {};

my $pageCount_suffix = 'p.'; # English



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
    
    # Koha Z39.50 query:
    #
    # Bib-1 @and @and @and @and @and @and @and @or
    # @attr 1=4 title 
    # @attr 1=7 isbn
    # @attr 1=8 issn 
    # @attr 1=1003 author 
    # @attr 1=16 dewey 
    # @attr 1=21 subject-holding 
    # @attr 1=12 control-no 
    # @attr 1=1007 standard-id 
    # @attr 1=1016 any
    
sub usemap {{
	4		=> 'intitle:',
	7		=> 'isbn:',
	8		=> 'isbn:', # FIXME?
	1003	=> 'inauthor:',
#	16		=> '',
	21		=> 'subject:',
	12		=> 'lccn:',
#	1007	=> '',
	1016	=> '',
}};



sub search {
	my ($query) = @_;

	die "need query" unless defined $query;

	my $url = 'https://www.googleapis.com/books/v1/volumes?q=' . $query;

    print "[INFO] Opening URL: $url\n";

	my $mech =  WWW::Mechanize->new();
	$mech->get( $url );

	my $json = decode_json $mech->content;
	warn "[DEBUG] json dump: ", dump($json) if $debug;

	my $hits = 0;

	if ( exists $json->{items} ) {
		$hits = $#{ $json->{items} } + 1;
	} else {
		warn "[WARN] Investigate anomalous API results in: ", $mech->content;
		return;
	}

    print "[INFO] Got $hits results, extracting info...";

	$global_json = $json;
	$global_json_item_count = 0;

	return $hits;
}



sub save_marc_file {
    my ( $id, $isbn, $marc ) = @_;

    mkdir 'marc_files' unless -e 'marc';

    my $path = "marc_files/$isbn-"."$id".".marc";

    open(my $out, '>:utf8', $path) || die "$path: $!";
    print $out $marc;
    close($out);

    print "\n\n[INFO] Saved marc file at: $path ", -s $path, " bytes\n\n";
}


sub next_marc {
	#my ($format) = @_;

    my $isbn;

	#$format ||= 'marc';

	my $item = $global_json->{items}->[ $global_json_item_count++ ];

	warn "[DEBUG] item = ",dump($item) if $debug;

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
		print "\n[INFO] LEADER: [$leader]\n";
		$leader =~ s/^(....).../$1nam/;
		$marc->leader( $leader );

	} else {
		warn "[ERROR] no volumeInfo in: ", dump($item);
	}

	$marc->add_fields( 856, ' ', ' ', 'u' => $item->{accessInfo}->{webReaderLink} );
#	$marc->add_fields( 520, ' ', ' ', 'a' => $item->{searchInfo}->{textSnippet} ); # duplicate of description

#	warn "# hash ",dump($hash);
    binmode STDOUT, ':utf8'; # prevent the "Wide character in print" warning on STDOUT: http://stackoverflow.com/a/2468550/376240

	print "\n[INFO] FORMATTED MARC RECORD: \n", $marc->as_formatted;

	save_marc_file( $id, $isbn, $marc->as_usmarc );

    print "[INFO] DONE!\n\n\n";
	return $id;
}


my $myQuery = join(' ', @ARGV) || 'Sri Sri Ravi Shankar';


my $hits = search( $myQuery );

foreach ( my $count = 1; $count <= $hits; $count++ ) { 
    print "\n\n\n[INFO] HIT NUMBER: $count";
    my $marc = next_marc;
}