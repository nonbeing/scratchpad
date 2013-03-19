#!/usr/bin/perl

use WWW::Mechanize;
use Data::Dump qw/dump/;
use JSON::XS;

# NOTE: You have to specify country=?? in the URL for google books API to work:
# NOTE: You also might have to specify a valid user agent for Mechanize
$url = "https://www.googleapis.com/books/v1/volumes/EZQlpjL9LlEC?country=IN";

my $mech =  WWW::Mechanize->new();
$mech->get( $url );


    my $json = decode_json $mech->content;
    warn "[DEBUG] json dump: ", dump($json);


    my $item = $json->{volumeInfo}->{categories};

    warn "\n\n\n[DEBUG] item = ", dump($item);
