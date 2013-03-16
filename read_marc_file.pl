#!/usr/bin/perl -w

## Example R8

use MARC::Batch;


my $marcfile;

if ( $#ARGV == 0 ) {
    $marcfile = $ARGV[0];
}
else {
    $marcfile = "file.dat"
}


my $batch = MARC::Batch->new('USMARC',$marcfile);
my $record = $batch->next();

## get all of the fields using the fields() method.
my @fields = $record->fields();

## print out the tag, the indicators and the field contents.
foreach my $field (@fields) {
  print
    $field->tag(), " ",
    defined $field->indicator(1) ? $field->indicator(1) : "",
    defined $field->indicator(2) ? $field->indicator(2) : "",
    " ", $field->as_string, " \n";
}


