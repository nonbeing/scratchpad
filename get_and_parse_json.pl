#!/usr/bin/perl -w

# based on idea from http://beerpla.net/2008/03/27/parsing-json-in-perl-by-example-southparkstudioscom-south-park-episodes/
 
use strict;
use WWW::Mechanize;
use JSON -support_by_pp;
 
 
sub fetch_json_page
{
    my ($json_url) = @_;
    my $browser = WWW::Mechanize->new();
    
    eval
    {
        # download the json page:
        print "Opening URL: $json_url\n";
        $browser->get( $json_url );
        my $content = $browser->content();

        # create new JSON parser
        my $json = new JSON;
     
        # these are some nice json options to relax restrictions a bit:
        my $json_text = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($content);

        # json_text now contains the decoded JSON
     
        # iterate over each element in the items[] array:
        my $item_number = 1;
        foreach my $item(@{$json_text->{items}})
        {
            my %item_hash = ();
            $item_hash{number} = "Item $item_number";
            $item_hash{title} = $item->{volumeInfo}->{title};

            # ToDo: join the elements of the authors array with commas into a string, then put that into $item_hash{authors}
            # $item_hash{authors} = $item->{description};


            $item_hash{thumbnail_url} = $item->{volumeInfo}->{imageLinks}->{thumbnail};
            $item_hash{publisher} = $item->{volumeInfo}->{publisher};
            $item_hash{pageCount} = $item->{volumeInfo}->{pageCount};
            $item_hash{description} = $item->{volumeInfo}->{description};
     
            # print item information:
            print "\n\nFound Item:\n";
            while (my($k, $v) = each (%item_hash))
            {
                print "\t$k: $v\n";
            }
            foreach my $author( @{ $item->{volumeInfo}->{authors} } )
            {   
               print "\tauthor: $author\n";
            } 
     
            $item_number++;
        }
    };
    # catch crashes:
    if($@){
        print "[[JSON ERROR]] JSON parser crashed! $@\n";
    }
}

#fetch_json_page("https://www.googleapis.com/books/v1/volumes?q=isbn:8179923703");
fetch_json_page("https://www.googleapis.com/books/v1/volumes?q=isbn:0073523321");

