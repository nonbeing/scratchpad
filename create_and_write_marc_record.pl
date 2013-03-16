#!/usr/bin/perl -w

# source: http://search.cpan.org/dist/MARC-Record/lib/MARC/Doc/Tutorial.pod

## Example W1

## create a MARC::Record object.
use strict;
use MARC::Record;
my $record = MARC::Record->new();

## add the leader to the record. optional.
$record->leader('00903pam  2200265 a 4500');

## create an author field.
my $author = MARC::Field->new('100',1,'', a => 'Logan, Robert K.', d => '1939-');

## create a title field.
my $title = MARC::Field->new('245','1','4', a => 'The alphabet effect /', c => 'Robert K. Logan.');

$record->append_fields($author, $title);


## pretty print the record.
print $record->as_formatted(), "\n";

## open a filehandle to write to 'record.dat'.
open(OUTPUT, '> record.dat') or die $!;
print OUTPUT $record->as_usmarc();
close(OUTPUT);